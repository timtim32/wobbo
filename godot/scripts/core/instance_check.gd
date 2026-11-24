extends RefCounted
## Whether another Wobbo is already running (standalone-app design D6). Pure: the
## `Instance` autoload reads bridge.json, checks the pid and the port, and asks
## `decide()`.

## How long the port check may take.
const PORT_TIMEOUT_MSEC := 200


## {pid, port} from bridge.json's text; {} when it is missing or not valid.
static func parse_info(text: String) -> Dictionary:
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not data is Dictionary:
		return {}
	var pid := int(data.get("pid", 0))
	var port := int(data.get("port", 0))
	if pid <= 0 or port <= 0:
		return {}
	return {"pid": pid, "port": port}


## {duplicate: bool, reason: String}. Another instance counts as alive only when
## its pid runs, is not ours, and its port takes connections (a reused pid after
## a crash fails the port check).
static func decide(info: Dictionary, own_pid: int, pid_running: bool, port_open: bool) -> Dictionary:
	if info.is_empty():
		return {"duplicate": false, "reason": "no running instance recorded"}
	if int(info.pid) == own_pid:
		return {"duplicate": false, "reason": "the recorded instance is this one"}
	if not pid_running:
		return {"duplicate": false, "reason": "the recorded instance (pid %d) is gone" % info.pid}
	if not port_open:
		return {"duplicate": false, "reason": "pid %d runs but does not listen on port %d" % [info.pid, info.port]}
	return {"duplicate": true, "reason": "Wobbo is already running (pid %d, port %d)" % [info.pid, info.port]}
