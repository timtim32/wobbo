extends "res://tests/base_test.gd"
## Debug features exist only in debug builds (open-source-readiness D2).

var _transient: bool
var _debug_build: bool
var _saved: bool


func before_each() -> void:
	_transient = Settings.transient
	_debug_build = Settings.debug_build
	_saved = Settings.get_value(&"debug_regions")
	Settings.transient = true # keep the real settings file untouched


func after_each() -> void:
	Settings.set_value(&"debug_regions", _saved)
	Settings.debug_build = _debug_build
	Settings.transient = _transient


func test_debug_regions_follow_the_setting_in_a_debug_build() -> void:
	Settings.debug_build = true
	Settings.set_value(&"debug_regions", true)
	assert_true(Settings.debug_regions, "on when saved on")
	Settings.set_value(&"debug_regions", false)
	assert_false(Settings.debug_regions, "off when saved off")


func test_debug_regions_are_off_in_a_release_build() -> void:
	Settings.debug_build = false
	Settings.set_value(&"debug_regions", true)
	assert_false(Settings.debug_regions, "a saved 'on' is ignored")
