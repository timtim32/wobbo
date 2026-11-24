extends "res://tests/base_test.gd"
## A buddy on the pointer: swinging, spinning, flying and landing (buddy-drag D2).

const SwingPhysics := preload("res://scripts/core/swing_physics.gd")

const H := 110.0 # a Normal buddy
const COM := Vector2(0, -55) # its centre, feet at the origin
const LIMITS := Rect2(0, -1000, 1500, 2000)
const FLOOR := 352.0

var s: SwingPhysics


func before_each() -> void:
	s = SwingPhysics.new()


## Runs `seconds` at `fps` with the pointer at path.call(t); returns the largest |turns()| seen.
func _run(seconds: float, fps: float, path: Callable, t0 := 0.0) -> float:
	var most := 0.0
	var frames := int(round(seconds * fps))
	for i in frames:
		var t := t0 + (i + 1) / fps
		s.step(1.0 / fps, path.call(t), LIMITS, FLOOR)
		most = maxf(most, absf(s.turns()))
	return most


func _grab_head(at: Vector2) -> void:
	# Feet straight below the pointer, grabbed at the top of the head.
	s.grab(at + Vector2(0, H), 0.0, at, COM, H)


func test_grab_does_not_jump() -> void:
	s.grab(Vector2(200, 352), 0.0, Vector2(170, 260), COM, H)
	assert_eq(s.mode, &"held")
	assert_true(s.feet.distance_to(Vector2(200, 352)) < 0.01, "feet stay put: %s" % s.feet)
	assert_true(absf(s.tilt) < 0.001, "no tilt at grab")


func test_still_pointer_hangs_straight_below() -> void:
	var p := Vector2(500, -200)
	_grab_head(p)
	_run(3.0, 60, func(_t: float) -> Vector2: return p)
	assert_true(absf(s.tilt) < 0.01, "hangs straight: %f" % s.tilt)
	assert_true(s.feet.distance_to(p + Vector2(0, H)) < 0.5, "feet below the head: %s" % s.feet)


func test_grabbed_by_an_ear_hangs_below_it() -> void:
	var ear := Vector2(-35, -100) # left ear, feet at the origin
	var p := Vector2(500, -200)
	s.grab(p - ear, 0.0, p, COM, H)
	var r0 := COM - ear
	_run(15.0, 60, func(_t: float) -> Vector2: return p)
	# The body has turned so its centre is straight below the ear.
	var centre := s.feet + COM.rotated(s.tilt)
	assert_true(absf(centre.x - p.x) < 1.0, "centre below the ear: %s" % centre)
	assert_true(absf(s.tilt - atan2(r0.x, r0.y)) < 0.02, "tilt %f" % s.tilt)


func test_small_circles_make_it_spin() -> void:
	var p := Vector2(600, -200)
	_grab_head(p)
	var f := sqrt(SwingPhysics.GRAVITY_PT / 55.0) / TAU # the swing's own pace
	var circle := func(t: float) -> Vector2: return p + 40.0 * Vector2(sin(TAU * f * t), -cos(TAU * f * t) + 1.0)
	var most := _run(5.0 / f, 60, circle)
	assert_true(most > 1.0, "a full turn within 5 circles (%.2f turns)" % most)


func test_flick_then_stop_comes_to_rest() -> void:
	var p := Vector2(400, -200)
	_grab_head(p)
	var flick := func(t: float) -> Vector2: return p + Vector2(300.0 * clampf(t / 0.2, 0.0, 1.0), 0)
	var most := _run(1.0, 60, flick)
	assert_true(most > 0.05, "it swings (%.2f turns)" % most)
	_run(12.0, 60, func(_t: float) -> Vector2: return p + Vector2(300, 0), 1.0)
	assert_true(absf(wrapf(s.tilt, -PI, PI)) < 0.05, "comes to rest: %f" % s.tilt)


func test_throw_left_lands_further_left() -> void:
	var p := Vector2(800, -100)
	_grab_head(p)
	_run(2.0, 60, func(_t: float) -> Vector2: return p)
	var throw := func(t: float) -> Vector2: return p - Vector2(150.0 * (t - 2.0) / 0.2, 0)
	_run(0.2, 60, throw, 2.0)
	var released_x := s.feet.x
	s.release()
	assert_eq(s.mode, &"flying")
	_run(5.0, 60, func(_t: float) -> Vector2: return Vector2.ZERO)
	assert_eq(s.mode, &"rest")
	assert_true(s.feet.x < released_x - 50.0, "lands left of %f: %f" % [released_x, s.feet.x])


func test_landing_is_upright_on_the_floor() -> void:
	var p := Vector2(600, -200)
	_grab_head(p)
	var circle := func(t: float) -> Vector2: return p + 40.0 * Vector2(sin(6.6 * t), -cos(6.6 * t) + 1.0)
	_run(3.0, 60, circle)
	s.release()
	var tumbled := false
	for i in 300:
		s.step(1.0 / 60, Vector2.ZERO, LIMITS, FLOOR)
		tumbled = tumbled or (s.mode == &"flying" and absf(s.tilt) > 0.5)
	assert_eq(s.mode, &"rest")
	assert_eq(s.tilt, 0.0)
	assert_true(absf(s.feet.y - FLOOR) < 0.001, "on the floor: %f" % s.feet.y)
	assert_true(tumbled, "it tumbled while falling")


func test_stays_within_the_walkway() -> void:
	var p := Vector2(100, -100)
	_grab_head(p)
	_run(0.3, 60, func(t: float) -> Vector2: return p - Vector2(2000.0 * t, 0))
	assert_true(s.feet.x >= -H, "held pointer clamped: %f" % s.feet.x)
	s.release()
	_run(5.0, 60, func(_t: float) -> Vector2: return Vector2.ZERO)
	assert_true(s.feet.x >= H * 0.5 - 0.01, "landed inside: %f" % s.feet.x)


func test_caught_while_falling() -> void:
	var p := Vector2(600, -300)
	_grab_head(p)
	s.release()
	_run(0.1, 60, func(_t: float) -> Vector2: return Vector2.ZERO)
	var at := s.feet + Vector2(0, -80).rotated(s.tilt)
	s.grab(s.feet, s.tilt, at, COM, H)
	assert_eq(s.mode, &"held")
	assert_true(s.feet.distance_to(s.feet) < 0.01)


func test_same_at_30_and_60_fps() -> void:
	var p := Vector2(400, -200)
	var sway := func(t: float) -> Vector2: return p + Vector2(150.0 * sin(3.0 * t), 0)
	_grab_head(p)
	_run(1.0, 60, sway)
	var tilt60 := s.tilt
	s = SwingPhysics.new()
	_grab_head(p)
	_run(1.0, 30, sway)
	assert_true(absf(s.tilt - tilt60) < 0.1, "30 fps %f vs 60 fps %f" % [s.tilt, tilt60])
