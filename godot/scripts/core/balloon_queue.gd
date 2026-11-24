extends RefCounted
## What one buddy's balloon shows now (balloons-and-speech design D3). Pure: time is
## passed in, in msec.
##
## Pending requests come first, oldest first. Then a question the agent asked in
## its own window (design D11), until the caller closes it. Otherwise the latest
## message is shown until it expires; while the pointer holds it, its countdown pauses.

var _requests: Array[String] = []
var _message := {} # {text, kind, until_msec}
var _asked := {} # {text, choices, tool, until} (design D11)
var _held_since := -1


func add_request(id: String) -> void:
	if not id in _requests:
		_requests.append(id)


## Returns true when the request was in the queue.
func remove_request(id: String) -> bool:
	var i := _requests.find(id)
	if i < 0:
		return false
	_requests.remove_at(i)
	return true


func has_requests() -> bool:
	return not _requests.is_empty()


func requests() -> Array[String]:
	return _requests.duplicate()


## Replaces the message; it stays `duration_s` seconds from `now_msec`.
func set_message(text: String, kind: StringName, duration_s: float, now_msec: int) -> void:
	_message = {"text": text, "kind": kind, "until_msec": now_msec + int(duration_s * 1000.0)}
	if _held_since >= 0:
		_held_since = now_msec # the hold pauses the new countdown from now on


## A question asked in the agent's own window; replaces an earlier one.
## `until`: "answer" (closes when `tool` ends) or "prompt".
func set_asked(text: String, choices: Array, tool: String, until: String) -> void:
	_asked = {"text": text, "choices": choices.duplicate(), "tool": tool, "until": until}


## Closes the asked question when `tool` ended and it waited for that answer.
func tool_ended(tool: String) -> void:
	if not _asked.is_empty() and _asked.until == "answer" and _asked.tool == tool:
		_asked = {}


func close_asked() -> void:
	_asked = {}


func has_asked() -> bool:
	return not _asked.is_empty()


func close_message() -> void:
	_message = {}
	_held_since = -1


## The pointer rests on the balloon: the message's countdown pauses.
func hold(now_msec: int) -> void:
	if _held_since < 0:
		_held_since = now_msec


## The pointer left: the countdown goes on where it paused.
func release(now_msec: int) -> void:
	if _held_since < 0:
		return
	if not _message.is_empty():
		_message.until_msec += now_msec - _held_since
	_held_since = -1


func is_held() -> bool:
	return _held_since >= 0


## {type: &"request", id, index, count}, {type: &"asked", text, choices},
## {type: &"message", text, kind}, or {}.
func current(now_msec: int) -> Dictionary:
	if not _requests.is_empty():
		return {"type": &"request", "id": _requests[0], "index": 1, "count": _requests.size()}
	if not _asked.is_empty():
		return {"type": &"asked", "text": _asked.text, "choices": _asked.choices}
	if _message.is_empty():
		return {}
	if _held_since < 0 and now_msec >= int(_message.until_msec):
		_message = {}
		return {}
	return {"type": &"message", "text": _message.text, "kind": _message.kind}


func clear() -> void:
	_requests.clear()
	_asked = {}
	close_message()
