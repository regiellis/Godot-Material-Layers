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


const SEA_LEVEL_BASE := HEAD + """
uniform float value = 1.0;
const float SEA_LEVEL = 0.5;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value * SEA_LEVEL);
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

const SEA_LEVEL_FROM_INCLUDE := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
#include "res://tests/fixtures/shared_const.gdshaderinc"

uniform float gain = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(gain * SEA_LEVEL);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


func test_layer_const_does_not_shadow_another_layers_include() -> void:
	# Layer 0 declares its own SEA_LEVEL; layer 1 gets SEA_LEVEL from an
	# include. Identifier renaming is scoped per layer, so layer 1's
	# reference must stay bare and resolve through the include.
	var code := generate(surface(SEA_LEVEL_BASE), [texture_masked_layer(SEA_LEVEL_FROM_INCLUDE)])

	check_contains(code, "s_layer_0_SEA_LEVEL", "layer 0's own const is namespaced")
	check_not_contains(code, "s_layer_1_SEA_LEVEL",
		"layer 1's include-provided const must not be renamed")
	check_compiles(code, "an include const shared across layers compiles")


func test_setup_macro_is_not_reexpanded() -> void:
	var code := _gen("uniform float value = 1.0;\n")
	check_not_contains(code, "SETUP_LAYER_FRAGMENT",
		"the fragment setup macro stays out of the merged shader")
	check_not_contains(code, "SETUP_LAYER_VERTEX",
		"the vertex setup macro stays out of the merged shader")
	check_compiles(code, "the merged shader works without the macro's locals")


func test_unknown_layer_token_fails_loudly() -> void:
	# Without the re-expanded macro, a token missing from the substitution
	# tables is an undeclared identifier instead of a silent constant.
	var code := _gen("uniform float value = 1.0;\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_BOGUS = value;
	LAYER_OUT_ALBEDO = vec3(value);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check(not compiles(code),
		"an unsubstituted layer token must be a compile error, not a silent default")


func test_plain_uniform_survives() -> void:
	var code := _gen("uniform float value = 1.0;\n")
	check_contains(code, "uniform float s_layer_0_value", "plain uniform is kept")
	check_compiles(code, "plain uniform compiles")


func test_uniform_with_hint_survives() -> void:
	var code := _gen("uniform vec3 value : source_color = vec3(1.0);\n")
	check_contains(code, "s_layer_0_value : source_color", "hint is preserved")
	check_compiles(code, "hinted uniform compiles")


func test_global_const_survives() -> void:
	var code := _gen("uniform float value = 1.0;\nconst float SCALE = 2.0;\nconst float HALF_SCALE = SCALE * 0.5;\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value * SCALE * HALF_SCALE);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_contains(code, "const float s_layer_0_SCALE = 2.0;",
		"const is carried over and namespaced")
	check_contains(code, "s_layer_0_SCALE * 0.5",
		"a const may reference an earlier const")
	check_compiles(code, "a layer shader may declare global consts")


func test_const_array_with_brace_initializer() -> void:
	var code := _gen("uniform float value = 1.0;\nconst float WEIGHTS[2] = {0.25, 0.75};\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value * WEIGHTS[0] + WEIGHTS[1]);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_contains(code, "s_layer_0_WEIGHTS[2]", "const array keeps its size")
	check_compiles(code, "a const array with a brace initializer compiles")


func test_define_survives() -> void:
	var code := _gen("uniform float value = 1.0;\n#define DOUBLE(x) ((x) * 2.0)\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(DOUBLE(value));
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_contains(code, "#define DOUBLE(x) ((x) * 2.0)", "the #define is carried over")
	check_compiles(code, "a layer shader may use its own #define")


const DEFINE_K1 := HEAD + """
uniform float value = 1.0;
#define K 1.0
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value * K);
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""

const DEFINE_K2 := HEAD + """
uniform float gain = 1.0;
#define K 2.0
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(gain * K);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


func test_conflicting_defines_keep_the_first() -> void:
	var code := generate(surface(DEFINE_K1), [texture_masked_layer(DEFINE_K2)])

	check_contains(code, "#define K 1.0", "the first definition is kept")
	check_not_contains(code, "#define K 2.0", "the conflicting redefinition is dropped")
	check_compiles(code, "a define conflict still yields a working shader")


func test_render_mode_carries_from_base() -> void:
	var code := _gen("render_mode unshaded;\nuniform float value = 1.0;\n")
	check_contains(code, "render_mode unshaded;", "base layer render_mode reaches the output")
	check_compiles(code, "render_mode carries from the base layer")


const RENDER_MODE_TOP := HEAD + """
render_mode unshaded;
uniform float gain = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(gain);
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


func test_render_mode_on_upper_layer_is_ignored() -> void:
	var code := generate(surface(HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value);
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""), [texture_masked_layer(RENDER_MODE_TOP)])

	check_not_contains(code, "render_mode", "only the base layer's render_mode is honoured")
	check_compiles(code, "an ignored render_mode still yields a working shader")


func test_base_layer_light_is_carried() -> void:
	var code := _gen("uniform float value = 1.0;\nuniform float wrap = 0.5;\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value);
	ALBEDO = LAYER_OUT_ALBEDO;
}

void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT) + wrap, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
}
""")
	check_contains(code, "void light() {", "the base layer's light() reaches the output")
	check_contains(code, "s_layer_0_wrap", "uniforms inside light() are namespaced")
	check_compiles(code, "a stack with a base light() compiles")


func test_instance_uniform_survives() -> void:
	var code := _gen("uniform float value = 1.0;\ninstance uniform float perInstance = 0.0;\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value + perInstance);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_contains(code, "instance uniform float s_layer_0_perInstance",
		"instance uniform is carried over and namespaced")
	check_compiles(code, "a layer shader may declare an instance uniform")


func test_array_uniform_survives() -> void:
	var code := _gen("uniform float value = 1.0;\nuniform vec4 palette[4];\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = palette[0].rgb * value;
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_contains(code, "uniform vec4 s_layer_0_palette[4]",
		"array uniform keeps its size and gets namespaced")
	check_compiles(code, "a layer shader may declare an array uniform")


func test_struct_survives() -> void:
	var code := _gen("uniform float value = 1.0;\nstruct Pair { float a; float b; };\n", """
void fragment() {
	SETUP_LAYER_FRAGMENT;
	Pair p = Pair(value, 1.0);
	LAYER_OUT_ALBEDO = vec3(p.a, p.b, 0.0);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""")
	check_contains(code, "struct s_layer_0_Pair", "struct is carried over and namespaced")
	check_contains(code, "s_layer_0_Pair(", "the constructor call is renamed to match")
	check_compiles(code, "a layer shader may declare a struct")


const STRUCT_LAYER := HEAD + """
uniform float value = 1.0;
struct Pair { float a; float b; };
void fragment() {
	SETUP_LAYER_FRAGMENT;
	Pair p = Pair(value, 1.0);
	LAYER_OUT_ALBEDO = vec3(p.a, p.b, 0.0);
	LAYER_OUT_HEIGHT = 0.5;
	ALBEDO = LAYER_OUT_ALBEDO;
}
"""


func test_same_struct_name_across_layers() -> void:
	var code := generate(surface(STRUCT_LAYER), [texture_masked_layer(STRUCT_LAYER)])

	check_contains(code, "struct s_layer_0_Pair", "layer 0 keeps its struct")
	check_contains(code, "struct s_layer_1_Pair", "layer 1 gets its own struct")
	check_compiles(code, "two layers may declare the same struct and local names")


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
