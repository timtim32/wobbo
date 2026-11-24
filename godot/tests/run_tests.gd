extends SceneTree
## Headless test runner. Usage (from the repo root):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd
## Exits 0 when every test passes, 1 otherwise.
##
## Tests are synchronous: a test that awaits fails, because nothing would wait
## for the rest of it. A script error inside a test fails it too
## (open-source-readiness D3).

const TEST_DIR := "res://tests/"
## Written by `--import` (or by opening the project in the editor). Without it,
## scripts that use another script's class_name do not compile.
const CLASS_CACHE := "res://.godot/global_script_class_cache.cfg"


## Counts the script errors Godot reports while a test runs.
class ErrorCounter extends Logger:
	var errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			errors.append("%s (%s:%d in %s)" % [rationale if rationale else code, file, line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _done := false


## Tests run on the first frame, once the root (and the autoloads) are inside
## the active scene tree, so nodes added by tests get _ready() as usual.
func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_run()
	return false


func _run() -> void:
	if not FileAccess.file_exists(CLASS_CACHE):
		printerr("The project has not been imported yet. Run this once, then run the tests again:")
		printerr("  /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --import")
		quit(1)
		return
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
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
			var failures := _run_test(script, name, counter)
			if failures.is_empty():
				print("  ok   %s::%s" % [file, name])
			else:
				failed += 1
				for message in failures:
					printerr("  FAIL %s::%s: %s" % [file, name, message])
	OS.remove_logger(counter)
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)


func _run_test(script: GDScript, name: String, counter: ErrorCounter) -> PackedStringArray:
	counter.errors.clear()
	var test: RefCounted = script.new()
	test.before_each()
	var result: Variant = test.call(name)
	test.after_each()
	var failures: PackedStringArray = test.failures.duplicate()
	# An awaiting test returns a GDScriptFunctionState, a class GDScript can't name.
	if result is Object and (result as Object).get_class() == "GDScriptFunctionState":
		failures.append("the test awaits; tests must be synchronous")
	for error in counter.errors:
		failures.append("script error: " + error)
	return failures


func _test_files() -> PackedStringArray:
	var files: PackedStringArray = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()
	return files
