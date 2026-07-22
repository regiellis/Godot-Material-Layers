@tool
extends MLTestCase

## What survives the textual parser. The generator rebuilds the global section
## from the pieces it recognises (#include, uniform, global uniform, varying,
## helper functions), so anything it does not recognise is dropped on the floor.
## Each test states what a layer shader is allowed to contain.

const HEAD := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
"""

const TAIL := """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


func _gen(globals: String, body: String = TAIL) -> String:
	return generate(surface(HEAD + globals + body), [])


func test_plain_uniform_survives() -> void:
	var code := _gen("uniform float value = 1.0;\n")
	check_contains(code, "uniform float s_layer_0_value", "plain uniform is kept")
	check_compiles(code, "plain uniform compiles")


func test_uniform_with_hint_survives() -> void:
	var code := _gen("uniform vec3 value : source_color = vec3(1.0);\n")
	check_contains(code, "s_layer_0_value : source_color", "hint is preserved")
	check_compiles(code, "hinted uniform compiles")


func test_global_const_is_dropped() -> void:
	var code := _gen("uniform float value = 1.0;\nconst float SCALE = 2.0;\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value * SCALE);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_contains(code, "SCALE", "the const is referenced somewhere in the output")
	check_compiles(code, "a layer shader may declare a global const")


func test_define_is_dropped() -> void:
	var code := _gen("uniform float value = 1.0;\n#define DOUBLE(x) ((x) * 2.0)\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(DOUBLE(value));
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_compiles(code, "a layer shader may use its own #define")


func test_render_mode_is_dropped() -> void:
	var code := _gen("render_mode unshaded;\nuniform float value = 1.0;\n")
	check_contains(code, "render_mode", "render_mode reaches the generated shader")


func test_instance_uniform_is_dropped() -> void:
	var code := _gen("uniform float value = 1.0;\ninstance uniform float perInstance = 0.0;\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value + perInstance);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_compiles(code, "a layer shader may declare an instance uniform")


func test_array_uniform() -> void:
	var code := _gen("uniform float value = 1.0;\nuniform vec4 palette[4];\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = palette[0].rgb * value;
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_compiles(code, "a layer shader may declare an array uniform")


func test_struct_is_dropped() -> void:
	var code := _gen("uniform float value = 1.0;\nstruct Pair { float a; float b; };\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	Pair p;
	p.a = value;
	p.b = 1.0;
	LAYER_OUT_ALBEDO = vec3(p.a, p.b, 0.0);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_compiles(code, "a layer shader may declare a struct")


func test_varying_survives() -> void:
	var code := generate(surface(HEAD + """
uniform float value = 1.0;
varying vec3 worldPos;

void vertex() {
	SETUP_LAYER_VERTEX;
	worldPos = VERTEX;
	LAYER_OUT_VERTEX = VERTEX;
}

void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = worldPos * value;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [])
	check_contains(code, "varying vec3 worldPos", "varying is kept")
	check_compiles(code, "varying compiles")


func test_sampler_uniform_survives() -> void:
	var code := _gen("uniform float value = 1.0;\nuniform sampler2D albedoTex;\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = texture(albedoTex, UV).rgb * value;
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_contains(code, "uniform sampler2D s_layer_0_albedoTex", "sampler is namespaced")
	check_compiles(code, "sampler compiles")


func test_cube_sampler() -> void:
	var code := _gen("uniform float value = 1.0;\nuniform samplerCube env;\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = texture(env, NORMAL).rgb * value;
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_compiles(code, "a layer shader may declare a samplerCube")
