@tool
extends MLTestCase

## Core code generation: namespacing, blend paths, and whether the result is a
## shader Godot will actually accept.

const HEAD := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
"""

const BASE := HEAD + """
uniform vec3 tint = vec3(1.0);

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = tint;
	LAYER_OUT_ROUGHNESS = 0.5;
	LAYER_OUT_HEIGHT = 0.25;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

const TOP := HEAD + """
uniform vec3 topColor = vec3(0.2, 0.4, 0.1);

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = topColor;
	LAYER_OUT_ROUGHNESS = 0.9;
	LAYER_OUT_HEIGHT = 0.75;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

## Deliberately reuses the identifier "tint" that BASE also declares.
const TOP_SAME_UNIFORM := HEAD + """
uniform vec3 tint = vec3(0.0, 1.0, 0.0);

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = tint;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

const HEIGHT_MASK := HEAD + """
uniform float heightOffset = 0.0;

void fragment() {
	SETUP_LAYER_FRAGMENT;
	float m = clamp(LAYER_CURRENT_HEIGHT + heightOffset, 0.0, 1.0);
	RESULT_ALBEDO = mix(LAYER_BELOW_ALBEDO, LAYER_CURRENT_ALBEDO, m);
	RESULT_ROUGHNESS = mix(LAYER_BELOW_ROUGHNESS, LAYER_CURRENT_ROUGHNESS, m);
	RESULT_HEIGHT = LAYER_BELOW_HEIGHT;
}
"""


func test_base_layer_only() -> void:
	var code := generate(surface(BASE), [])

	check_contains(code, "uniform vec3 s_layer_0_tint", "base uniform is namespaced")
	check_contains(code, "fragmentMaterial fragment_0_out = DEFAULT_FRAGMENT",
		"layer 0 seeds from DEFAULT_FRAGMENT")
	check_contains(code, "fragmentMaterial finalFragment = fragment_0_out",
		"finalFragment starts at layer 0")
	check_eq(undeclared_tokens(code), [] as Array[String], "no dangling namespaced tokens")
	check_compiles(code, "base-only stack compiles")


func test_texture_masked_layer() -> void:
	var code := generate(surface(BASE), [texture_masked_layer(TOP)])

	check_contains(code, "uniform sampler2D m_layer_1_mask_sampler", "emits the mask sampler")
	check_contains(code, "uniform int m_layer_1_mask_channel", "emits the mask channel")
	check_contains(code, "l_mixFragment(finalFragment, fragment_1_out",
		"blends through l_mixFragment")
	check_eq(undeclared_tokens(code), [] as Array[String], "no dangling namespaced tokens")
	check_compiles(code, "texture-masked stack compiles")


func test_material_masked_layer() -> void:
	var code := generate(surface(BASE), [material_masked_layer(TOP, HEIGHT_MASK)])

	check_contains(code, "uniform float m_layer_1_heightOffset", "mask uniform is namespaced")
	check_contains(code, "finalFragment.layer_mat_albedo = mix(",
		"RESULT_ALBEDO writes straight to finalFragment")
	check_not_contains(code, "l_mixFragment",
		"material masks blend themselves, the generator does not mix")
	check_eq(undeclared_tokens(code), [] as Array[String], "no dangling namespaced tokens")
	check_compiles(code, "material-masked stack compiles")


func test_inactive_mask_replaces_result() -> void:
	var layer := texture_masked_layer(TOP)
	layer.mask_active = false
	var code := generate(surface(BASE), [layer])

	check_contains(code, "finalFragment = fragment_1_out", "layer replaces the result outright")
	check_compiles(code, "unmasked layer stack compiles")


func test_same_uniform_name_across_layers() -> void:
	var code := generate(surface(BASE), [texture_masked_layer(TOP_SAME_UNIFORM)])

	check_contains(code, "uniform vec3 s_layer_0_tint", "layer 0 keeps its own tint")
	check_contains(code, "uniform vec3 s_layer_1_tint", "layer 1 gets a distinct tint")
	check_compiles(code, "colliding uniform names still compile")


func test_three_layer_chain() -> void:
	var code := generate(surface(BASE), [
		material_masked_layer(TOP, HEIGHT_MASK),
		texture_masked_layer(TOP),
	])

	check_contains(code, "fragmentMaterial fragment_2_out = finalFragment",
		"layer 2 seeds from the running result")
	check_eq(undeclared_tokens(code), [] as Array[String], "no dangling namespaced tokens")
	check_compiles(code, "three-layer stack compiles")


func test_missing_base_layer() -> void:
	var stack := LayerStack.new()
	stack.layers = [texture_masked_layer(TOP)] as Array[MaterialLayer]
	stack.compile()
	var code: String = stack.shader.code if stack.shader else ""

	# Slot 0 is skipped when it has no shader, so nothing declares finalFragment.
	check_contains(code, "void fragment()", "still emits a fragment function")
	check(not compiles(code) or code.contains("fragmentMaterial finalFragment"),
		"a stack with no base layer must not emit code that references an undeclared finalFragment")
