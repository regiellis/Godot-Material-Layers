extends SceneTree

## Headless verification that the example project works against the current
## addon: the scene loads with its dependencies, every LayerStack in the
## project compiles, and uniform values reach the generated material.
##
##     godot --headless --path examples/vcol-heightblend --script res://tools/verify_example.gd
##
## Exit code 0 means everything passed; anything else is the failure count.
##
## compile() rewrites assets/shaders/rockGroundMossStack.gdshader in place
## (the stack's shader has a resource_path), so that file doubles as a golden
## output: a git diff after this run means the generator's output changed.

const STACK_DIR := "res://assets/materialLayers/stacks"


func _initialize() -> void:
	var failures := 0

	# 1. The scene must load and actually use a LayerStack.
	var scene: PackedScene = load("res://materialLayers.tscn")
	if scene == null:
		printerr("FAIL materialLayers.tscn did not load")
		failures += 1
	else:
		var root := scene.instantiate()
		var found_stack := false
		for mesh in root.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.get_surface_override_material_count():
				if mesh.get_surface_override_material(i) is LayerStack:
					found_stack = true
		if found_stack:
			print("ok   materialLayers.tscn loads and a mesh uses a LayerStack")
		else:
			printerr("FAIL no MeshInstance3D in the scene uses a LayerStack")
			failures += 1
		root.free()

	# 2. Every stack in the project must compile to a working shader.
	var stack_count := 0
	var dir := DirAccess.open(STACK_DIR)
	if dir == null:
		printerr("FAIL cannot open " + STACK_DIR)
		failures += 1
	else:
		for file in dir.get_files():
			var res_name := file.trim_suffix(".remap")
			if not res_name.ends_with(".tres"):
				continue
			var res = load(STACK_DIR.path_join(res_name))
			if not (res is LayerStack):
				continue
			stack_count += 1
			var stack: LayerStack = res
			stack.compile()

			var sh := Shader.new()
			sh.code = stack.shader.code if stack.shader else ""
			if sh.get_shader_uniform_list().size() == 0:
				printerr("FAIL %s: generated shader does not compile" % res_name)
				failures += 1
				continue

			var set_params := 0
			for prop in stack.get_property_list():
				if prop.name.begins_with("shader_parameter/") and stack.get(prop.name) != null:
					set_params += 1
			if set_params == 0:
				printerr("FAIL %s: no uniform values were copied onto the stack" % res_name)
				failures += 1
			else:
				print("ok   %s: compiles, %d uniform values set" % [res_name, set_params])

	if stack_count == 0:
		printerr("FAIL no LayerStack resources found in " + STACK_DIR)
		failures += 1

	if failures == 0:
		print("EXAMPLE OK  scene loads, %d stack(s) verified" % stack_count)
	quit(failures)


## Safety net: if _initialize aborts on a script error, quit instead of
## spinning forever in headless mode.
func _process(_delta: float) -> bool:
	printerr("verify_example: reached the main loop without quitting - aborting")
	return true
