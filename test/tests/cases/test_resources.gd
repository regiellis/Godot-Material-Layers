@tool
extends MLTestCase

## Resource ownership and uniform propagation, independent of code generation.

const HEAD := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
"""

const TEXTURED := HEAD + """
uniform vec3 tint = vec3(1.0);
uniform sampler2D albedoTex;

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = texture(albedoTex, UV).rgb * tint;
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


static func _tex(c: Color) -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


func test_layer_references_its_surface_material() -> void:
	var shared := surface(TEXTURED)
	shared.set_shader_parameter("tint", Vector3(1, 0, 0))

	var a := MaterialLayer.new()
	var b := MaterialLayer.new()
	a.surface_material = shared
	b.surface_material = shared

	check(a.surface_material == shared, "the layer stores the material it was given")
	check(b.surface_material == shared, "two layers may share one material")

	shared.set_shader_parameter("tint", Vector3(0, 1, 0))
	check_eq(a.surface_material.get_shader_parameter("tint"), Vector3(0, 1, 0),
		"editing the source material is visible through the layer")


func test_stack_references_its_base_layer() -> void:
	var shared := surface(TEXTURED)
	var stack := LayerStack.new()
	stack.base_layer = shared
	check(stack.base_layer == shared, "the stack stores the material it was given")


func test_editing_the_source_material_updates_the_stack() -> void:
	# The live-link contract: layers reference the material asset, so editing
	# the asset itself drives the generated material. Per-stack uniqueness is
	# Godot's own Make Unique, not an implicit duplicate.
	var source := surface(TEXTURED)
	source.set_shader_parameter("tint", Vector3(1, 0, 0))

	var layer := texture_masked_layer(TEXTURED)
	layer.surface_material = source

	var stack := LayerStack.new()
	stack.base_layer = surface(TEXTURED)
	stack.layers = [layer] as Array[MaterialLayer]
	stack.compile()
	check_eq(stack.get_shader_parameter("s_layer_1_tint"), Vector3(1, 0, 0),
		"compile picks up the source material's values")

	source.set_shader_parameter("tint", Vector3(0, 0, 1))
	source.emit_changed()
	check_eq(stack.get_shader_parameter("s_layer_1_tint"), Vector3(0, 0, 1),
		"editing the source material updates the stack live")


func test_uniform_values_reach_the_generated_material() -> void:
	var base := surface(TEXTURED)
	base.set_shader_parameter("tint", Vector3(0.25, 0.5, 0.75))

	var stack := LayerStack.new()
	stack.base_layer = base
	stack.compile()

	check_eq(stack.get_shader_parameter("s_layer_0_tint"), Vector3(0.25, 0.5, 0.75),
		"uniform value is copied onto the generated material")


func test_uniform_edit_after_compile_propagates() -> void:
	var base := surface(TEXTURED)
	base.set_shader_parameter("tint", Vector3(1, 0, 0))

	var stack := LayerStack.new()
	stack.base_layer = base
	stack.compile()
	check_eq(stack.get_shader_parameter("s_layer_0_tint"), Vector3(1, 0, 0),
		"initial uniform value is copied at compile time")

	# SurfaceMaterial._set() defers emit_changed(), and a MainLoop script never
	# reaches an idle frame, so deliver the signal the editor would deliver.
	stack.base_layer.set_shader_parameter("tint", Vector3(0, 1, 0))
	stack.base_layer.emit_changed()
	check_eq(stack.get_shader_parameter("s_layer_0_tint"), Vector3(0, 1, 0),
		"editing a layer uniform updates the stack without recompiling")


func test_unset_uniform_falls_back_to_the_shader_default() -> void:
	var base := surface(TEXTURED)
	var stack := LayerStack.new()
	stack.base_layer = base
	stack.compile()

	check_contains(stack.shader.code, "uniform vec3 s_layer_0_tint = vec3(1.0)",
		"the layer shader's default value survives into the generated uniform")


func test_distinct_textures_stay_distinct() -> void:
	var red := _tex(Color.RED)
	var green := _tex(Color.GREEN)

	var base := surface(TEXTURED)
	base.set_shader_parameter("albedoTex", red)
	var top := texture_masked_layer(TEXTURED)
	top.surface_material.set_shader_parameter("albedoTex", green)

	var stack := LayerStack.new()
	stack.base_layer = base
	stack.layers = [top] as Array[MaterialLayer]
	stack.compile()

	var code: String = stack.shader.code
	check_contains(code, "uniform sampler2D s_layer_0_albedoTex", "layer 0 sampler exists")
	check_contains(code, "uniform sampler2D s_layer_1_albedoTex", "layer 1 sampler exists")


func test_shared_texture_layers_keep_their_own_samplers() -> void:
	var shared_tex := _tex(Color.BLUE)

	var base := surface(TEXTURED)
	base.set_shader_parameter("albedoTex", shared_tex)
	var top := texture_masked_layer(TEXTURED)
	top.surface_material.set_shader_parameter("albedoTex", shared_tex)

	var stack := LayerStack.new()
	stack.base_layer = base
	stack.layers = [top] as Array[MaterialLayer]
	stack.compile()

	var code: String = stack.shader.code
	check_contains(code, "uniform sampler2D s_layer_0_albedoTex", "layer 0 keeps its sampler")
	check_contains(code, "uniform sampler2D s_layer_1_albedoTex",
		"layer 1 keeps its own sampler even when the texture is shared")
	check_compiles(code, "a shared-texture stack compiles")

	# The point of per-layer samplers: a texture swap after Generate must
	# propagate without a recompile.
	var other := _tex(Color.WHITE)
	top.surface_material.set_shader_parameter("albedoTex", other)
	top.surface_material.emit_changed()
	check(stack.get_shader_parameter("s_layer_1_albedoTex") == other,
		"the swapped texture reaches the stack without a recompile")
	check(stack.get_shader_parameter("s_layer_0_albedoTex") == shared_tex,
		"the other layer keeps the original texture")


func test_reverting_a_uniform_clears_it_on_the_stack() -> void:
	var base := surface(TEXTURED)
	base.set_shader_parameter("tint", Vector3(1, 0, 0))
	var stack := LayerStack.new()
	stack.base_layer = base
	stack.compile()
	check_eq(stack.get_shader_parameter("s_layer_0_tint"), Vector3(1, 0, 0),
		"the override reaches the stack")

	base.set_shader_parameter("tint", null)
	base.emit_changed()
	check(stack.get_shader_parameter("s_layer_0_tint") == null,
		"reverting the source uniform reverts the stack to the shader default")


func test_mask_uv_controls_reach_the_stack() -> void:
	var base := surface(TEXTURED)
	var top := texture_masked_layer(TEXTURED)
	top.mask_uv_scale = Vector2(3, 3)
	top.mask_uv2 = true

	var stack := LayerStack.new()
	stack.base_layer = base
	stack.layers = [top] as Array[MaterialLayer]
	stack.compile()

	var code: String = stack.shader.code
	check_contains(code, "uniform vec2 m_layer_1_mask_uv_scale", "mask UV scale uniform exists")
	check_contains(code, "uniform bool m_layer_1_mask_uv2", "mask UV2 switch uniform exists")
	check_compiles(code, "mask UV controls compile")
	check_eq(stack.get_shader_parameter("m_layer_1_mask_uv_scale"), Vector2(3, 3),
		"the layer's UV scale reaches the generated material")
	check_eq(stack.get_shader_parameter("m_layer_1_mask_uv2"), true,
		"the UV2 switch reaches the generated material")

	# mask_updated is emitted synchronously, so this propagates without frames.
	top.mask_uv_offset = Vector2(0.5, 0.25)
	check_eq(stack.get_shader_parameter("m_layer_1_mask_uv_offset"), Vector2(0.5, 0.25),
		"a UV offset edit propagates live without a recompile")


func test_null_layer_entry_becomes_a_real_layer() -> void:
	var stack := LayerStack.new()
	stack.layers = [null] as Array[MaterialLayer]
	check_eq(stack.layers.size(), 1, "array keeps its size")
	check(stack.layers[0] != null, "null entries are replaced with a MaterialLayer")
