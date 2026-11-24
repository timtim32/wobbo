extends RefCounted
## Pure settings storage on top of ConfigFile. No autoload or window dependency,
## so it can be unit tested headless. The `Settings` autoload wraps this class.

const SECTION := "settings"
const DEFAULTS := {
	&"overlay_visible": true,
	&"debug_regions": false,
	&"screen": "auto", # "auto" or a display id (multi-display D6)
	&"screen_name": "", # name of the chosen display, shown while it is disconnected
	&"show_names": true, # name labels above the avatars (session-avatars D5)
	&"buddy_size": "normal", # small, normal, large or xl (buddy-size D2)
	&"messages": "balloons", # balloons, speech, both or off (balloons-and-speech D8)
	&"notify_done": true, # "Turn finished" notices (balloons-and-speech D2)
	&"notify_errors": true, # "Errors" notices (balloons-and-speech D2)
	&"connect_declined": false, # "Not now" to the Connect offer (standalone-app D10)
}

var path: String
var _values: Dictionary = {}


func _init(p_path: String) -> void:
	path = p_path
	reset_to_defaults()


func reset_to_defaults() -> void:
	_values = {}
	for key: StringName in DEFAULTS:
		_values[key] = DEFAULTS[key]


## Loads the file. A missing file is not an error (defaults stay). On a parse or
## read error the defaults are kept and the error is returned for the caller to log.
func load_file() -> Error:
	reset_to_defaults()
	if not FileAccess.file_exists(path):
		return OK
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return err
	if not cfg.has_section(SECTION):
		return OK
	for key: String in cfg.get_section_keys(SECTION):
		var value: Variant = cfg.get_value(SECTION, key)
		var sname := StringName(key)
		# Known keys must keep their type; a mismatching value falls back to the default.
		if DEFAULTS.has(sname) and typeof(value) != typeof(DEFAULTS[sname]):
			continue
		_values[sname] = value
	return OK


func save_file() -> Error:
	var cfg := ConfigFile.new()
	for key: StringName in _values:
		cfg.set_value(SECTION, String(key), _values[key])
	return cfg.save(path)


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	if _values.has(key):
		return _values[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return fallback


## Returns true when the stored value actually changed.
func set_value(key: StringName, value: Variant) -> bool:
	if _values.has(key) and _values[key] == value and typeof(_values[key]) == typeof(value):
		return false
	_values[key] = value
	return true
