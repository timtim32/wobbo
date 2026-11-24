extends RefCounted
## Tells a click from picking a buddy up (buddy-drag D1). Pure.
##
## A left press becomes a grab once the button has been held for HOLD_SEC or the
## pointer has moved MOVE_PT from where it went down. A release before that is
## a click. Points are walkway points, times seconds.

const HOLD_SEC := 0.25
const MOVE_PT := 6.0

var _pressed := false
var _grabbed := false
var _start := Vector2.ZERO
var _t0 := 0.0


func press(point: Vector2, now: float) -> void:
	_pressed = true
	_grabbed = false
	_start = point
	_t0 = now


func is_pressed() -> bool:
	return _pressed


func is_grabbed() -> bool:
	return _grabbed


## Called each frame while the button is down. Returns &"grab" on the frame the
## press turns into a grab, &"" otherwise.
func update(point: Vector2, now: float) -> StringName:
	if not _pressed or _grabbed:
		return &""
	if _passed(point, now):
		_grabbed = true
		return &"grab"
	return &""


## The button went up. Returns &"click" for a press that never became a grab,
## &"drop" for one that did (or reached the threshold just now), &"" without a press.
func release(point: Vector2, now: float) -> StringName:
	if not _pressed:
		return &""
	_pressed = false
	var was := _grabbed or _passed(point, now)
	_grabbed = false
	return &"drop" if was else &"click"


## Forgets the press without a click (e.g. the buddy left meanwhile).
func cancel() -> void:
	_pressed = false
	_grabbed = false


func _passed(point: Vector2, now: float) -> bool:
	return now - _t0 >= HOLD_SEC or point.distance_to(_start) >= MOVE_PT
