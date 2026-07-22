@tool
extends MLTestCase

## The generator deletes statements that write Godot's built-in outputs
## (ALBEDO, ROUGHNESS, ...) because those exist only so a layer shader can
## render standalone for previews. The match must be on the identifier, not on
## a prefix, or user locals whose names merely start the same way vanish.

const HEAD := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
"""


func test_builtin_output_writes_are_stripped() -> void:
	var code := generate(surface(HEAD + """
uniform vec3 tint = vec3(1.0);
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = tint;
	ALBEDO = LAYER_OUT_ALBEDO;
	ROUGHNESS = 0.5;
}
"""), [])

	# The only ALBEDO assignment left should be the generator's own tail.
	check_eq(code.count("ALBEDO = "), 1, "exactly one ALBEDO write survives")
	check_contains(code, "ALBEDO = finalFragment.layer_mat_albedo",
		"the surviving write is the generated one")


func test_local_named_like_an_output_survives() -> void:
	var code := generate(surface(HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	float AOamount = value * 0.5;
	LAYER_OUT_AO = AOamount;
	LAYER_OUT_ALBEDO = vec3(AOamount);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])

	check_compiles(code, "a local whose name starts with AO survives")


func test_local_named_like_emission_survives() -> void:
	var code := generate(surface(HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	vec3 EMISSIONtint = vec3(value);
	LAYER_OUT_EMISSION = EMISSIONtint;
	LAYER_OUT_ALBEDO = EMISSIONtint;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])

	check_compiles(code, "a local whose name starts with EMISSION survives")


func test_control_flow_is_preserved() -> void:
	var code := generate(surface(HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	vec3 c = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		c += vec3(float(i) * value);
	}
	if (value > 0.5) {
		c *= 2.0;
	} else {
		c *= 0.5;
	}
	LAYER_OUT_ALBEDO = c;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])

	check_contains(code, "for (int", "for loop survives")
	check_contains(code, "else", "else branch survives")
	check_compiles(code, "control flow compiles")


func test_comments_do_not_break_parsing() -> void:
	var code := generate(surface(HEAD + """
uniform float value = 1.0; // trailing comment with a ; semicolon
/* block comment
   spanning lines with { braces } */
void fragment() {
	SETUP_LAYER_FRAGMENT;
	// LAYER_OUT_ALBEDO = vec3(9.0);
	LAYER_OUT_ALBEDO = vec3(value);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])

	check_not_contains(code, "trailing comment", "comments are stripped")
	check_not_contains(code, "vec3(9.0)", "commented-out code does not leak in")
	check_compiles(code, "commented shader compiles")
