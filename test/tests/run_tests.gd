extends SceneTree

## Headless test runner for the Material Layers addon.
##
##     godot --headless --path test --script res://tests/run_tests.gd
##
## Exit code 0 means every check passed. Anything else is a failure count.
## Pass --case=<substring> after the script path to run a subset.

const CASE_DIR := "res://tests/cases"

var _verbose := false


func _initialize() -> void:
	_verbose = OS.get_cmdline_user_args().has("--verbose")
	var filter := _case_filter()
	var scripts := _discover(filter)

	if scripts.is_empty():
		printerr("no test cases found in %s (filter: %s)" % [CASE_DIR, filter])
		quit(1)
		return

	var total_checks := 0
	var all_failures: Array[String] = []

	for path in scripts:
		var script: GDScript = load(path)
		# A script with a parse error still loads as a GDScript, it just cannot
		# be instantiated. Treat that as a failure rather than crashing.
		if script == null or not script.can_instantiate():
			all_failures.append("%s :: failed to compile (see Parse Error above)" % path)
			print("FAIL %-28s could not be compiled" % path.get_file().get_basename())
			continue

		var case: MLTestCase = script.new()
		var name := path.get_file().get_basename()
		var case_failures := 0

		for method in _test_methods(script):
			case._begin("%s.%s" % [name, method])
			if _verbose:
				# stderr: unbuffered, so progress survives a kill on hang.
				printerr("     -> %s.%s" % [name, method])
			case.callv(method, [])

		total_checks += case.checks
		case_failures = case.failures.size()
		all_failures.append_array(case.failures)

		var status := "ok  " if case_failures == 0 else "FAIL"
		print("%s %-28s %d checks, %d failures" % [status, name, case.checks, case_failures])

	print("")
	if all_failures.is_empty():
		print("PASSED  %d checks across %d case(s)" % [total_checks, scripts.size()])
		quit(0)
		return

	print("FAILED  %d of %d checks" % [all_failures.size(), total_checks])
	for f in all_failures:
		print("  - " + f)
	quit(all_failures.size())


## Safety net. If _initialize() aborts on a script error, the SceneTree would
## otherwise spin forever in headless mode. Quitting on the first idle frame
## turns a hang into a reportable failure.
func _process(_delta: float) -> bool:
	printerr("run_tests: reached the main loop without quitting - aborting")
	return true


func _case_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			return arg.substr("--case=".length())
	return ""


func _discover(filter: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(CASE_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		# Exported/imported projects report .gd as .gd.remap; normalise.
		var name := file.trim_suffix(".remap")
		if not name.begins_with("test_") or not name.ends_with(".gd"):
			continue
		if filter != "" and not name.contains(filter):
			continue
		out.append(CASE_DIR.path_join(name))
	out.sort()
	return out


func _test_methods(script: GDScript) -> Array[String]:
	var out: Array[String] = []
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not out.has(n):
			out.append(n)
	out.sort()
	return out
