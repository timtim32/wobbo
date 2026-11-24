extends "res://scripts/bridge/bridge_server.gd"
## `Bridge` autoload: the app's endpoint for coding agents (claude-bridge).
## Not started in headless runs (tests and tools), so they never overwrite the
## running app's bridge.json, nor in a trailer run, which shows only its
## pretend sessions (TrailerMode).

const TrailerMode := preload("res://scripts/core/trailer_mode.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless" or Instance.duplicate:
		set_process(false)
		return
	if TrailerMode.active():
		print("Bridge: trailer run, not listening for agents")
		return
	start(OS.get_user_data_dir().path_join("bridge.json"))
