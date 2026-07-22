@tool
extends MLTestCase

## Helper functions declared inside a layer shader. parse_helper_funcs() lifts
## them into the generated global scope and renames them; the call sites inside
## fragment()/vertex() have to be renamed to match.

const HEAD := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
"""

const WITH_HELPER := HEAD + """
uniform float strength = 1.0;

float boost(float x) {
	return clamp(x * 2.0, 0.0, 1.0);
}

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ROUGHNESS = boost(strength);
	LAYER_OUT_ALBEDO = vec3(strength);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

const MASK_WITH_HELPER := HEAD + """
uniform float contrast = 1.0;

float boost(float x) {
	return clamp(x * contrast, 0.0, 1.0);
}

void fragment() {
	SETUP_LAYER_FRAGMENT;
	float m = boost(LAYER_CURRENT_HEIGHT);
	RESULT_ALBEDO = mix(LAYER_BELOW_ALBEDO, LAYER_CURRENT_ALBEDO, m);
	RESULT_HEIGHT = LAYER_BELOW_HEIGHT;
}
"""

const PLAIN := HEAD + """
uniform vec3 tint = vec3(1.0);

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = tint;
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


func test_surface_helper_definition_and_call_agree() -> void:
	var code := generate(surface(WITH_HELPER), [])

	var dangling := undeclared_tokens(code)
	check_eq(dangling, [] as Array[String], "helper call sites resolve to a definition")
	check_compiles(code, "a surface shader with a helper function compiles")


func test_surface_helper_uses_surface_prefix() -> void:
	var code := generate(surface(WITH_HELPER), [])

	check_contains(code, "float s_layer_0_boost(", "surface helpers take the s_ prefix")
	check_not_contains(code, "float m_layer_0_boost(",
		"a surface helper must not be namespaced as a mask helper")


func test_surface_and_mask_helper_same_name() -> void:
	# Both shaders declare boost(). They must not collapse onto one symbol.
	var layer := material_masked_layer(WITH_HELPER, MASK_WITH_HELPER)
	var code := generate(surface(PLAIN), [layer])

	check_compiles(code, "a surface and its mask may both declare boost()")


func test_two_layers_declaring_the_same_helper() -> void:
	# Both layers declare boost(). Each must bind to its own copy.
	var code := generate(surface(WITH_HELPER), [texture_masked_layer(WITH_HELPER)])

	check_contains(code, "float s_layer_0_boost(", "layer 0 gets its own helper")
	check_contains(code, "float s_layer_1_boost(", "layer 1 gets its own helper")
	check_eq(undeclared_tokens(code), [] as Array[String], "every helper call resolves")
	check_compiles(code, "two layers with the same helper name compile")


func test_helper_reading_a_uniform() -> void:
	var code := generate(surface(HEAD + """
uniform float contrast = 2.0;
uniform sampler2D noiseTex;

float boost(float x) {
	return clamp(x * contrast, 0.0, 1.0);
}

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ROUGHNESS = boost(texture(noiseTex, UV).r);
	LAYER_OUT_ALBEDO = vec3(contrast);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])

	check_contains(code, "s_layer_0_contrast", "the uniform is namespaced inside the helper body")
	check_eq(undeclared_tokens(code), [] as Array[String], "helper body references resolve")
	check_compiles(code, "a helper reading a uniform compiles")


func test_void_helper_survives() -> void:
	var code := generate(surface(HEAD + """
uniform float fogAmount = 0.5;

void applyFog(inout vec3 color, float amount) {
	color = mix(color, vec3(0.5), amount);
}

void fragment() {
	SETUP_LAYER_FRAGMENT;
	vec3 c = vec3(fogAmount);
	applyFog(c, fogAmount);
	LAYER_OUT_ALBEDO = c;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])

	check_contains(code, "void s_layer_0_applyFog(", "void helpers are carried over")
	check_eq(undeclared_tokens(code), [] as Array[String], "the void helper call resolves")
	check_compiles(code, "a void helper compiles")


func test_helper_calling_another_helper() -> void:
	var code := generate(surface(HEAD + """
uniform float strength = 1.0;

float half_of(float x) {
	return x * 0.5;
}

float boost(float x) {
	return clamp(half_of(x) * 4.0, 0.0, 1.0);
}

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ROUGHNESS = boost(strength);
	LAYER_OUT_ALBEDO = vec3(strength);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])

	check_eq(undeclared_tokens(code), [] as Array[String], "nested helper calls resolve")
	check_compiles(code, "helper calling a helper compiles")
