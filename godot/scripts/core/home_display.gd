extends RefCounted
## Chooses the buddies' home display (multi-display design D6). Pure: time and
## the display under the pointer are passed in.
##
## setting "auto": follow the pointer after it stayed on another display for
## DWELL_SEC. Otherwise the setting is a display id: that display when it is
## connected, else the main display (the choice itself is kept by the caller).

const AUTO := "auto"
const DWELL_SEC := 2.0

var _home := -1
var _candidate := -1
var _candidate_since := 0.0


## Returns the home display id.
func update(setting: String, connected: Array, main_id: int, pointer_id: int, now_sec: float) -> int:
	if setting != AUTO:
		var wanted := int(setting) if setting.is_valid_int() else -1
		_home = wanted if wanted in connected else main_id
		_candidate = -1
		return _home
	if not _home in connected:
		_home = pointer_id if pointer_id in connected else main_id
		_candidate = -1
	if pointer_id == _home or not pointer_id in connected:
		_candidate = -1
	elif pointer_id != _candidate:
		_candidate = pointer_id
		_candidate_since = now_sec
	elif now_sec - _candidate_since >= DWELL_SEC:
		_home = pointer_id
		_candidate = -1
	return _home
