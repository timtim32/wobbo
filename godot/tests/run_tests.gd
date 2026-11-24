extends SceneTree
## Headless test runner. Usage (from the repo root):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd
## Exits 0 when every test passes, 1 otherwise.

const TEST_DIR := "res://tests/"


var _done := false


## Tests run on the first frame, once the root (and the autoloads) are inside
## the active scene tree, so nodes added by tests get _ready() as usual.
func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_run()
	return false


func _run() -> void:
	var total := 0
	var failed := 0
	for file in _test_files():
		var script: GDScript = load(TEST_DIR + file)
		if script == null or not script.can_instantiate():
			printerr("FAIL %s: could not load script" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			total += 1
			var test: RefCounted = script.new()
			test.before_each()
			test.call(name)
			test.after_each()
			if test.failures.is_empty():
				print("  ok   %s::%s" % [file, name])
			else:
				failed += 1
				for message in test.failures:
					printerr("  FAIL %s::%s: %s" % [file, name, message])
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)


func _test_files() -> PackedStringArray:
	var files: PackedStringArray = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()
	return files
