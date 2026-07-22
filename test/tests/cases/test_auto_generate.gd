@tool
extends MLTestCase

## Auto-generate: structural changes schedule one coalesced recompile unless
## auto_generate is off. The schedule is deferred and the runner never pumps
## frames, so these tests arm the stack manually (the arming hook is itself
## deferred) and invoke the deferred target directly; deferred delivery is
## engine behaviour, proven separately by the editor diagnostics.

const HEAD := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
"""

const BASE := HEAD + """
uniform vec3 tint = vec3(1.0);
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = tint;
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

const TOP := HEAD + """
uniform vec3 topColor = vec3(0.2, 0.4, 0.1);
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = topColor;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

const OTHER := HEAD + """
uniform float otherValue = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(otherValue);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


func _armed_stack() -> LayerStack:
	var stack := LayerStack.new()
	stack.base_layer = surface(BASE)
	stack.layers = [texture_masked_layer(TOP)] as Array[MaterialLayer]
	stack.compile()
	stack._auto_armed = true  # normally set by the deferred load hook
	return stack


func test_toggling_a_layer_schedules_a_recompile() -> void:
	var stack := _armed_stack()
	check_contains(stack.shader.code, "s_layer_1_", "layer 1 is in the shader while active")

	stack.layers[0].active = false
	check(stack._auto_compile_queued, "a structural change queues an auto-compile")

	stack._run_auto_compile()
	check_not_contains(stack.shader.code, "s_layer_1_",
		"the recompiled shader drops the inactive layer")
	check(not stack._auto_compile_queued, "the queue flag clears after the run")


func test_mask_type_change_schedules_a_recompile() -> void:
	var stack := _armed_stack()
	stack._auto_compile_queued = false

	stack.layers[0].mask_type = MaterialLayer.MaskType.MATERIAL
	check(stack._auto_compile_queued, "switching mask type queues an auto-compile")


func test_material_swap_recompiles_with_the_new_shader() -> void:
	var stack := _armed_stack()
	stack.layers[0].surface_material = surface(OTHER)
	check(stack._auto_compile_queued, "swapping a material queues an auto-compile")

	stack._run_auto_compile()
	check_contains(stack.shader.code, "s_layer_1_otherValue",
		"the new material's uniforms reach the shader without pressing Generate")


func test_auto_generate_off_means_manual() -> void:
	var stack := _armed_stack()
	stack.auto_generate = false

	stack.layers[0].active = false
	check(not stack._auto_compile_queued, "no auto-compile queues when auto_generate is off")
	check_contains(stack.shader.code, "s_layer_1_",
		"the shader keeps the old structure until Generate is pressed")


func test_construction_does_not_auto_compile() -> void:
	# Resource loading runs the same setters; until the deferred arming hook
	# fires, none of them may schedule a compile.
	var stack := LayerStack.new()
	stack.base_layer = surface(BASE)
	stack.layers = [texture_masked_layer(TOP)] as Array[MaterialLayer]

	check(not stack._auto_compile_queued, "constructing a stack never queues a compile")


func test_auto_compile_is_silent_without_a_base() -> void:
	var stack := LayerStack.new()
	stack._auto_armed = true
	stack.layers = [texture_masked_layer(TOP)] as Array[MaterialLayer]
	check(stack._auto_compile_queued, "the structural change still queues")

	stack._run_auto_compile()
	check(stack.shader == null, "auto-compile without a base is a quiet no-op")