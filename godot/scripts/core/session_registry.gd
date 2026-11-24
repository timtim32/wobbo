extends RefCounted
## Sessions, their states and pending requests (claude-bridge D3, D6). Pure logic: no
## sockets, no nodes, time passed in explicitly, so it is unit tested headless.
##
## Mutating methods return what changed, so the caller (the Bridge autoload)
## can emit signals.

const Protocol := preload("res://scripts/bridge/protocol.gd")
const FocusLink := preload("res://scripts/core/focus_link.gd")

const ENDED_LINGER_MS := 5000
const IDLE_TIMEOUT_MS := 30 * 60 * 1000
const CODE_TAB_PREFIX := "local-agent-mode-"


class Session:
	extends RefCounted
	var id: String
	var agent: String
	var project_dir: String
	var name: String
	var state: StringName = Protocol.STATE_IDLE
	var tool := ""
	var last_message := ""
	var last_problem := ""
	var ppid := 0
	var focus_url := "" # opens the session in its host app (go-to-session D4)
	var last_ts := 0 # client time of the last applied state change
	var updated_msec := 0 # local time of the last activity
	var turn_started_msec := 0 # local time of the last prompt (balloons-and-speech D4)
	var ended_msec := 0
	var connections := 0 # open MCP connections attributed to this session
	var state_before_wait: StringName = &""
	var pending: Array[String] = []


## A pending question or permission prompt, waiting for the user's answer.
class Request:
	extends RefCounted
	var id: String
	var session_id: String
	var kind: String # Protocol.REQUEST_QUESTION or Protocol.REQUEST_PERMISSION
	var text: String
	var choices: Array[String] = []
	var allow_text: bool
	var owner: int # the connection that asked; -1 for a request from inside the app
	var timeout_s: int # how long the asker waits; 0 when unknown
	var added_msec := 0 # set by add_request, for the time-left bar (balloons-and-speech D4)

	func _init(p_id: String, p_session_id: String, p_kind := Protocol.REQUEST_QUESTION, p_text := "",
			p_choices: Array = [], p_allow_text := false, p_owner := -1, p_timeout_s := 0) -> void:
		id = p_id
		session_id = p_session_id
		kind = p_kind
		text = p_text
		for choice: Variant in p_choices:
			choices.append(String(choice))
		allow_text = p_allow_text
		owner = p_owner
		timeout_s = p_timeout_s

	## A request from a received `request` frame (bridge/PROTOCOL.md).
	static func from_message(msg: Dictionary, p_session_id: String, p_owner: int) -> Request:
		var raw_choices: Variant = msg.get("choices", [])
		return Request.new(String(msg.get("id", "")), p_session_id,
			String(msg.get("kind", Protocol.REQUEST_QUESTION)), String(msg.get("text", "")),
			raw_choices if raw_choices is Array else [], bool(msg.get("allow_text", false)), p_owner,
			int(msg.get("timeout_s", 0)))


## Pending requests by id.
var requests: Dictionary[String, Request] = {}
var _sessions: Dictionary = {} # id -> Session


static func display_name(project_dir: String, fallback: String) -> String:
	var trimmed := project_dir.trim_suffix("/")
	var base := trimmed.get_file()
	return base if not base.is_empty() else fallback


## How many background commands a `turn_end` reports as still running (0 when absent).
static func running_in_background(data: Dictionary) -> int:
	var n: Variant = data.get("background", 0)
	return int(n) if n is int or n is float else 0


func get_session(id: String) -> Session:
	return _sessions.get(id)


func sessions() -> Array:
	var list := _sessions.values()
	list.sort_custom(func(a: Session, b: Session) -> bool: return a.updated_msec > b.updated_msec)
	return list


func has_session(id: String) -> bool:
	return _sessions.has(id)


## The most recently active session that is not ended, or null.
func most_recent() -> Session:
	for s: Session in sessions():
		if s.state != Protocol.STATE_ENDED:
			return s
	return null


## Returns the session for `info` ({id, agent, project_dir}), creating it if needed.
func ensure_session(info: Dictionary, now_msec: int, ppid := 0) -> Session:
	var id := String(info.get("id", ""))
	var s: Session = _sessions.get(id)
	if s == null:
		s = Session.new()
		s.id = id
		s.agent = String(info.get("agent", "unknown"))
		s.project_dir = String(info.get("project_dir", ""))
		s.name = display_name(s.project_dir, s.agent)
		s.updated_msec = now_msec
		_sessions[id] = s
	if ppid != 0:
		s.ppid = ppid
	var url := String(info.get("focus_url", ""))
	if not url.is_empty() and FocusLink.allowed(url):
		s.focus_url = url
	if s.project_dir.is_empty() and not String(info.get("project_dir", "")).is_empty():
		s.project_dir = info.project_dir
		s.name = display_name(s.project_dir, s.agent)
	return s


## Applies an event. Returns true when the session's visible data changed.
func apply_event(info: Dictionary, kind: String, data: Dictionary, ts: int, now_msec: int, ppid := 0) -> bool:
	var s := ensure_session(info, now_msec, ppid)
	s.updated_msec = now_msec
	if kind == "notification":
		return false # informational only; state comes from the other events
	if ts < s.last_ts and kind != "session_end":
		return false # out of order: an older hook arrived late
	s.last_ts = maxi(s.last_ts, ts)
	var new_state: StringName = s.state
	match kind:
		"session_start":
			new_state = Protocol.STATE_IDLE
			s.ended_msec = 0
		"prompt":
			new_state = Protocol.STATE_THINKING
			s.last_problem = ""
			s.turn_started_msec = now_msec
		"tool_start":
			new_state = Protocol.STATE_WORKING
			s.tool = String(data.get("tool", ""))
		"tool_end":
			new_state = Protocol.STATE_THINKING
			s.tool = ""
		"tool_error":
			new_state = Protocol.STATE_THINKING
			s.tool = ""
			s.last_problem = String(data.get("error", ""))
		"input_wait":
			# The agent waits for the user in its own UI (work-and-wait D1).
			new_state = Protocol.STATE_WAITING
			s.tool = String(data.get("tool", ""))
		"turn_end":
			# Still at work while it waits for a command it runs in the background
			# (background-work D3); woken when it ends, it reports again.
			new_state = Protocol.STATE_WORKING if running_in_background(data) > 0 else Protocol.STATE_DONE
			s.tool = ""
		"turn_error":
			new_state = Protocol.STATE_ERROR
			s.last_problem = String(data.get("error", ""))
		"session_end":
			new_state = Protocol.STATE_ENDED
			s.ended_msec = now_msec
		_:
			return false
	if not s.pending.is_empty() and new_state != Protocol.STATE_ENDED:
		# A request is open: stay "waiting", but remember where to return to.
		s.state_before_wait = new_state
		return true
	s.state = new_state
	return true


func set_message(session_id: String, text: String, now_msec: int) -> bool:
	var s: Session = _sessions.get(session_id)
	if s == null:
		return false
	s.last_message = text
	s.updated_msec = now_msec
	return true


## Adds a pending request; the session goes to "waiting".
func add_request(request: Request, now_msec: int) -> bool:
	var s: Session = _sessions.get(request.session_id)
	if s == null or request.id.is_empty() or requests.has(request.id):
		return false
	request.added_msec = now_msec
	requests[request.id] = request
	if s.pending.is_empty():
		s.state_before_wait = s.state
	s.pending.append(request.id)
	s.state = Protocol.STATE_WAITING
	s.updated_msec = now_msec
	return true


## Removes a pending request (answered, dismissed or cancelled). Returns it, or null.
func remove_request(id: String) -> Request:
	var request: Request = requests.get(id)
	if request == null:
		return null
	requests.erase(id)
	var s: Session = _sessions.get(request.session_id)
	if s:
		s.pending.erase(id)
		if s.pending.is_empty() and s.state == Protocol.STATE_WAITING:
			s.state = s.state_before_wait if s.state_before_wait != &"" else Protocol.STATE_IDLE
			s.state_before_wait = &""
	return request


## Removes every request owned by `owner` (a connection that closed).
func remove_requests_of(owner: int) -> Array[Request]:
	var removed: Array[Request] = []
	for id: String in requests.keys():
		if requests[id].owner == owner:
			removed.append(remove_request(id))
	return removed


func requests_of(session_id: String) -> Array[Request]:
	var list: Array[Request] = []
	for request: Request in requests.values():
		if request.session_id == session_id:
			list.append(request)
	return list


## Finds the session an MCP connection speaks for (claude-bridge D6): a live session of
## the same agent with the same parent process, else the most recent live session
## of that agent in the same project, else the connection's own session.
func resolve_mcp_session(client: Dictionary, now_msec: int) -> Session:
	var agent := String(client.get("agent", "unknown"))
	var ppid := int(client.get("ppid", 0))
	var project_dir := String(client.get("project_dir", ""))
	# Claude Desktop's Code tab starts one instance of the Desktop MCP server per
	# project, under the Claude app (so its ppid never matches the hooks), with
	# client name "local-agent-mode-<name>". Link it by that name; the name is
	# Claude Desktop's own name for the project and may differ from the folder
	# (claude-desktop-setup D6), so otherwise take the Code session in the Claude
	# app that was active last: its hook for this very tool call just fired.
	var client_name := String(client.get("client_name", ""))
	if client_name.begins_with(CODE_TAB_PREFIX):
		var wanted := client_name.trim_prefix(CODE_TAB_PREFIX)
		var in_app: Session = null
		for s: Session in sessions():
			if s.state == Protocol.STATE_ENDED or s.id.begins_with("mcp:"):
				continue
			if s.name == wanted:
				return s
			if in_app == null and s.focus_url.begins_with("claude:"):
				in_app = s
		if in_app:
			return in_app
	var by_project: Session = null
	for s: Session in sessions():
		if s.state == Protocol.STATE_ENDED or s.id.begins_with("mcp:") or s.agent != agent:
			continue
		if ppid != 0 and s.ppid == ppid:
			return s
		if by_project == null and not project_dir.is_empty() and s.project_dir == project_dir:
			by_project = s
	if by_project:
		return by_project
	var own := ensure_session({"id": "mcp:%d" % int(client.get("pid", 0)), "agent": agent,
		"project_dir": project_dir}, now_msec, ppid)
	if project_dir.is_empty() and not client_name.is_empty():
		own.name = pretty_client_name(client_name)
	return own


static func pretty_client_name(client_name: String) -> String:
	if client_name.begins_with(CODE_TAB_PREFIX):
		return "Claude Desktop"
	match client_name:
		"claude-ai":
			return "Claude Desktop"
		"claude-code":
			return "Claude Code"
	return client_name


## Removes sessions that ended a while ago or went silent. Returns their ids;
## the open requests of those sessions are appended to `dropped_requests`.
func tick(now_msec: int, dropped_requests: Array[Request] = []) -> Array[String]:
	var removed: Array[String] = []
	for id: String in _sessions.keys():
		var s: Session = _sessions[id]
		var gone := s.state == Protocol.STATE_ENDED and now_msec - s.ended_msec >= ENDED_LINGER_MS
		var silent := s.connections == 0 and s.pending.is_empty() \
			and now_msec - s.updated_msec >= IDLE_TIMEOUT_MS
		if gone or silent:
			for request_id in s.pending.duplicate():
				dropped_requests.append(remove_request(request_id))
			_sessions.erase(id)
			removed.append(id)
	return removed
