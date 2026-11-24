extends "res://tests/base_test.gd"
## The app endpoint with a real WebSocket client on loopback (design D1, D2).

const BridgeServer := preload("res://scripts/bridge/bridge_server.gd")
const INFO_PATH := "user://test_bridge.json"
const BASE_PORT := 47400

var server: Node
var events: Array = []
var session_events: Array = []


func before_each() -> void:
	server = BridgeServer.new()
	server.set_process(false)
	(Engine.get_main_loop() as SceneTree).root.add_child(server)
	server.start(ProjectSettings.globalize_path(INFO_PATH), BASE_PORT, 20)
	events.clear()
	session_events.clear()
	for sig in ["session_added", "session_changed", "message_received", "request_added", "request_removed"]:
		server.connect(sig, func(a: Variant = null, b: Variant = null) -> void: events.append([sig, a, b]))
	server.session_event.connect(func(id: String, kind: String, data: Dictionary) -> void:
		session_events.append([id, kind, data]))


func after_each() -> void:
	server.stop()
	server.free()


func _pump(client: WebSocketPeer, until: Callable, max_ms := 2000) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < max_ms:
		client.poll()
		server.poll(Time.get_ticks_msec())
		if until.call():
			return true
		OS.delay_msec(2)
	return false


func _connect(token: String, client_info := {"role": "hook", "agent": "claude-code", "pid": 1, "ppid": 4100}) -> WebSocketPeer:
	var ws := WebSocketPeer.new()
	ws.connect_to_url("ws://127.0.0.1:%d" % server.port)
	_pump(ws, func() -> bool: return ws.get_ready_state() == WebSocketPeer.STATE_OPEN)
	ws.send_text(JSON.stringify({"v": 1, "type": "hello", "token": token, "client": client_info}))
	return ws


func _receive(ws: WebSocketPeer) -> Dictionary:
	var got := {}
	_pump(ws, func() -> bool:
		if ws.get_available_packet_count() > 0:
			got.merge(JSON.parse_string(ws.get_packet().get_string_from_utf8()))
			return true
		return ws.get_ready_state() == WebSocketPeer.STATE_CLOSED)
	return got


func _send(ws: WebSocketPeer, msg: Dictionary) -> void:
	msg["v"] = 1
	ws.send_text(JSON.stringify(msg))
	_pump(ws, func() -> bool: return false, 60)


func test_info_file_is_private_and_removed_on_stop() -> void:
	var path := ProjectSettings.globalize_path(INFO_PATH)
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(int(info.port), server.port, "port published")
	assert_eq(String(info.token).length(), 64, "32-byte token as hex")
	assert_eq(int(info.pid), OS.get_process_id(), "pid published")
	var perms := FileAccess.get_unix_permissions(path)
	assert_eq(perms & 0x1FF, 0x180, "only the owner can read and write (0600)")
	server.stop()
	assert_false(FileAccess.file_exists(path), "removed on stop")


func test_handshake_with_token() -> void:
	var ws := _connect(server.token)
	var welcome := _receive(ws)
	assert_eq(welcome.get("type"), "welcome")
	assert_eq(welcome.get("app_version"), ProjectSettings.get_setting("application/config/version"), "the app's own version")
	ws.close()


func test_wrong_token_is_rejected() -> void:
	var ws := _connect("not-the-token")
	var reply := _receive(ws)
	assert_eq(reply.get("reason"), "bad_token")
	_pump(ws, func() -> bool: return ws.get_ready_state() == WebSocketPeer.STATE_CLOSED)
	assert_eq(ws.get_ready_state(), WebSocketPeer.STATE_CLOSED, "connection closed")


func test_only_loopback() -> void:
	# A connection to any non-loopback address of this machine must never reach
	# the server. (On macOS StreamPeerTCP briefly reports CONNECTED before the
	# reset, so the check is on the server side.)
	var tried := 0
	for address in IP.get_local_addresses():
		if address.begins_with("127.") or address.contains(":"):
			continue
		tried += 1
		var tcp := StreamPeerTCP.new()
		tcp.connect_to_host(address, server.port)
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 300:
			tcp.poll()
			server.poll(Time.get_ticks_msec())
			OS.delay_msec(5)
		assert_eq(server._conns.size(), 0, "no connection accepted via %s" % address)
		tcp.disconnect_from_host()
	print("    loopback test tried %d non-loopback address(es)" % tried)


func test_events_create_and_update_a_session() -> void:
	# Like real hooks: one connection per event.
	var session := {"id": "s1", "agent": "claude-code", "project_dir": "/Users/me/Projects/api"}
	var ws := _connect(server.token)
	_receive(ws)
	_send(ws, {"type": "event", "ts": 1, "session": session, "kind": "prompt", "data": {}})
	ws = _connect(server.token)
	_receive(ws)
	_send(ws, {"type": "event", "ts": 2, "session": session, "kind": "tool_start", "data": {"tool": "Bash"}})
	var s = server.registry.get_session("s1")
	assert_true(s != null, "session added")
	assert_eq(s.state, &"working")
	assert_eq(s.ppid, 4100, "ppid from hello")
	assert_eq(events[0][0], "session_added")
	ws.close()


func test_mcp_question_round_trip() -> void:
	var ws := _connect(server.token, {"role": "mcp", "agent": "claude-desktop", "pid": 77, "ppid": 1,
		"project_dir": "", "client_name": "claude-ai"})
	_receive(ws)
	_send(ws, {"type": "say", "ts": 1, "session": null, "text": "Hello"})
	_send(ws, {"type": "request", "ts": 2, "id": "r1", "session": null, "kind": "question",
		"text": "Continue?", "choices": ["yes", "no"], "allow_text": false, "timeout_s": 60})
	var s = server.registry.get_session("mcp:77")
	assert_true(s != null, "MCP-only client has its own session")
	assert_eq(s.name, "Claude Desktop")
	assert_eq(s.last_message, "Hello")
	assert_eq(s.state, &"waiting")
	assert_true(server.answer_request("r1", "no"))
	var answer := _receive(ws)
	assert_eq(answer.get("type"), "answer")
	assert_eq(answer.get("status"), "answered")
	assert_eq(answer.get("choice"), "no")
	assert_false(s.state == &"waiting", "no longer waiting")
	ws.close()


func test_closing_connection_withdraws_requests() -> void:
	var ws := _connect(server.token, {"role": "mcp", "agent": "claude-code", "pid": 9, "ppid": 4100, "project_dir": "/p"})
	_receive(ws)
	_send(ws, {"type": "request", "ts": 1, "id": "r9", "session": null, "kind": "question", "text": "?"})
	assert_true(server.registry.requests.has("r9"))
	ws.close()
	_pump(ws, func() -> bool: return not server.registry.requests.has("r9"))
	assert_false(server.registry.requests.has("r9"), "request withdrawn on disconnect")


func test_cancel_withdraws_request() -> void:
	var ws := _connect(server.token, {"role": "mcp", "agent": "claude-code", "pid": 9, "ppid": 4100, "project_dir": "/p"})
	_receive(ws)
	_send(ws, {"type": "request", "ts": 1, "id": "r5", "session": null, "kind": "question", "text": "?"})
	_send(ws, {"type": "cancel", "ts": 2, "id": "r5"})
	assert_false(server.registry.requests.has("r5"))
	ws.close()


func test_app_closes_hook_connection_after_event() -> void:
	var ws := _connect(server.token)
	_receive(ws)
	ws.send_text(JSON.stringify({"v": 1, "type": "event", "ts": 1,
		"session": {"id": "quick", "agent": "claude-code", "project_dir": "/p/quick"}, "kind": "prompt", "data": {}}))
	# The hook does not close itself: the app closes after handling (PROTOCOL.md).
	_pump(ws, func() -> bool: return ws.get_ready_state() == WebSocketPeer.STATE_CLOSED)
	assert_eq(ws.get_ready_state(), WebSocketPeer.STATE_CLOSED, "app closed the hook connection")
	assert_true(server.registry.has_session("quick"), "event was handled")


func test_local_events_signal_like_received_ones() -> void:
	var info := {"id": "demo:web", "agent": "demo", "project_dir": "/demo/web"}
	server.local_event(info, "session_start")
	server.local_event(info, "prompt")
	assert_eq(events.map(func(e): return e[0]), ["session_added", "session_changed"])
	assert_eq(server.registry.get_session("demo:web").state, &"thinking")
	assert_eq(server.registry.get_session("demo:web").name, "web")


func test_local_request_answer_is_dropped_safely() -> void:
	server.local_event({"id": "demo:web", "agent": "demo", "project_dir": "/demo/web"}, "session_start")
	assert_true(server.local_request("demo:web", "q1", "Publish?", ["Yes", "No"]))
	assert_eq(server.registry.get_session("demo:web").state, &"waiting")
	assert_true(server.answer_request("q1", "Yes"), "answered from the panel, sent to nobody")
	assert_eq(server.registry.get_session("demo:web").state, &"idle")
	assert_true(server.local_request("demo:web", "q2", "Again?", []))
	server.withdraw_request("q2")
	assert_eq(server.registry.requests.size(), 0)


func test_answers_to_local_requests_are_reported() -> void:
	var seen := []
	server.request_answered.connect(func(r: Dictionary, status: String, choice: String, _t: String) -> void:
		seen.append([r.id, status, choice]))
	server.local_event({"id": "wobbo:welcome", "agent": "wobbo", "project_dir": "/Wobbo"}, "session_start")
	server.local_request("wobbo:welcome", "w1", "Connect?", ["Connect", "Not now"])
	server.answer_request("w1", "Connect")
	server.local_request("wobbo:welcome", "w2", "Move?", ["Move", "Not now"])
	server.dismiss_request("w2")
	assert_eq(seen, [["w1", "answered", "Connect"], ["w2", "dismissed", ""]])


func test_request_keeps_timeout_from_the_frame() -> void:
	var ws := _connect(server.token, {"role": "mcp", "agent": "claude-code", "pid": 9, "ppid": 4100, "project_dir": "/p"})
	_receive(ws)
	_send(ws, {"type": "request", "ts": 1, "id": "r7", "session": null, "kind": "permission",
		"text": "Bash: ls", "choices": ["allow", "deny"], "timeout_s": 20})
	assert_eq(server.registry.requests["r7"].timeout_s, 20)
	assert_true(server.registry.requests["r7"].added_msec > 0, "arrival time kept")
	ws.close()


func test_session_events_also_while_waiting() -> void:
	var info := {"id": "demo:web", "agent": "demo", "project_dir": "/demo/web"}
	server.local_event(info, "prompt")
	server.local_request("demo:web", "q1", "Publish?", ["Yes", "No"])
	server.local_event(info, "turn_end")
	server.local_event(info, "turn_error", {"error": "API overloaded"})
	assert_eq(session_events.map(func(e): return e[1]), ["prompt", "turn_end", "turn_error"])
	assert_eq(session_events[2][2], {"error": "API overloaded"})
	assert_eq(server.registry.get_session("demo:web").state, &"waiting", "the question keeps it waiting")


func test_no_session_event_for_late_or_informational_events() -> void:
	var session := {"id": "s1", "agent": "claude-code", "project_dir": "/p/api"}
	var ws := _connect(server.token)
	_receive(ws)
	_send(ws, {"type": "event", "ts": 50, "session": session, "kind": "turn_end", "data": {}})
	for e in [[40, "tool_start"], [60, "notification"]]:
		ws = _connect(server.token)
		_receive(ws)
		_send(ws, {"type": "event", "ts": e[0], "session": session, "kind": e[1], "data": {}})
	assert_eq(session_events.map(func(x): return x[1]), ["turn_end"], "out-of-order and notifications are skipped")
	ws.close()
