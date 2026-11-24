extends Node
## `Instance` autoload, the first one: makes sure only one Wobbo runs per user,
## counting the app and editor runs alike (standalone-app design D6). A second
## instance sets `duplicate` and quits; the other autoloads and the boot scene
## then do nothing, so no window, menu bar icon or bridge.json write appears.

const InstanceCheck := preload("res://scripts/core/instance_check.gd")

var duplicate := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return # tests and tools never compete with the running app
	var path := OS.get_user_data_dir().path_join("bridge.json")
	var info := InstanceCheck.parse_info(FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "")
	var running := false
	var listening := false
	if not info.is_empty() and int(info.pid) != OS.get_process_id():
		running = _pid_running(int(info.pid))
		listening = running and _port_open(int(info.port))
	var verdict := InstanceCheck.decide(info, OS.get_process_id(), running, listening)
	if not verdict.duplicate:
		return
	duplicate = true
	print("Instance: %s; quitting. Quit the other Wobbo first to run this one." % verdict.reason)
	get_tree().quit()


## OS.is_process_running() only knows our own child processes; `kill -0` asks
## about any process of this user.
static func _pid_running(pid: int) -> bool:
	return OS.execute("/bin/kill", ["-0", str(pid)], [], false) == 0


static func _port_open(port: int) -> bool:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host("127.0.0.1", port) != OK:
		return false
	var deadline := Time.get_ticks_msec() + InstanceCheck.PORT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		tcp.poll()
		match tcp.get_status():
			StreamPeerTCP.STATUS_CONNECTED:
				tcp.disconnect_from_host()
				return true
			StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE:
				return false
		OS.delay_msec(5)
	tcp.disconnect_from_host()
	return false
