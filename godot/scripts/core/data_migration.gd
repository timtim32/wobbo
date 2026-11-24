extends RefCounted
## Moving the settings from the folder used before the rename to Wobbo
## (standalone-app design D5). Pure apart from `migrate()`, which copies the file.

const OLD_FOLDER := "ClaudeBuddy"
const SETTINGS_FILE := "settings.cfg"


## The settings file of the old app, next to the current user data folder:
## ".../Application Support/Wobbo" -> ".../Application Support/ClaudeBuddy/settings.cfg".
static func old_settings_path(user_dir: String) -> String:
	return user_dir.get_base_dir().path_join(OLD_FOLDER).path_join(SETTINGS_FILE)


## What to do at startup: {copy: bool, first_start: bool}. Copy only when the new
## file is missing and the old one exists; a true first start has neither.
static func plan(new_exists: bool, old_exists: bool) -> Dictionary:
	return {"copy": not new_exists and old_exists, "first_start": not new_exists and not old_exists}


## Copies the old settings file into `user_dir` when needed. Returns the plan
## plus {copied: bool}. A failed copy leaves no new file, so defaults apply.
static func migrate(user_dir: String) -> Dictionary:
	var new_file := user_dir.path_join(SETTINGS_FILE)
	var old_file := old_settings_path(user_dir)
	var result := plan(FileAccess.file_exists(new_file), FileAccess.file_exists(old_file))
	result["copied"] = false
	if result.copy:
		DirAccess.make_dir_recursive_absolute(user_dir)
		var err := DirAccess.copy_absolute(old_file, new_file)
		result.copied = err == OK
		if err == OK:
			print("Settings: copied %s from the old %s folder" % [SETTINGS_FILE, OLD_FOLDER])
		else:
			push_warning("Settings: could not copy %s (%s), using defaults." % [old_file, error_string(err)])
	return result
