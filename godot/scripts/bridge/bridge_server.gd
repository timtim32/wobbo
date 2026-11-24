extends Node
## WebSocket endpoint for the bridge (claude-bridge D1, D2, D9). Listens on 127.0.0.1
## only, publishes port and token in bridge.json (mode 0600), checks the token
## in `hello`, and routes messages into a SessionRegistry. The `Bridge` autoload
## (bridge.gd) starts it; tests start their own instance.

signal session_added(session_id: String)
signal session_changed(session_id: String)
signal session_removed(session_id: String)
signal message_received(session_id: String, text: String)
signal request_added(request: Dictionary)
signal request_removed(request: Dictionary)
## A request was answered or dismissed through answer_request(), after
## request_removed. Lets the app answer its own local requests (the welcome).
signal request_answered(request: Dictionary, status: String, choice: String, text: String)
## An event was applied to a session, also while a request keeps it waiting
## (balloons-and-speech D4). `kind` is the protocol's event kind.
signal session_event(session_id: String, kind: String, data: Dictionary)

const Protocol := preload("res://scripts/bridge/protocol.gd")
const SessionRegistry := preload("res://scripts/core/session_registry.gd")
const APP_VERSION := "0.1.0"
const TICK_SEC := 1.0


## One WebSocket connection from a bridge process (claude-bridge D1).
class Connection:
	extends RefCounted
	var ws: WebSocketPeer
	var ready := false # a hello with the right token arrived
	var deadline := 0 # ticks (msec) by which the hello must arrive
	var client := {} # the client info from the hello
	var session := "" # MCP: id of the session this connection speaks for
	var rejected := false # an error was sent; further frames are ignored
	var close_at := -1 # ticks (msec) at which to close a rejected connection, or -1


var registry := SessionRegistry.new()
var port := 0
var token := ""
var info_path := ""

var _server := TCPServer.new()
var _conns: Dictionary = {} # connection id -> Connection
var _next_conn := 1
var _tick_left := TICK_SEC


func is_running() -> bool:
	return _server.is_listening()


## Starts listening on the first free port from `base_port` and writes the info file.
func start(p_info_path: String, base_port := Protocol.DEFAULT_PORT, tries := Protocol.PORT_TRIES) -> Error:
	for i in tries:
		if _server.listen(base_port + i, "127.0.0.1") == OK:
			port = base_port + i
			break
	if not _server.is_listening():
		push_warning("Bridge: no free port in %d-%d; agents cannot connect." % [base_port, base_port + tries - 1])
		return ERR_CANT_OPEN
	token = Crypto.new().generate_random_bytes(32).hex_encode()
	info_path = p_info_path
	var err := _write_info()
	if err != OK:
		push_warning("Bridge: could not write %s (%s)." % [info_path, error_string(err)])
	print("Bridge: listening on 127.0.0.1:%d" % port)
	return OK


func stop() -> void:
	for id: int in _conns.keys():
		(_conns[id] as Connection).ws.close(1001, "app quitting")
	_conns.clear()
	_server.stop()
	if not info_path.is_empty() and FileAccess.file_exists(info_path):
		DirAccess.remove_absolute(info_path)


func _exit_tree() -> void:
	stop()


func _write_info() -> Error:
	var dir := info_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	if FileAccess.file_exists(info_path):
		DirAccess.remove_absolute(info_path)
	var f := FileAccess.open(info_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	# Restrict permissions before the token is written.
	FileAccess.set_unix_permissions(info_path, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
	f.store_string(JSON.stringify({"port": port, "token": token, "pid": OS.get_process_id(),
		"protocol": Protocol.VERSION}))
	f.close()
	return OK


func _process(delta: float) -> void:
	poll(Time.get_ticks_msec())
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK_SEC
		for id in registry.tick(Time.get_ticks_msec()):
			session_removed.emit(id)


## Accepts new connections and handles incoming frames. Public for tests.
func poll(now_msec: int) -> void:
	if not _server.is_listening():
		return
	while _server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(_server.take_connection())
		var c := Connection.new()
		c.ws = ws
		c.deadline = now_msec + Protocol.HELLO_TIMEOUT_MS
		_conns[_next_conn] = c
		_next_conn += 1
	for id: int in _conns.keys():
		var c: Connection = _conns[id]
		var ws := c.ws
		ws.poll()
		# Read frames first: a hook sends its event and closes right away, so the
		# frame and the close often arrive in the same poll.
		while not c.rejected and ws.get_available_packet_count() > 0:
			_handle(id, ws.get_packet().get_string_from_utf8(), now_msec)
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_on_closed(id)
			continue
		if c.close_at >= 0:
			if now_msec >= c.close_at:
				c.close_at = -1
				ws.close(1008, "rejected")
			continue
		if not c.ready and now_msec > c.deadline:
			_reject(id, "no_hello")


func _send(id: int, message: Dictionary) -> void:
	if not _conns.has(id):
		return
	message["v"] = Protocol.VERSION
	(_conns[id] as Connection).ws.send_text(JSON.stringify(message))


## Sends an error and closes shortly after, so the error frame is delivered first.
func _reject(id: int, reason: String) -> void:
	_send(id, {"type": "error", "reason": reason})
	var c: Connection = _conns[id]
	c.close_at = Time.get_ticks_msec() + 100
	c.rejected = true


func _handle(id: int, text: String, now_msec: int) -> void:
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	var c: Connection = _conns[id]
	if int(msg.get("v", 0)) != Protocol.VERSION:
		_reject(id, "unsupported_version")
		return
	if not c.ready:
		if msg.get("type") != "hello" or String(msg.get("token", "")) != token:
			_reject(id, "bad_token")
			return
		c.ready = true
		c.client = msg.get("client", {}) if typeof(msg.get("client")) == TYPE_DICTIONARY else {}
		_send(id, {"type": "welcome", "app_version": APP_VERSION})
		return
	var ts := int(msg.get("ts", 0))
	match msg.get("type"):
		"event":
			var info: Dictionary = _resolve_session(c, msg, now_msec)
			var existed := registry.has_session(info.id)
			var data: Dictionary = msg.get("data", {}) if typeof(msg.get("data")) == TYPE_DICTIONARY else {}
			_apply_event(info, existed, String(msg.get("kind", "")), data, ts, now_msec, int(c.client.get("ppid", 0)))
			_finish_hook(id)
		"say":
			var info: Dictionary = _resolve_session(c, msg, now_msec)
			if registry.set_message(info.id, String(msg.get("text", "")), now_msec):
				message_received.emit(info.id, String(msg.get("text", "")))
				session_changed.emit(info.id)
			_finish_hook(id)
		"request":
			var info: Dictionary = _resolve_session(c, msg, now_msec)
			var choices: Array = msg.get("choices", []) if typeof(msg.get("choices")) == TYPE_ARRAY else []
			var request := {"id": String(msg.get("id", "")), "session_id": info.id,
				"kind": String(msg.get("kind", Protocol.REQUEST_QUESTION)), "text": String(msg.get("text", "")),
				"choices": choices.map(func(x: Variant) -> String: return String(x)),
				"allow_text": bool(msg.get("allow_text", false)), "owner": id,
				"timeout_s": int(msg.get("timeout_s", 0))}
			if not request.id.is_empty() and registry.add_request(request, now_msec):
				request_added.emit(request)
				session_changed.emit(info.id)
		"cancel":
			_remove_request(String(msg.get("id", "")))


func _apply_event(info: Dictionary, existed: bool, kind: String, data: Dictionary, ts: int, now_msec: int,
		ppid: int) -> void:
	var changed := registry.apply_event(info, kind, data, ts, now_msec, ppid)
	if not existed and registry.has_session(info.id):
		print("Bridge: new %s session %s (%s, ppid %d)" % [info.agent, info.id,
			registry.get_session(info.id).name, ppid])
		session_added.emit(info.id)
	elif changed:
		session_changed.emit(info.id)
	if changed:
		session_event.emit(String(info.id), kind, data)


## An event from inside the app (the demo, session-avatars D11): handled like a
## received one. `info`: {id, agent, project_dir}.
func local_event(info: Dictionary, kind: String, data := {}) -> void:
	var now := Time.get_ticks_msec()
	_apply_event(info, registry.has_session(String(info.id)), kind, data, int(Time.get_unix_time_from_system() * 1000.0),
		now, 0)


## A request from inside the app. Its owner is no connection, so an answer is dropped.
## `kind`, `allow_text` and `timeout_s` as in a received request (for checks of
## permission prompts and text answers).
func local_request(session_id: String, request_id: String, text: String, choices: Array,
		kind := Protocol.REQUEST_QUESTION, allow_text := false, timeout_s := 0) -> bool:
	var request := {"id": request_id, "session_id": session_id, "kind": kind,
		"text": text, "choices": choices.map(func(x: Variant) -> String: return String(x)),
		"allow_text": allow_text, "owner": -1, "timeout_s": timeout_s}
	if not registry.add_request(request, Time.get_ticks_msec()):
		return false
	request_added.emit(request)
	session_changed.emit(session_id)
	return true


## A message from inside the app (the welcome buddy): shown like a received `say`.
func local_say(session_id: String, text: String) -> void:
	if registry.set_message(session_id, text, Time.get_ticks_msec()):
		message_received.emit(session_id, text)


## Removes a request without answering anyone (the demo ending).
func withdraw_request(request_id: String) -> void:
	_remove_request(request_id)


## A hook connection carries one message: the app closes it once handled. The
## hook waits for that close instead of closing itself, because Godot drops a
## frame that arrives in the same poll as the peer's close frame.
func _finish_hook(id: int) -> void:
	var c: Connection = _conns.get(id)
	if c and c.client.get("role") == Protocol.ROLE_HOOK:
		c.ws.close(1000, "done")


## The session a message belongs to, as {id, agent, project_dir} (plus
## focus_url when the message names one): the session the message names (hooks),
## else the one its MCP connection speaks for (claude-bridge D6).
## Side effects: a session that a non-event message names but the registry does
## not know yet is created and session_added is emitted for it; for MCP see
## _attribute_mcp_connection().
func _resolve_session(c: Connection, msg: Dictionary, now_msec: int) -> Dictionary:
	if typeof(msg.get("session")) == TYPE_DICTIONARY and not String(msg.session.get("id", "")).is_empty():
		var info: Dictionary = msg.session
		if not registry.has_session(String(info.id)) and msg.get("type") != "event":
			registry.ensure_session(info, now_msec, int(c.client.get("ppid", 0)))
			session_added.emit(String(info.id))
		return {"id": String(info.id), "agent": String(info.get("agent", c.client.get("agent", "unknown"))),
			"project_dir": String(info.get("project_dir", c.client.get("project_dir", ""))),
			"focus_url": String(info.get("focus_url", ""))}
	var s := _attribute_mcp_connection(c, now_msec)
	return {"id": s.id, "agent": s.agent, "project_dir": s.project_dir}


## The session an MCP connection speaks for (claude-bridge D6). Side effects: the
## registry may create that session (session_added is emitted for a new one), and
## when the connection moves to another session its connection count moves along
## and the change is logged.
func _attribute_mcp_connection(c: Connection, now_msec: int) -> SessionRegistry.Session:
	var known: Array = registry.sessions().map(func(s) -> String: return s.id)
	var s := registry.resolve_mcp_session(c.client, now_msec)
	if s.id != c.session:
		var previous := registry.get_session(c.session)
		if previous:
			previous.connections -= 1
		s.connections += 1
		c.session = s.id
		print("Bridge: MCP client %s (agent %s, pid %d, ppid %d) -> session %s (%s, ppid %d)" % [
			c.client.get("client_name", "?"), c.client.get("agent", "?"), int(c.client.get("pid", 0)),
			int(c.client.get("ppid", 0)), s.id, s.name, s.ppid])
	if not s.id in known:
		session_added.emit(s.id)
	return s


func _on_closed(id: int) -> void:
	var c: Connection = _conns[id]
	_conns.erase(id)
	var s := registry.get_session(c.session)
	if s:
		s.connections -= 1
	for request in registry.remove_requests_of(id):
		request_removed.emit(request)
		session_changed.emit(request.session_id)


func _remove_request(request_id: String) -> Dictionary:
	var request := registry.remove_request(request_id)
	if not request.is_empty():
		request_removed.emit(request)
		session_changed.emit(request.session_id)
	return request


## Sends the user's answer to the agent that asked (status "answered" or "dismissed").
func answer_request(request_id: String, choice := "", text := "", status := "answered") -> bool:
	var request := _remove_request(request_id)
	if request.is_empty():
		return false
	_send(int(request.owner), {"type": "answer", "id": request_id, "status": status,
		"choice": choice, "text": text})
	request_answered.emit(request, status, choice, text)
	return true


func dismiss_request(request_id: String) -> bool:
	return answer_request(request_id, "", "", "dismissed")
