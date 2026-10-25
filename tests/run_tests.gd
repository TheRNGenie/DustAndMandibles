extends SceneTree
## Minimal headless test runner (no addon download needed):
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every test_*() method in tests/test_*.gd and exits with code 1 on failure.
## Test scripts extend TestCase. GUT can replace this later if wanted.


func _init() -> void:
	var failures := 0
	var passed := 0
	var dir := DirAccess.open("res://tests")
	var files: PackedStringArray = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script := load("res://tests/" + f) as GDScript
		for m: Dictionary in script.get_script_method_list():
			var method := str(m["name"])
			if not method.begins_with("test_"):
				continue
			var case := script.new() as TestCase
			case.call(method)
			if case.failures.is_empty():
				passed += 1
				print("  ok    %s.%s" % [f.get_basename(), method])
			else:
				failures += 1
				print("  FAIL  %s.%s" % [f.get_basename(), method])
				for msg in case.failures:
					print("        " + msg)
	print("%d passed, %d failed" % [passed, failures])
	quit(1 if failures > 0 else 0)
