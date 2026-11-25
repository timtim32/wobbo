extends RefCounted
## A carried buddy as a point mass on a rod hanging from the pointer, and its
## flight and landing after release (buddy-drag D2). Pure.
##
## Walkway points and seconds, y pointing down. The body is described in its
## own upright frame with the feet at the origin; `tilt` rotates it around the
## feet, which is how the views draw it (buddy-drag D3).
##
## held:    the grab point follows the pointer; the rod angle `_theta` (from
##          straight down, positive = centre of mass to the right) obeys the
##          pendulum equation for an accelerating pivot, without any limit, so
##          the body can spin all the way round. Godot rotates the other way
##          round (Vector2.rotated, Node2D.rotation), so tilt = theta0 - theta.
## flying:  the centre of mass falls under gravity, the body keeps spinning.
## landing: feet on the floor, the body turns upright and slides to a stop.
## rest:    done; the owner takes over again.

const GRAVITY_PT := 2400.0
const DAMPING := 1.0 # 1/s on the swing's angular speed
const MIN_ROD := 0.3 # times the body height
const MAX_ACCEL := 40000.0 # pt/s², clamps pointer jitter
const PIVOT_SMOOTH_SEC := 0.03 # follower that turns pointer steps into an acceleration
const MAX_SPIN := 3.0 # turns per second
const AIR_SPIN_DAMPING := 0.4 # 1/s
const UPRIGHT_SEC := 0.15
const SLIDE_SEC := 0.2
const BOUNCE := 0.5 # speed kept when hitting a walkway end or the top
const STEP := 1.0 / 240.0

var mode: StringName = &"rest"
## Output: feet point and rotation of the body.
var feet := Vector2.ZERO
var tilt := 0.0

var _grab_local := Vector2.ZERO # grab point in the upright body frame
var _com_local := Vector2.ZERO # centre of mass in the upright body frame
var _height := 0.0 # the body's height, set by grab()
var _rod := 1.0
var _theta := 0.0
var _theta0 := 0.0 # rod angle that means tilt 0
var _omega := 0.0 # d theta / dt (held), d tilt / dt (flying)
var _pivot := Vector2.ZERO # follower position
var _pivot_v := Vector2.ZERO
var _pivot_a := Vector2.ZERO
var _target := Vector2.ZERO # last pointer target
var _com := Vector2.ZERO # flying / landing
var _com_v := Vector2.ZERO
var _land_t := 0.0
var _land_tilt := 0.0
var _land_vx := 0.0
var _leftover_sec := 0.0 # part of the last frame not yet simulated in whole steps


## Picks the body up at `grab_point` (walkway points). `feet` and `current_tilt`
## describe where the body is now; `com_local` is its centre in the upright frame.
func grab(feet_now: Vector2, current_tilt: float, grab_point: Vector2, com_local: Vector2,
		body_height: float) -> void:
	var spin := -_omega if mode == &"flying" else 0.0 # d tilt/dt -> d theta/dt
	_com_local = com_local
	_height = body_height
	_grab_local = (grab_point - feet_now).rotated(-current_tilt)
	var r0 := (_com_local - _grab_local).rotated(current_tilt)
	_rod = maxf(r0.length(), MIN_ROD * body_height)
	_theta = atan2(r0.x, r0.y)
	_theta0 = _theta + current_tilt
	_omega = spin
	_pivot = grab_point
	_target = grab_point
	_pivot_v = Vector2.ZERO
	_pivot_a = Vector2.ZERO
	_leftover_sec = 0.0
	mode = &"held"
	_update_held_output()


## Lets go: the body flies on with the pivot's speed plus its swing.
func release() -> void:
	if mode != &"held":
		return
	var r := _rod * Vector2(sin(_theta), cos(_theta))
	_com = feet + _com_local.rotated(tilt)
	_com_v = _pivot_v + _omega * Vector2(r.y, -r.x)
	_omega = -_omega # from now on d tilt / dt
	mode = &"flying"


## Launches the body from standing at `feet_now` with `velocity` (points per
## second) and `spin` (radians per second, positive = clockwise): it flies,
## falls and lands like a released buddy (side-climb: jumping down).
func throw(feet_now: Vector2, com_local: Vector2, body_height: float, velocity: Vector2, spin: float) -> void:
	_com_local = com_local
	_height = body_height
	tilt = 0.0
	feet = feet_now
	_com = feet_now + com_local
	_com_v = velocity
	_omega = spin
	_leftover_sec = 0.0
	mode = &"flying"


## Moves the whole state by `offset`: the body changes to another strip's
## walkway coordinates over the seam of stacked displays (side-climb).
func shift(offset: Vector2) -> void:
	feet += offset
	_com += offset
	_pivot += offset
	_target += offset


func is_busy() -> bool:
	return mode != &"rest"


## Full turns of the body since the grab (for tests and logs).
func turns() -> float:
	return tilt / TAU


## Advances `dt` seconds. `target` is the pointer (held only), `limits` the
## walkway's x range (position.x .. end.x) and the highest y the body may reach
## (position.y), `floor_y` the floor under the body.
func step(dt: float, target: Vector2, limits: Rect2, floor_y: float) -> void:
	if mode == &"rest":
		return
	var from := _target
	if mode == &"held":
		_target = Vector2(clampf(target.x, limits.position.x, limits.end.x), maxf(target.y, limits.position.y))
	var total := _leftover_sec + dt
	var n := int(floor(total / STEP + 1e-6))
	_leftover_sec = total - n * STEP
	for k in n:
		match mode:
			&"held":
				_step_held(from.lerp(_target, float(k + 1) / n), STEP)
			&"flying":
				_step_flying(STEP, limits, floor_y)
			&"landing":
				_step_landing(STEP, limits, floor_y)
	match mode:
		&"held":
			_update_held_output()
		&"flying":
			feet = _com - _com_local.rotated(tilt)
		&"landing":
			feet = Vector2(_com.x - _com_local.x, floor_y)


func _step_held(target: Vector2, h: float) -> void:
	# Critically damped follower: its acceleration is the pivot acceleration.
	var w := 1.0 / PIVOT_SMOOTH_SEC
	_pivot_a = w * w * (target - _pivot) - 2.0 * w * _pivot_v
	if _pivot_a.length() > MAX_ACCEL:
		_pivot_a = _pivot_a.normalized() * MAX_ACCEL
	_pivot_v += _pivot_a * h
	_pivot += _pivot_v * h
	var alpha := -((GRAVITY_PT - _pivot_a.y) * sin(_theta) + _pivot_a.x * cos(_theta)) / _rod - DAMPING * _omega
	_omega = clampf(_omega + alpha * h, -MAX_SPIN * TAU, MAX_SPIN * TAU)
	_theta += _omega * h


func _update_held_output() -> void:
	tilt = _theta0 - _theta
	# Drawn at the real pointer, so the grab point never lags behind it.
	feet = _target - _grab_local.rotated(tilt)


func _step_flying(h: float, limits: Rect2, floor_y: float) -> void:
	_com_v.y += GRAVITY_PT * h
	_com += _com_v * h
	tilt += _omega * h
	_omega *= exp(-AIR_SPIN_DAMPING * h)
	var half := _height * 0.5
	if _com.x < limits.position.x + half and _com_v.x < 0.0:
		_com.x = limits.position.x + half
		_com_v.x = -_com_v.x * BOUNCE
	elif _com.x > limits.end.x - half and _com_v.x > 0.0:
		_com.x = limits.end.x - half
		_com_v.x = -_com_v.x * BOUNCE
	if _com.y < limits.position.y + half and _com_v.y < 0.0:
		_com.y = limits.position.y + half
		_com_v.y = -_com_v.y * BOUNCE
	var standing := floor_y + _com_local.y # centre height when standing upright
	if _com.y >= standing and _com_v.y > 0.0:
		_com.y = standing
		_land_tilt = wrapf(tilt, -PI, PI)
		tilt = _land_tilt
		_land_vx = _com_v.x
		_com_v = Vector2.ZERO
		_omega = 0.0
		_land_t = 0.0
		mode = &"landing"


func _step_landing(h: float, limits: Rect2, floor_y: float) -> void:
	_land_t += h
	_com.y = floor_y + _com_local.y
	var slide := maxf(0.0, 1.0 - _land_t / SLIDE_SEC)
	_com.x = clampf(_com.x + _land_vx * slide * h, limits.position.x + _height * 0.5,
		limits.end.x - _height * 0.5)
	var k := clampf(_land_t / UPRIGHT_SEC, 0.0, 1.0)
	tilt = _land_tilt * (1.0 - k) * (1.0 - k)
	if _land_t >= maxf(UPRIGHT_SEC, SLIDE_SEC):
		tilt = 0.0
		mode = &"rest"
