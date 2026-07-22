extends SceneTree

## Diagnostic: prints the shader generated for a named scenario, so a failing
## case can be read rather than guessed at.
##
##     godot --headless --path test --script res://tools/dump_generated.gd -- layerdata
##
## Scenarios: layerdata, helper, const, instanceuniform, arrayuniform, struct

const HEAD := """shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
"""

const SCENARIOS := {
	"layerdata": HEAD + """
uniform float value = 1.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_TEX_0 = vec4(value);
	LAYER_OUT_MASK_0 = value;
	LAYER_OUT_ALBEDO = LAYER_BELOW_TEX_0.rgb + vec3(LAYER_BELOW_MASK_0);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""",
	"helper": HEAD + """
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
""",
	"const": HEAD + """
uniform float value = 1.0;
const float SCALE = 2.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value * SCALE);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""",
	"instanceuniform": HEAD + """
uniform float value = 1.0;
instance uniform float perInstance = 0.0;
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = vec3(value + perInstance);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""",
	"arrayuniform": HEAD + """
uniform float value = 1.0;
uniform vec4 palette[4];
void fragment() {
	SETUP_LAYER_FRAGMENT;
	LAYER_OUT_ALBEDO = palette[0].rgb * value;
	ALBEDO = LAYER_OUT_ALBEDO;
}
""",
	"struct": HEAD + """
uniform float value = 1.0;
struct Pair { float a; float b; };
void fragment() {
	SETUP_LAYER_FRAGMENT;
	Pair p;
	p.a = value;
	p.b = 1.0;
	LAYER_OUT_ALBEDO = vec3(p.a, p.b, 0.0);
	ALBEDO = LAYER_OUT_ALBEDO;
}
""",
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "layerdata"

	if not SCENARIOS.has(which):
		printerr("unknown scenario: ", which, "  (have: ", ", ".join(SCENARIOS.keys()), ")")
		quit(1)
		return

	var mat := SurfaceMaterial.new()
	mat.shader.code = SCENARIOS[which]

	var stack := LayerStack.new()
	stack.base_layer = mat
	stack.compile()

	print("========== GENERATED (", which, ") ==========")
	print(stack.shader.code)
	print("========== END ==========")
	quit(0)


func _process(_delta: float) -> bool:
	return true
