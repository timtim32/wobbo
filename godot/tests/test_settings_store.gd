extends "res://tests/base_test.gd"

const SettingsStore := preload("res://scripts/core/settings_store.gd")
const PATH := "user://test_settings.cfg"


func before_each() -> void:
	_remove_file()


func after_each() -> void:
	_remove_file()


func _remove_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_defaults_without_file() -> void:
	var store := SettingsStore.new(PATH)
	assert_eq(store.load_file(), OK, "missing file is not an error")
	assert_eq(store.get_value(&"overlay_visible"), true, "overlay_visible default")
	assert_eq(store.get_value(&"debug_regions"), false, "debug_regions default")
	assert_eq(store.get_value(&"screen"), "auto", "screen default (multi-display)")
	assert_eq(store.get_value(&"show_names"), true, "names shown by default (session-avatars)")
	assert_eq(store.get_value(&"buddy_size"), "normal", "Normal size by default (buddy-size)")
	assert_eq(store.get_value(&"unknown", 7), 7, "unknown key uses fallback")


func test_round_trip() -> void:
	var store := SettingsStore.new(PATH)
	assert_true(store.set_value(&"overlay_visible", false), "change reported")
	assert_false(store.set_value(&"overlay_visible", false), "same value is no change")
	store.set_value(&"debug_regions", true)
	store.set_value(&"output_mode", "speech")
	assert_eq(store.save_file(), OK, "save")

	var reloaded := SettingsStore.new(PATH)
	assert_eq(reloaded.load_file(), OK, "load")
	assert_eq(reloaded.get_value(&"overlay_visible"), false, "overlay_visible persisted")
	assert_eq(reloaded.get_value(&"debug_regions"), true, "debug_regions persisted")
	assert_eq(reloaded.get_value(&"output_mode"), "speech", "extra key persisted")


func test_corrupt_file_falls_back_to_defaults() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[settings]\noverlay_visible = = =\ndebug_regions=Vector2(1,\n")
	file.close()
	var store := SettingsStore.new(PATH)
	assert_true(store.load_file() != OK, "corrupt file reports an error")
	assert_eq(store.get_value(&"overlay_visible"), true, "overlay_visible default kept")
	assert_eq(store.get_value(&"debug_regions"), false, "debug_regions default kept")


func test_wrong_type_falls_back_to_default() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[settings]\noverlay_visible=\"nope\"\ndebug_regions=true\n")
	file.close()
	var store := SettingsStore.new(PATH)
	assert_eq(store.load_file(), OK, "load")
	assert_eq(store.get_value(&"overlay_visible"), true, "wrongly typed key uses default")
	assert_eq(store.get_value(&"debug_regions"), true, "valid key is loaded")


func test_old_file_without_screen_keys() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[settings]\noverlay_visible=false\ndebug_regions=true\n")
	file.close()
	var store := SettingsStore.new(PATH)
	assert_eq(store.load_file(), OK)
	assert_eq(store.get_value(&"screen"), "auto", "missing key gets the default")
	assert_eq(store.get_value(&"screen_name"), "")
	assert_eq(store.get_value(&"show_names"), true, "old file: names shown")
	assert_eq(store.get_value(&"buddy_size"), "normal", "old file: Normal size")
	store.set_value(&"screen", "2")
	store.save_file()
	var again := SettingsStore.new(PATH)
	again.load_file()
	assert_eq(again.get_value(&"screen"), "2", "round-trip")


func test_show_names_round_trip() -> void:
	var store := SettingsStore.new(PATH)
	store.set_value(&"show_names", false)
	store.save_file()
	var again := SettingsStore.new(PATH)
	again.load_file()
	assert_eq(again.get_value(&"show_names"), false)


func test_message_settings_defaults_and_old_file() -> void:
	var store := SettingsStore.new(PATH)
	store.load_file()
	assert_eq(store.get_value(&"messages"), "balloons", "Balloons by default (balloons-and-speech)")
	assert_eq(store.get_value(&"notify_done"), true, "Turn finished on by default")
	assert_eq(store.get_value(&"notify_errors"), true, "Errors on by default")
	assert_eq(store.get_value(&"connect_declined"), false, "Connect not declined by default (standalone-app)")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[settings]\noverlay_visible=true\nbuddy_size=\"large\"\n")
	file.close()
	var old := SettingsStore.new(PATH)
	assert_eq(old.load_file(), OK)
	assert_eq(old.get_value(&"messages"), "balloons", "old file: Balloons")
	assert_eq(old.get_value(&"notify_errors"), true, "old file: Errors on")


func test_message_settings_round_trip() -> void:
	var store := SettingsStore.new(PATH)
	store.set_value(&"messages", "off")
	store.set_value(&"notify_done", false)
	store.save_file()
	var again := SettingsStore.new(PATH)
	again.load_file()
	assert_eq(again.get_value(&"messages"), "off")
	assert_eq(again.get_value(&"notify_done"), false)


func test_colours_round_trip() -> void:
	var store := SettingsStore.new(PATH)
	assert_eq(store.get_colour("wobbo"), -1.0, "no choice by default")
	assert_true(store.set_colour("wobbo", 25.0), "choice reported")
	assert_false(store.set_colour("wobbo", 25.0), "same choice is no change")
	store.set_colour("iris-mobile", 355.0)
	assert_eq(store.save_file(), OK, "save")
	var reloaded := SettingsStore.new(PATH)
	assert_eq(reloaded.load_file(), OK, "load")
	assert_eq(reloaded.get_colour("wobbo"), 25.0, "wobbo kept")
	assert_eq(reloaded.get_colour("iris-mobile"), 355.0, "iris-mobile kept")
	assert_true(reloaded.set_colour("wobbo", -1.0), "forget reported")
	assert_eq(reloaded.get_colour("wobbo"), -1.0, "forgotten")
	assert_false(reloaded.set_colour("wobbo", -1.0), "forgetting twice is no change")


func test_bad_colours_are_dropped() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[colours]\nok=205.0\nodd=12.0\nword=\"red\"\n")
	file.close()
	var store := SettingsStore.new(PATH)
	assert_eq(store.load_file(), OK, "load")
	assert_eq(store.get_colour("ok"), 205.0, "known hue kept")
	assert_eq(store.get_colour("odd"), -1.0, "hue outside the set dropped")
	assert_eq(store.get_colour("word"), -1.0, "non-number dropped")
	assert_eq(store.colours().size(), 1, "only one choice")
