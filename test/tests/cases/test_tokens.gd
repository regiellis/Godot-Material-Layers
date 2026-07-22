@tool
extends MLTestCase

## Every token the README documents must actually be rewritten into a struct
## field. A token that is not in the substitution tables stays a plain local
## declared by the SETUP_LAYER_* macro, so it compiles but silently reads a
## default and writes nowhere.

const HEAD := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
"""

const SURFACE_OUT_TOKENS := [
	"LAYER_OUT_ALBEDO", "LAYER_OUT_NORMAL_MAP", "LAYER_OUT_ROUGHNESS",
	"LAYER_OUT_HEIGHT", "LAYER_OUT_AO", "LAYER_OUT_METALLIC",
	"LAYER_OUT_EMISSION", "LAYER_OUT_BENT_NORMAL",
	"LAYER_OUT_MESH_NORMAL_MAP", "LAYER_OUT_MESH_AO",
	"LAYER_OUT_MESH_HEIGHT", "LAYER_OUT_MESH_CURVATURE",
	"LAYER_OUT_MESH_THICKNESS",
]

const BELOW_TOKENS := [
	"LAYER_BELOW_ALBEDO", "LAYER_BELOW_NORMAL_MAP", "LAYER_BELOW_ROUGHNESS",
	"LAYER_BELOW_HEIGHT", "LAYER_BELOW_AO", "LAYER_BELOW_METALLIC",
	"LAYER_BELOW_EMISSION", "LAYER_BELOW_BENT_NORMAL",
	"LAYER_BELOW_MESH_NORMAL_MAP", "LAYER_BELOW_MESH_AO",
	"LAYER_BELOW_MESH_HEIGHT", "LAYER_BELOW_MESH_CURVATURE",
	"LAYER_BELOW_MESH_THICKNESS",
]

const CURRENT_TOKENS := [
	"LAYER_CURRENT_ALBEDO", "LAYER_CURRENT_NORMAL_MAP", "LAYER_CURRENT_ROUGHNESS",
	"LAYER_CURRENT_HEIGHT", "LAYER_CURRENT_AO", "LAYER_CURRENT_METALLIC",
	"LAYER_CURRENT_EMISSION", "LAYER_CURRENT_BENT_NORMAL",
]

const RESULT_TOKENS := [
	"RESULT_ALBEDO", "RESULT_NORMAL_MAP", "RESULT_ROUGHNESS",
	"RESULT_HEIGHT", "RESULT_AO", "RESULT_METALLIC",
	"RESULT_EMISSION", "RESULT_BENT_NORMAL",
]

const PLAIN := HEAD + """
uniform vec3 tint = vec3(1.0);
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = tint;
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


## Reads a token in a surface shader and returns the generated code.
func _read_in_surface(token: String) -> String:
	var is_vec := token.ends_with("ALBEDO") or token.ends_with("NORMAL_MAP") \
		or token.ends_with("EMISSION") or token.ends_with("BENT_NORMAL")
	var expr := token if is_vec else "vec3(%s)" % token
	return generate(surface(HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = %s * value;
	ALBEDO = LAYER_OUT_ALBEDO;
}
""" % expr), [])


func test_layer_out_tokens_are_substituted() -> void:
	for token in SURFACE_OUT_TOKENS:
		var is_vec: bool = token.ends_with("ALBEDO") or token.ends_with("NORMAL_MAP") \
			or token.ends_with("EMISSION") or token.ends_with("BENT_NORMAL")
		var value: String = "vec3(0.5)" if is_vec else "0.5"
		var code := generate(surface(HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	%s = %s;
	LAYER_OUT_ALBEDO = vec3(value);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""" % [token, value]), [])
		check_not_contains(code, token, "%s is rewritten to a struct field" % token)


func test_layer_below_tokens_are_substituted() -> void:
	for token in BELOW_TOKENS:
		var code := _read_in_surface(token)
		check_not_contains(code, token, "%s is rewritten to a struct field" % token)


func test_layer_current_tokens_are_substituted() -> void:
	for token in CURRENT_TOKENS:
		var is_vec: bool = token.ends_with("ALBEDO") or token.ends_with("NORMAL_MAP") \
			or token.ends_with("EMISSION") or token.ends_with("BENT_NORMAL")
		var expr: String = token if is_vec else "vec3(%s)" % token
		var code := generate(surface(PLAIN), [material_masked_layer(PLAIN, HEAD + """
uniform float contrast = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	RESULT_ALBEDO = %s * contrast;
	RESULT_HEIGHT = LAYER_BELOW_HEIGHT;
}
""" % expr)])
		check_not_contains(code, token, "%s is rewritten to a struct field" % token)


func test_result_tokens_are_substituted() -> void:
	for token in RESULT_TOKENS:
		var is_vec: bool = token.ends_with("ALBEDO") or token.ends_with("NORMAL_MAP") \
			or token.ends_with("EMISSION") or token.ends_with("BENT_NORMAL")
		var value: String = "vec3(0.5)" if is_vec else "0.5"
		var code := generate(surface(PLAIN), [material_masked_layer(PLAIN, HEAD + """
uniform float contrast = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	%s = %s * contrast;
}
""" % [token, value])])
		check_not_contains(code, token, "%s is rewritten to a struct field" % token)


func test_layer_data_tex_and_mask_tokens() -> void:
	var code := generate(surface(HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_TEX_0 = vec4(value);
	LAYER_OUT_MASK_0 = value;
	LAYER_OUT_ALBEDO = LAYER_BELOW_TEX_0.rgb + vec3(LAYER_BELOW_MASK_0);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])
	check_not_contains(code, "LAYER_OUT_TEX_0", "LAYER_OUT_TEX_0 is rewritten")
	check_not_contains(code, "LAYER_OUT_MASK_0", "LAYER_OUT_MASK_0 is rewritten")
	check_not_contains(code, "LAYER_BELOW_TEX_0", "LAYER_BELOW_TEX_0 is rewritten")
	check_not_contains(code, "LAYER_BELOW_MASK_0", "LAYER_BELOW_MASK_0 is rewritten")
	check_compiles(code, "layerData tokens compile")


const TEX_WRITER := HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_TEX_0 = vec4(value);
	LAYER_OUT_MASK_0 = value;
	LAYER_OUT_ALBEDO = vec3(value);
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

const TEX_READER := HEAD + """
uniform float gain = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = LAYER_BELOW_TEX_0.rgb * gain + vec3(LAYER_BELOW_MASK_0);
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


## LAYER_BELOW_* resolves differently per slot: the defaults at 0, layer 0's
## struct at 1, and the running result above that. All three must be declared
## before the statement that reads them.
func test_layer_data_resolves_per_slot() -> void:
	var code := generate(surface(TEX_WRITER), [
		texture_masked_layer(TEX_READER),
		texture_masked_layer(TEX_READER),
	])

	check_contains(code, "layer_0_data.mat_layer_tex_0",
		"slot 1 reads layer 0's struct directly")
	check_contains(code, "finalLayerData.mat_layer_tex_0",
		"slot 2 reads the running result")
	check_eq(undeclared_tokens(code), [] as Array[String], "no dangling namespaced tokens")
	check_compiles(code, "layerData reads across three layers compile")


func test_layer_data_below_at_slot_zero_uses_defaults() -> void:
	var code := generate(surface(TEX_READER), [])

	check_contains(code, "DEFAULT_LAYER_DATA.mat_layer_tex_0",
		"the base layer reads the layerData defaults, not finalLayerData")
	check_compiles(code, "base layer reading LAYER_BELOW_TEX compiles")
