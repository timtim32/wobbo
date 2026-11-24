extends RefCounted
## What an avatar does right now (session-avatars design D3). Pure: the session
## state, activity times and the clock are passed in; out comes {clip, motion}.
##
## motion: &"stand", &"stroll", &"walk_in", &"travel" or &"walk_off".
## The avatar node reports its phase changes (arrive, travel, leave) and
## finished one-shot clips back.

const Protocol := preload("res://scripts/bridge/protocol.gd")
const SLEEP_AFTER_MS := 120 * 1000
## Asleep this long: the avatar goes home (send-home D3).
const HOME_AFTER_ASLEEP_MS := 15 * 60 * 1000
const PAUSE_MIN_MS := 2000
const PAUSE_MAX_MS := 6000
const STROLL_MIN_MS := 8000
const STROLL_MAX_MS := 15000

const STATE_CLIPS := {Protocol.STATE_THINKING: &"thinking", Protocol.STATE_WORKING: &"working", Protocol.STATE_WAITING: &"waiting"}
const REACTIONS := {Protocol.STATE_DONE: &"happy", Protocol.STATE_ERROR: &"error"}
const RESTING := [Protocol.STATE_IDLE, Protocol.STATE_DONE, Protocol.STATE_ERROR]
## Ways of working (work-and-wait D5, D7). All but plain `working` have a prop
## with `_in` / `_out` transitions around their loop.
const WORK_CLIPS: Array[StringName] = [&"working", &"work_hammer", &"work_laptop", &"work_wrench", &"work_papers"]
const WORK_SWITCH_MIN_MS := 8000
const WORK_SWITCH_MAX_MS := 15000

var phase := &"entering" # entering, home, travelling, leaving
var asleep := false
## When `asleep` became true, or -1 while awake.
var asleep_since_msec := -1

var _state: StringName
var _reaction: StringName = &"" # one-shot to play when at home
var _leave_after_reaction := false
var _pause_until := -1
var _next_pause := -1
var _rng := RandomNumberGenerator.new()
var _work_clip: StringName = &"" # the current way of working, or none
var _work_phase: StringName = &"" # in, loop or out
var _work_until := 0
var _work_next := false # pick the next way of working on the next update
var _last_work: StringName = &""


func _init(initial_state: StringName = &"idle", seed_value := 0) -> void:
	_state = initial_state
	_rng.seed = seed_value


func arrive() -> void:
	if phase != &"leaving":
		phase = &"home"


func travel() -> void:
	if phase != &"leaving":
		phase = &"travelling"


## The cast decided this avatar goes; with a wave first when its session ended.
func leave(wave: bool) -> void:
	if phase == &"leaving" or _leave_after_reaction:
		return
	if wave:
		_reaction = &"wave"
		_leave_after_reaction = true
	else:
		_reaction = &""
		phase = &"leaving"


## True when it has slept long enough to go home by itself (send-home D3).
func wants_home(now_msec: int) -> bool:
	return asleep and asleep_since_msec >= 0 and now_msec - asleep_since_msec >= HOME_AFTER_ASLEEP_MS


## True once the avatar is leaving (or waving goodbye first).
func is_going() -> bool:
	return phase == &"leaving" or _leave_after_reaction


## The avatar's one-shot clip finished.
func one_shot_finished(clip: StringName) -> void:
	if _work_clip != &"" and clip == _with_suffix("_in"):
		_work_phase = &"loop"
		return
	if _work_clip != &"" and clip == _with_suffix("_out"):
		_work_next = _state == Protocol.STATE_WORKING
		_work_clip = &""
		_work_phase = &""
		return
	if clip != _reaction:
		return
	_reaction = &""
	if _leave_after_reaction:
		_leave_after_reaction = false
		phase = &"leaving"


func update(state: StringName, last_activity_msec: int, now_msec: int) -> Dictionary:
	if state != _state:
		_state = state
		if not _leave_after_reaction:
			_reaction = REACTIONS.get(state, &"")
	var active_since := last_activity_msec
	asleep = state in RESTING and _reaction == &"" and now_msec - active_since >= SLEEP_AFTER_MS
	if not asleep:
		asleep_since_msec = -1
	elif asleep_since_msec < 0:
		asleep_since_msec = now_msec
	match phase:
		&"entering", &"travelling", &"leaving":
			_drop_work() # walking hides every prop
			match phase:
				&"entering":
					return {"clip": &"walk", "motion": &"walk_in"}
				&"travelling":
					return {"clip": &"walk", "motion": &"travel"}
			return {"clip": &"walk", "motion": &"walk_off"}
	var work := _work(state, now_msec)
	if not work.is_empty():
		return work
	if _reaction != &"":
		return {"clip": _reaction, "motion": &"stand"}
	if asleep:
		return {"clip": &"sleep", "motion": &"stand"}
	if STATE_CLIPS.has(state):
		return {"clip": STATE_CLIPS[state], "motion": &"stand"}
	return _stroll(now_msec)


## The work clip to show, or {} when not working (work-and-wait D5, D7).
func _work(state: StringName, now_msec: int) -> Dictionary:
	if _work_clip != &"" and state != Protocol.STATE_WORKING and _work_phase != &"out":
		# Stop working: put the prop away first, then the new state.
		if _has_prop(_work_clip):
			_work_phase = &"out"
		else:
			_drop_work()
	if _work_phase == &"out":
		return {"clip": _with_suffix("_out"), "motion": &"stand"}
	if state != Protocol.STATE_WORKING:
		_work_next = false
		return {}
	if _work_clip == &"" or _work_next:
		_pick_work(now_msec)
	if _work_phase == &"in":
		return {"clip": _with_suffix("_in"), "motion": &"stand"}
	if now_msec >= _work_until:
		if _has_prop(_work_clip):
			_work_phase = &"out"
			return {"clip": _with_suffix("_out"), "motion": &"stand"}
		_pick_work(now_msec)
		if _work_phase == &"in":
			return {"clip": _with_suffix("_in"), "motion": &"stand"}
	return {"clip": _work_clip, "motion": &"stand"}


func _pick_work(now_msec: int) -> void:
	var choices := WORK_CLIPS.filter(func(c: StringName) -> bool: return c != _last_work)
	_work_clip = choices[_rng.randi_range(0, choices.size() - 1)]
	_last_work = _work_clip
	_work_phase = &"in" if _has_prop(_work_clip) else &"loop"
	_work_until = now_msec + _rng.randi_range(WORK_SWITCH_MIN_MS, WORK_SWITCH_MAX_MS)
	_work_next = false


func _drop_work() -> void:
	_work_clip = &""
	_work_phase = &""
	_work_next = false


func _has_prop(clip: StringName) -> bool:
	return clip != &"working"


func _with_suffix(suffix: String) -> StringName:
	return StringName(String(_work_clip) + suffix)


## The current way of working, for tests and the avatar.
func work_clip() -> StringName:
	return _work_clip


## Strolling with short idle pauses, randomised per avatar.
func _stroll(now_msec: int) -> Dictionary:
	if _next_pause < 0:
		_next_pause = now_msec + _rng.randi_range(STROLL_MIN_MS, STROLL_MAX_MS)
	if _pause_until >= now_msec:
		return {"clip": &"idle", "motion": &"stand"}
	if now_msec >= _next_pause:
		_pause_until = now_msec + _rng.randi_range(PAUSE_MIN_MS, PAUSE_MAX_MS)
		_next_pause = _pause_until + _rng.randi_range(STROLL_MIN_MS, STROLL_MAX_MS)
		return {"clip": &"idle", "motion": &"stand"}
	return {"clip": &"walk", "motion": &"stroll"}
