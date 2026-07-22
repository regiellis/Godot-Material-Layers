@tool
class_name MLTestCase
extends RefCounted

## Base class for Material Layers test cases.
##
## The runner instantiates a subclass, calls every method whose name starts with
## "test_", and reads `failures` afterwards. A case records problems instead of
## aborting, so one bad assertion does not hide the rest of the file.

var failures: Array[String] = []
var checks := 0

var _current_test := ""

func _begin(test_name: String) -> void:
	_current_test = test_name


func _fail(msg: String) -> void:
	failures.append("%s :: %s" % [_current_test, msg])


func check(condition: bool, msg: String) -> void:
	checks += 1
	if not condition:
		_fail(msg)


func check_contains(haystack: String, needle: String, msg: String) -> void:
	checks += 1
	if not haystack.contains(needle):
		_fail("%s (expected to find %s)" % [msg, _quote(needle)])


func check_not_contains(haystack: String, needle: String, msg: String) -> void:
	checks += 1
	if haystack.contains(needle):
		_fail("%s (did not expect %s)" % [msg, _quote(needle)])


func check_eq(actual: Variant, expected: Variant, msg: String) -> void:
	checks += 1
	if actual != expected:
		_fail("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func _quote(s: String) -> String:
	return "\"" + s.replace("\n", "\\n") + "\""


## Asserts that `code` survives Godot's shader compiler. Errors are printed to
## stderr by the engine, so a failure here is always accompanied by the reason.
func check_compiles(code: String, msg: String) -> void:
	checks += 1
	if not compiles(code):
		_fail("%s (shader did not compile; see SHADER ERROR above)" % msg)


## True when Godot accepts `code`. Relies on the uniform list being empty for a
## shader that failed to parse, so the code under test must declare a uniform.
static func compiles(code: String) -> bool:
	var sh := Shader.new()
	sh.code = code
	return sh.get_shader_uniform_list().size() > 0


# --- shared fixtures -------------------------------------------------------

## Builds a SurfaceMaterial carrying `code` verbatim.
static func surface(code: String) -> SurfaceMaterial:
	var mat := SurfaceMaterial.new()
	mat.shader.code = code
	return mat


## Builds a MaskMaterial carrying `code` verbatim.
static func mask(code: String) -> MaskMaterial:
	var mat := MaskMaterial.new()
	mat.shader.code = code
	return mat


## Builds a MaterialLayer using a MaskMaterial to blend.
static func material_masked_layer(surface_code: String, mask_code: String) -> MaterialLayer:
	var layer := MaterialLayer.new()
	layer.surface_material = surface(surface_code)
	layer.mask_type = MaterialLayer.MaskType.MATERIAL
	layer.mask_material = mask(mask_code)
	layer.mask_active = true
	return layer


## Builds a MaterialLayer blended by a mask texture.
static func texture_masked_layer(surface_code: String, tex: Texture2D = null) -> MaterialLayer:
	var layer := MaterialLayer.new()
	layer.surface_material = surface(surface_code)
	layer.mask_type = MaterialLayer.MaskType.TEXTURE
	layer.mask_texture = tex if tex else _white_texture()
	layer.mask_active = true
	return layer


## Compiles a stack and returns the generated shader code.
static func generate(base: SurfaceMaterial, layers: Array[MaterialLayer]) -> String:
	var stack := LayerStack.new()
	stack.base_layer = base
	stack.layers = layers
	stack.compile()
	return stack.shader.code if stack.shader else ""


static func _white_texture() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


# --- generated-code inspection --------------------------------------------

## Every namespaced token the generator produced, e.g. "s_layer_0_albedoTex".
static func prefixed_tokens(code: String) -> Array[String]:
	var rx := RegEx.new()
	rx.compile("\\b[sm]_layer_\\d+_\\w+\\b")
	var seen := {}
	var out: Array[String] = []
	for m in rx.search_all(code):
		var tok := m.get_string()
		if not seen.has(tok):
			seen[tok] = true
			out.append(tok)
	return out


## Namespaced tokens that are used but never declared. A non-empty result means
## the generated shader cannot compile.
static func undeclared_tokens(code: String) -> Array[String]:
	var out: Array[String] = []
	for tok in prefixed_tokens(code):
		if not _is_declared(code, tok):
			out.append(tok)
	return out


static func _is_declared(code: String, tok: String) -> bool:
	var types := "float|int|bool|uint|vec2|vec3|vec4|bvec2|bvec3|bvec4|ivec2|ivec3|ivec4|uvec2|uvec3|uvec4|mat2|mat3|mat4|void|sampler2D|sampler2DArray|samplerCube|sampler3D"
	var patterns := [
		"uniform\\s+[\\w]+\\s+" + tok + "\\b",           # uniform declaration
		"(?:" + types + ")\\s+" + tok + "\\s*\\(",        # function definition
		"(?:" + types + ")\\s+" + tok + "\\s*[=;,]",      # local / global declaration
		"varying\\s+[\\w\\s]*" + tok + "\\b",             # varying
		"struct\\s+" + tok + "\\b",                       # struct declaration
		"[sm]_layer_\\d+_\\w+\\s+" + tok + "\\s*[=;,]",   # local of a struct type
	]
	for p in patterns:
		var rx := RegEx.new()
		rx.compile(p)
		if rx.search(code) != null:
			return true
	return false
