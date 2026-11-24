extends Node
## "Play Demo" from the menu (session-avatars design D11): a scripted show
## with pretend sessions that exist only inside the app. They go through the
## Bridge like real sessions, so the avatars behave exactly as they would.

signal running_changed(running: bool)
## A step that is not about a session (the trailer's "dock" show/hide).
signal cue(action: String, argument: String)

const Protocol := preload("res://scripts/bridge/protocol.gd")
const AGENT := "demo"
const ID_PREFIX := "demo:"

## [at_sec, session name, action, argument]
## actions: start, prompt, tool, say, done, error, ask, answered, end; and
## without a session: dock (show/hide, the trailer's pretend Dock)
const STEPS := [
	[0.0, "website", "start", ""],
	[1.0, "api", "start", ""],
	[2.0, "docs", "start", ""],
	[9.0, "website", "prompt", ""],
	[10.0, "api", "tool", "Bash"],
	[11.0, "docs", "ask", "Publish the new docs?"],
	[18.0, "website", "done", ""],
	[19.0, "api", "error", "tests failed"],
	[24.0, "mobile-app", "start", ""],
	[25.0, "mobile-app", "prompt", ""],
	[29.0, "data-pipeline", "start", ""],
	[30.0, "data-pipeline", "tool", "Edit"],
	[33.0, "shop", "start", ""],
	[34.0, "shop", "prompt", ""],
	[40.0, "docs", "answered", ""],
	[40.5, "docs", "tool", "Write"],
	[44.0, "mobile-app", "tool", "Read"],
	[48.0, "website", "end", ""],
	[53.0, "docs", "done", ""],
	[56.0, "shop", "done", ""],
	[60.0, "data-pipeline", "done", ""],
	[64.0, "mobile-app", "error", "build failed"],
	[70.0, "api", "end", ""],
	[74.0, "docs", "end", ""],
	[78.0, "shop", "end", ""],
	[80.0, "mobile-app", "end", ""],
	[82.0, "data-pipeline", "end", ""],
]
## The trailer (tools/record-trailer.sh, TrailerMode): every state in about half a
## minute. "Done" shows only after a turn of 20 s or more, so api works that long.
const TRAILER_STEPS := [
	[0.0, "website", "start", ""],
	[0.6, "api", "start", ""],
	[1.2, "docs", "start", ""],
	[4.0, "api", "prompt", ""],
	[4.5, "api", "tool", "Bash"],
	[5.0, "website", "prompt", ""],
	[6.5, "docs", "ask", "Publish the new docs?"],
	[8.5, "website", "tool", "Edit"],
	[10.5, "website", "say", "Found it: the cart total skipped the discount."],
	[12.0, "mobile-app", "start", ""],
	[14.0, "docs", "answered", ""],
	[14.3, "docs", "prompt", ""],
	[14.5, "docs", "tool", "Write"],
	[16.0, "mobile-app", "prompt", ""],
	[17.0, "", "dock", "show"],
	[18.5, "mobile-app", "tool", "Read"],
	[21.0, "", "dock", "hide"],
	[21.5, "mobile-app", "error", "build failed"],
	[25.0, "api", "done", ""],
	[27.0, "website", "done", ""],
	[28.5, "docs", "done", ""],
	[32.0, "website", "end", ""],
	[32.4, "api", "end", ""],
	[32.8, "docs", "end", ""],
	[33.2, "mobile-app", "end", ""],
]
const EVENT_KINDS := {"start": "session_start", "prompt": "prompt", "tool": "tool_start",
	"done": "turn_end", "error": "turn_error", "end": "session_end"}

var running := false
var _steps: Array = STEPS
var _time := 0.0
var _next := 0


static func info(session_name: String) -> Dictionary:
	return {"id": ID_PREFIX + session_name, "agent": AGENT, "project_dir": "/demo/" + session_name}


static func request_id(session_name: String) -> String:
	return "demo-question:" + session_name


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func toggle() -> void:
	if running:
		stop()
	else:
		start()


## Plays `steps` (STEPS: the menu's demo, TRAILER_STEPS: the trailer).
func start(steps: Array = STEPS) -> void:
	if running:
		return
	running = true
	_steps = steps
	_time = 0.0
	_next = 0
	set_process(true)
	print("Demo: started")
	running_changed.emit(true)


## Ends every pretend session that is still there (the show's end or "Stop Demo").
func stop() -> void:
	if not running:
		return
	running = false
	set_process(false)
	for s in Bridge.registry.sessions():
		if String(s.id).begins_with(ID_PREFIX):
			Bridge.withdraw_request(request_id(String(s.id).trim_prefix(ID_PREFIX)))
			if s.state != Protocol.STATE_ENDED:
				Bridge.local_event(info(String(s.id).trim_prefix(ID_PREFIX)), "session_end", {"reason": "demo"})
	print("Demo: stopped")
	running_changed.emit(false)


func _process(delta: float) -> void:
	_time += delta
	while _next < _steps.size() and _steps[_next][0] <= _time:
		_run(_steps[_next])
		_next += 1
	if _next >= _steps.size():
		stop()


func _run(step: Array) -> void:
	var session_name: String = step[1]
	var action: String = step[2]
	var arg: String = step[3]
	match action:
		"ask":
			Bridge.local_request(info(session_name).id, request_id(session_name), arg, ["Yes", "No"])
		"answered":
			Bridge.withdraw_request(request_id(session_name))
		"say":
			Bridge.local_say(info(session_name).id, arg)
		"dock":
			cue.emit(action, arg)
		"tool":
			Bridge.local_event(info(session_name), EVENT_KINDS[action], {"tool": arg})
		"error":
			Bridge.local_event(info(session_name), EVENT_KINDS[action], {"error": arg})
		_:
			Bridge.local_event(info(session_name), EVENT_KINDS[action], {})
