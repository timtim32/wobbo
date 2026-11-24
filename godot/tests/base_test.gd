extends RefCounted
## Minimal base class for headless tests. Methods named `test_*` are run by
## res://tests/run_tests.gd on a fresh instance each.

var failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message)


func assert_true(value: bool, message := "expected true") -> void:
	if not value:
		fail(message)


func assert_false(value: bool, message := "expected false") -> void:
	if value:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%sexpected %s, got %s" % [message + ": " if message else "", var_to_str(expected), var_to_str(actual)])
