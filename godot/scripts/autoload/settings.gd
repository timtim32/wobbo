extends Node
## `Settings` autoload: persisted per-user settings in user://settings.cfg
## (~/Library/Application Support/Wobbo/settings.cfg). Saves on every change. On
## start it copies the settings of the app from before the rename (standalone-app D5).

signal changed(key: StringName, value: Variant)

const SettingsStore := preload("res://scripts/core/settings_store.gd")
const MessagePolicy := preload("res://scripts/core/message_policy.gd")
const DataMigration := preload("res://scripts/core/data_migration.gd")
const TrailerMode := preload("res://scripts/core/trailer_mode.gd")
const PATH := "user://settings.cfg"

var _store: SettingsStore
## True when neither this nor the old app had saved settings: the welcome shows
## (standalone-app D10).
var first_start := false
## Changes stay in memory and are not saved (a trailer run, TrailerMode).
var transient := false

var overlay_visible: bool:
	get:
		return _store.get_value(&"overlay_visible")
	set(value):
		set_value(&"overlay_visible", value)

var debug_regions: bool:
	get:
		return _store.get_value(&"debug_regions")
	set(value):
		set_value(&"debug_regions", value)

## "auto" (follow the pointer) or the id of the home display (multi-display D6).
var screen: String:
	get:
		return _store.get_value(&"screen")
	set(value):
		set_value(&"screen", value)

## Name of the chosen display, shown in the menu while it is disconnected.
var screen_name: String:
	get:
		return _store.get_value(&"screen_name")
	set(value):
		set_value(&"screen_name", value)

## Name labels above the buddies (session-avatars D5).
var show_names: bool:
	get:
		return _store.get_value(&"show_names")
	set(value):
		set_value(&"show_names", value)

## small, normal, large or xl (buddy-size D2).
var buddy_size: String:
	get:
		return _store.get_value(&"buddy_size")
	set(value):
		set_value(&"buddy_size", value)


## balloons, speech, both or off; an unknown stored value reads as balloons
## (balloons-and-speech D8).
var messages: String:
	get:
		return MessagePolicy.mode_of(_store.get_value(&"messages"))
	set(value):
		set_value(&"messages", value)

## "Turn finished" notices (balloons-and-speech D2).
var notify_done: bool:
	get:
		return _store.get_value(&"notify_done")
	set(value):
		set_value(&"notify_done", value)

## "Errors" notices (balloons-and-speech D2).
var notify_errors: bool:
	get:
		return _store.get_value(&"notify_errors")
	set(value):
		set_value(&"notify_errors", value)

## The user said "Not now" to the welcome's Connect offer, so it is not offered
## at start again; the menu still offers it (standalone-app D10).
var connect_declined: bool:
	get:
		return _store.get_value(&"connect_declined")
	set(value):
		set_value(&"connect_declined", value)


func _init() -> void:
	transient = TrailerMode.active()
	first_start = DataMigration.migrate(OS.get_user_data_dir()).first_start
	_store = SettingsStore.new(PATH)
	var err := _store.load_file()
	if err != OK and not first_start:
		push_warning("Settings: could not load %s (%s), using defaults." % [PATH, error_string(err)])
	# Values are saved only when they change, so a user who only connects would
	# never get a settings file and see the first-start welcome on every start.
	# Write it now; headless runs (tests) leave the real data folder alone.
	if first_start and not transient and DisplayServer.get_name() != "headless":
		err = _store.save_file()
		if err != OK:
			push_warning("Settings: could not save %s (%s)." % [PATH, error_string(err)])


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return _store.get_value(key, fallback)


func set_value(key: StringName, value: Variant) -> void:
	if not _store.set_value(key, value):
		return
	var err := OK if transient else _store.save_file()
	if err != OK:
		push_warning("Settings: could not save %s (%s)." % [PATH, error_string(err)])
	changed.emit(key, value)
