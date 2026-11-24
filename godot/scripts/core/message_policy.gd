extends RefCounted
## What the buddies tell the user, and how (balloons-and-speech design D2, D8). Pure:
## the `Messages` node asks it what to show, speak or hand back.
##
## A plan for one message or notice is {show, speak, text, spoken, duration_s, kind},
## or {} when nothing happens. A plan for a request is {show, speak, spoken}.

const BALLOONS := "balloons"
const SPEECH := "speech"
const BOTH := "both"
const OFF := "off"
const DEFAULT := BALLOONS
## value -> label, in menu order.
const MODES := {
	BALLOONS: "Balloons",
	SPEECH: "Speech",
	BOTH: "Balloons and Speech",
	OFF: "Off",
}

const KIND_MESSAGE := &"message"
const KIND_DONE := &"done"
const KIND_ERROR := &"error"

## A turn is announced only when it took at least this long (design D2).
const DONE_AFTER_MS := 20 * 1000
const DONE_SEC := 4.0
const ERROR_SEC := 8.0
const MIN_READ_SEC := 4.0
const MAX_READ_SEC := 12.0
const ERROR_MAX_CHARS := 120


## The output mode for a stored value: an unknown value counts as Balloons.
static func mode_of(value: Variant) -> String:
	var v := String(value) if value is String or value is StringName else ""
	return v if MODES.has(v) else DEFAULT


## {balloon, speech}: what the output mode uses for messages and notices.
static func output_flags(mode: String) -> Dictionary:
	match mode_of(mode):
		SPEECH:
			return {"balloon": false, "speech": true}
		BOTH:
			return {"balloon": true, "speech": true}
		OFF:
			return {"balloon": false, "speech": false}
	return {"balloon": true, "speech": false}


## False when requests must be handed back at once: output Off, or the buddies
## hidden (spec "Output off", "Hidden buddies").
static func accepts_requests(mode: String, buddies_visible: bool) -> bool:
	return buddies_visible and mode_of(mode) != OFF


## How long a message stays: grows with its length, 4 to 12 seconds.
static func reading_time_s(text: String) -> float:
	return clampf(3.0 + 0.06 * text.length(), MIN_READ_SEC, MAX_READ_SEC)


static func for_message(text: String, session_name: String, mode: String) -> Dictionary:
	return _plan(mode, KIND_MESSAGE, text, "%s: %s" % [session_name, text], reading_time_s(text))


## `turn_ms` is the time since the prompt, or a negative number when unknown.
## `background` is how many background commands still run: then it is not done
## yet (background-work D3).
static func for_turn_end(session_name: String, turn_ms: int, notify_done: bool, mode: String,
		background := 0) -> Dictionary:
	if not notify_done or turn_ms < DONE_AFTER_MS or background > 0:
		return {}
	return _plan(mode, KIND_DONE, "Done", "%s is done" % session_name, DONE_SEC)


static func for_turn_error(session_name: String, error: String, notify_errors: bool, mode: String) -> Dictionary:
	if not notify_errors:
		return {}
	var line := first_line(error)
	var text := "Something went wrong: %s" % line if not line.is_empty() else "Something went wrong"
	return _plan(mode, KIND_ERROR, text, "%s: something went wrong" % session_name, ERROR_SEC)


## The first non-empty line of an error, cut to 120 characters with "…".
static func first_line(error: String) -> String:
	for line in error.split("\n"):
		var t := line.strip_edges()
		if not t.is_empty():
			return t if t.length() <= ERROR_MAX_CHARS else t.left(ERROR_MAX_CHARS - 1) + "…"
	return ""


## A question the agent asked in its own window (design D11): read only, so it
## follows the output like a message. {show, speak, spoken}, or {} when off.
static func for_asked(question: String, session_name: String, mode: String) -> Dictionary:
	var flags := output_flags(mode)
	if not flags.balloon and not flags.speech:
		return {}
	return {"show": flags.balloon, "speak": flags.speech, "spoken": "%s asks: %s" % [session_name, question]}


## A request is always shown while requests are accepted, also with output
## Speech, because it can only be answered in its balloon (spec "Spoken output").
## `kind` and `text` are the request's (a question or a permission prompt).
static func for_request(kind: String, text: String, session_name: String, mode: String) -> Dictionary:
	var flags := output_flags(mode)
	var spoken := "%s asks: %s" % [session_name, text]
	if kind == "permission":
		spoken = "%s asks permission to use %s" % [session_name, tool_of(text)]
	return {"show": mode_of(mode) != OFF, "speak": flags.speech, "spoken": spoken}


## "Bash: rm -rf build" -> "Bash": the part of a permission text worth saying aloud.
static func tool_of(permission_text: String) -> String:
	var i := permission_text.find(": ")
	return permission_text.left(i) if i > 0 else permission_text


## The "Messages" menu's radio items: [{label, value, checked, disabled}], exactly
## one checked. Without a voice the speech items are disabled (design D8).
static func menu_items(mode: String, speech_available: bool) -> Array[Dictionary]:
	var chosen := mode_of(mode)
	var out: Array[Dictionary] = []
	for value: String in MODES:
		out.append({"label": MODES[value], "value": value, "checked": value == chosen,
			"disabled": not speech_available and (value == SPEECH or value == BOTH)})
	return out


static func _plan(mode: String, kind: StringName, text: String, spoken: String, duration_s: float) -> Dictionary:
	var flags := output_flags(mode)
	if not flags.balloon and not flags.speech:
		return {}
	return {"show": flags.balloon, "speak": flags.speech, "text": text, "spoken": spoken,
		"duration_s": duration_s, "kind": kind}
