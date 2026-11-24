extends RefCounted
## An avatar's lift above the shown Dock (dock-dodge design D4). Pure: the
## target, the ceiling and the frame time are passed in.
##
## A change of target starts a hop: an ease-out rise (or ease-in fall) towards
## the new lift plus a small arc on top, so it reads as a jump, not a slide.

const HOP_SEC := 0.3
const HOP_ARC_PT := 16.0

## Current lift in points, before the ceiling (may include the arc).
var value := 0.0
## Counts the hops started, so the avatar can play its jump clip on each.
var hops := 0
var _from := 0.0
var _to := 0.0
var _t := 1.0


## The highest lift that keeps the head and the name label inside the strip.
## `floor_y`: the feet on the floor (from the strip top); `head_top`: the top of
## the head relative to the feet (negative); `label_room`: space above the head.
static func max_lift(floor_y: float, head_top: float, label_room: float) -> float:
	return maxf(0.0, floor_y + head_top - label_room)


## Advances the hop by `delta` seconds towards `target`; returns the lift to use.
func step(target: float, ceiling: float, delta: float) -> float:
	target = clampf(target, 0.0, maxf(ceiling, 0.0))
	if not is_equal_approx(target, _to):
		_from = value
		_to = target
		_t = 0.0
		hops += 1
	if _t < 1.0:
		_t = minf(1.0, _t + delta / HOP_SEC)
		var e := 1.0 - (1.0 - _t) * (1.0 - _t) if _to > _from else _t * _t
		value = _to if _t >= 1.0 else lerpf(_from, _to, e) + HOP_ARC_PT * sin(PI * _t)
	else:
		value = _to
	return clampf(value, 0.0, maxf(ceiling, 0.0))
