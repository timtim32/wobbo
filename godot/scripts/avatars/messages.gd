extends Node
## What each buddy says (balloons-and-speech design D1). Listens to the Bridge's
## messages, events and requests, asks MessagePolicy what to show, speak or hand
## back, keeps a BalloonQueue per session, and gives each avatar on screen its
## balloon content every frame. Lives outside Content, so it keeps handing
## requests back while the buddies are hidden.

const Policy := preload("res://scripts/core/message_policy.gd")
const BalloonQueue := preload("res://scripts/core/balloon_queue.gd")
const SessionRegistry := preload("res://scripts/core/session_registry.gd")
const Speech := preload("res://scripts/avatars/speech.gd")

@export var avatars_path: NodePath = ^"../Content/Avatars"

var speech := Speech.new()
var _queues := {} # session id -> BalloonQueue
@onready var _avatars: Node = get_node_or_null(avatars_path)


func _ready() -> void:
	speech.name = "Speech"
	add_child(speech)
	Bridge.message_received.connect(_on_message)
	Bridge.session_event.connect(_on_session_event)
	Bridge.request_added.connect(_on_request_added)
	Bridge.request_removed.connect(_on_request_removed)
	Bridge.session_removed.connect(func(id: String) -> void: _queues.erase(id))
	Settings.changed.connect(_on_setting_changed)
	Overlay.content_visibility_changed.connect(_on_visibility_changed)


func speech_available() -> bool:
	return speech.available()


## Whether any buddy shows a balloon now (keeps the frame rate up, design D10).
func any_balloon_open() -> bool:
	if _avatars == null:
		return false
	for a in _avatars.avatars():
		if a.balloon_open():
			return true
	return false


func _process(_delta: float) -> void:
	if _avatars == null:
		return
	var now := Time.get_ticks_msec()
	for a in _avatars.avatars():
		a.messages = self
		a.balloon_content = content_for(a.session_id, now)


## What the balloon of `session_id` shows now: {} for nothing, else the queue's
## entry plus `request` (the pending request) for a request.
func content_for(session_id: String, now_msec: int) -> Dictionary:
	var q: BalloonQueue = _queues.get(session_id)
	if q == null:
		return {}
	var current := q.current(now_msec)
	if current.get("type") == &"request":
		var request: Dictionary = Bridge.registry.requests.get(current.id, {})
		if request.is_empty():
			q.remove_request(current.id) # withdrawn without a signal we saw
			return content_for(session_id, now_msec)
		current["request"] = request
	return current


# --- Actions from the balloons ---------------------------------------------------

func answer(request_id: String, choice: String, text := "") -> void:
	Bridge.answer_request(request_id, choice, text)


## The close button of a request: a question is dismissed, a permission is left
## to the agent's own prompt (both through "dismissed", design D9).
func dismiss(request_id: String) -> void:
	Bridge.dismiss_request(request_id)


func close_message(session_id: String) -> void:
	var q: BalloonQueue = _queues.get(session_id)
	if q:
		q.close_message()


func close_asked(session_id: String) -> void:
	var q: BalloonQueue = _queues.get(session_id)
	if q:
		q.close_asked()


## A click on an asked question's balloon: answer it in the session (design D11).
func go_to_session(session_id: String) -> void:
	if _avatars:
		_avatars.go_to_session(session_id)


## The pointer rests on (or left) the balloon of `session_id`.
func set_hovered(session_id: String, hovered: bool) -> void:
	var q: BalloonQueue = _queues.get(session_id)
	if q == null or q.is_held() == hovered:
		return
	if hovered:
		q.hold(Time.get_ticks_msec())
	else:
		q.release(Time.get_ticks_msec())


# --- Bridge -----------------------------------------------------------------------

func _on_message(session_id: String, text: String) -> void:
	_notify(session_id, Policy.for_message(text, _name_of(session_id), Settings.messages))


func _on_session_event(session_id: String, kind: String, data: Dictionary) -> void:
	var s: SessionRegistry.Session = Bridge.registry.get_session(session_id)
	if s == null:
		return
	var question := String(data.get("question", ""))
	if not question.is_empty():
		_on_asked(s, question, data)
	match kind:
		"prompt":
			if _queues.has(session_id):
				_queues[session_id].close_asked()
		"tool_end", "tool_error":
			if _queues.has(session_id):
				_queues[session_id].tool_ended(String(data.get("tool", "")))
		"turn_end":
			var turn_ms: int = Time.get_ticks_msec() - s.turn_started_msec if s.turn_started_msec > 0 else -1
			_notify(session_id, Policy.for_turn_end(s.name, turn_ms, Settings.notify_done, Settings.messages))
		"turn_error":
			_notify(session_id, Policy.for_turn_error(s.name, String(data.get("error", "")),
				Settings.notify_errors, Settings.messages))
		"session_end":
			_queues.erase(session_id)


## A question asked in the agent's own window (design D11). One that waits for an
## answer is kept even before its buddy is on screen: a waiting session comes in.
func _on_asked(s: SessionRegistry.Session, question: String, data: Dictionary) -> void:
	var plan := Policy.for_asked(question, s.name, Settings.messages)
	if plan.is_empty():
		return
	if plan.speak:
		speech.speak(plan.spoken)
	var until := String(data.get("question_until", "prompt"))
	if plan.show and (until == "answer" or _on_screen(s.id)):
		var choices: Array = data.get("choices", []) if typeof(data.get("choices")) == TYPE_ARRAY else []
		_queue(s.id).set_asked(question, choices.map(func(c: Variant) -> String: return String(c)),
			String(data.get("tool", "")), until)


func _on_request_added(request: Dictionary) -> void:
	if not _accepts_requests():
		_hand_back.call_deferred(String(request.id)) # not while the Bridge is still adding it
		return
	var session_id := String(request.session_id)
	_queue(session_id).add_request(String(request.id))
	var plan := Policy.for_request(request, _name_of(session_id), Settings.messages)
	if plan.speak:
		speech.speak(plan.spoken)


func _on_request_removed(request: Dictionary) -> void:
	var q: BalloonQueue = _queues.get(String(request.session_id))
	if q:
		q.remove_request(String(request.id))


## Shows and speaks a plan from MessagePolicy. A balloon only for a buddy on
## screen: it is not kept for later (spec "Sessions without a buddy on screen").
func _notify(session_id: String, plan: Dictionary) -> void:
	if plan.is_empty():
		return
	if plan.speak:
		speech.speak(plan.spoken)
	if plan.show and _on_screen(session_id):
		_queue(session_id).set_message(plan.text, plan.kind, plan.duration_s, Time.get_ticks_msec())


# --- Settings and visibility ----------------------------------------------------

func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key != &"messages":
		return
	var flags := Policy.output_flags(Settings.messages)
	if not flags.speech:
		speech.stop()
	if not flags.balloon:
		for q: BalloonQueue in _queues.values():
			q.close_message()
			q.close_asked()
	if not _accepts_requests():
		_hand_back_all()


func _on_visibility_changed(shown: bool) -> void:
	if not shown:
		_hand_back_all()


func _accepts_requests() -> bool:
	return Policy.accepts_requests(Settings.messages, Overlay.content_visible)


## Output Off or buddies hidden: every request goes back, nothing stays open or
## keeps talking (design D9).
func _hand_back_all() -> void:
	for id: String in Bridge.registry.requests.keys():
		_hand_back(id)
	for q: BalloonQueue in _queues.values():
		q.clear()
	speech.stop()


func _hand_back(request_id: String) -> void:
	if Bridge.dismiss_request(request_id):
		print("Messages: request %s handed back (output %s, buddies %s)" % [request_id, Settings.messages,
			"shown" if Overlay.content_visible else "hidden"])


# --- Helpers ----------------------------------------------------------------------

func _queue(session_id: String) -> BalloonQueue:
	if not _queues.has(session_id):
		_queues[session_id] = BalloonQueue.new()
	return _queues[session_id]


func _name_of(session_id: String) -> String:
	var s: SessionRegistry.Session = Bridge.registry.get_session(session_id)
	return s.name if s else session_id


func _on_screen(session_id: String) -> bool:
	if _avatars == null:
		return false
	for a in _avatars.avatars():
		if a.session_id == session_id and not a.is_going():
			return true
	return false
