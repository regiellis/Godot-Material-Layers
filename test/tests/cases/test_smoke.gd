@tool
extends MLTestCase

## Sanity checks: the addon's classes load and a trivial stack compiles.

const MINIMAL_SURFACE := """
shader_type spatial;

#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"

uniform vec3 tint = vec3(1.0);

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = tint;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


func test_classes_are_registered() -> void:
	check(ClassDB.class_exists("ShaderMaterial"), "engine classes available")
	check(SurfaceMaterial.new() != null, "SurfaceMaterial instantiates")
	check(MaskMaterial.new() != null, "MaskMaterial instantiates")
	check(MaterialLayer.new() != null, "MaterialLayer instantiates")
	check(LayerStack.new() != null, "LayerStack instantiates")


func test_new_surface_material_gets_template_code() -> void:
	var mat := SurfaceMaterial.new()
	check(mat.shader != null, "SurfaceMaterial seeds a Shader")
	check_contains(mat.shader.code, "SETUP_LAYER_FRAGMENT", "template has the fragment macro")
	check_contains(mat.shader.code, "layer_lib.gdshaderinc", "template includes the layer lib")


func test_new_mask_material_gets_template_code() -> void:
	var mat := MaskMaterial.new()
	check(mat.shader != null, "MaskMaterial seeds a Shader")
	check_contains(mat.shader.code, "RESULT_ALBEDO", "template writes RESULT_ALBEDO")


func test_single_layer_stack_compiles() -> void:
	var code := generate(surface(MINIMAL_SURFACE), [])

	check_contains(code, "shader_type spatial;", "declares a spatial shader")
	check_contains(code, "void fragment()", "emits a fragment function")
	check_contains(code, "void vertex()", "emits a vertex function")
	check_contains(code, "fragmentMaterial finalFragment", "seeds finalFragment")
	check_contains(code, "ALBEDO = finalFragment.layer_mat_albedo", "writes the final albedo")
	check_contains(code, "uniform vec3 s_layer_0_tint", "namespaces the base layer uniform")
