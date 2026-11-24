extends "res://tests/base_test.gd"

const DataMigration := preload("res://scripts/core/data_migration.gd")
const ROOT := "user://test_migration"

var _root := ""
var _new_dir := ""


func before_each() -> void:
	_root = ProjectSettings.globalize_path(ROOT)
	_remove_tree(_root)
	_new_dir = _root.path_join("Wobbo")
	DirAccess.make_dir_recursive_absolute(_new_dir)
	DirAccess.make_dir_recursive_absolute(_root.path_join("ClaudeBuddy"))


func after_each() -> void:
	_remove_tree(_root)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func test_old_path_is_next_to_the_user_folder() -> void:
	assert_eq(DataMigration.old_settings_path("/Users/x/Library/Application Support/Wobbo"),
		"/Users/x/Library/Application Support/ClaudeBuddy/settings.cfg")


func test_plan() -> void:
	assert_eq(DataMigration.plan(false, true), {"copy": true, "first_start": false}, "only the old file")
	assert_eq(DataMigration.plan(true, true), {"copy": false, "first_start": false}, "both files")
	assert_eq(DataMigration.plan(true, false), {"copy": false, "first_start": false}, "only the new file")
	assert_eq(DataMigration.plan(false, false), {"copy": false, "first_start": true}, "neither: first start")


func test_copies_the_old_file() -> void:
	_write(_root.path_join("ClaudeBuddy/settings.cfg"), "[settings]\nbuddy_size=\"xl\"\n")
	var r := DataMigration.migrate(_new_dir)
	assert_true(r.copied, "copied")
	assert_false(r.first_start, "not a first start")
	assert_eq(FileAccess.get_file_as_string(_new_dir.path_join("settings.cfg")), "[settings]\nbuddy_size=\"xl\"\n")


func test_keeps_the_new_file() -> void:
	_write(_root.path_join("ClaudeBuddy/settings.cfg"), "old")
	_write(_new_dir.path_join("settings.cfg"), "new")
	var r := DataMigration.migrate(_new_dir)
	assert_false(r.copied, "no copy")
	assert_eq(FileAccess.get_file_as_string(_new_dir.path_join("settings.cfg")), "new")


func test_first_start_without_files() -> void:
	var r := DataMigration.migrate(_new_dir)
	assert_true(r.first_start, "first start")
	assert_false(FileAccess.file_exists(_new_dir.path_join("settings.cfg")), "nothing created")


func test_unreadable_old_file_gives_defaults() -> void:
	_write(_root.path_join("ClaudeBuddy/settings.cfg"), "not [ a valid = cfg")
	DataMigration.migrate(_new_dir)
	var store: RefCounted = preload("res://scripts/core/settings_store.gd").new(_new_dir.path_join("settings.cfg"))
	store.load_file()
	assert_eq(store.get_value(&"buddy_size"), "normal", "defaults after a bad copy")
