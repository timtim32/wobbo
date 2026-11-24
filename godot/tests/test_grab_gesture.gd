extends "res://tests/base_test.gd"
## Click or grab (buddy-drag D1).

const GrabGesture := preload("res://scripts/core/grab_gesture.gd")

var g: GrabGesture


func before_each() -> void:
	g = GrabGesture.new()


func test_quick_click() -> void:
	g.press(Vector2(10, 10), 1.0)
	assert_eq(g.update(Vector2(10, 10), 1.1), &"")
	assert_eq(g.release(Vector2(11, 10), 1.15), &"click")
	assert_false(g.is_pressed())


func test_hold_without_moving() -> void:
	g.press(Vector2(10, 10), 1.0)
	assert_eq(g.update(Vector2(10, 10), 1.2), &"")
	assert_eq(g.update(Vector2(10, 10), 1.26), &"grab")
	assert_true(g.is_grabbed())
	assert_eq(g.update(Vector2(10, 10), 1.3), &"", "grab is reported once")
	assert_eq(g.release(Vector2(10, 10), 2.0), &"drop")


func test_move_before_the_hold_time() -> void:
	g.press(Vector2(10, 10), 1.0)
	assert_eq(g.update(Vector2(13, 10), 1.05), &"")
	assert_eq(g.update(Vector2(16, 10), 1.06), &"grab")


func test_release_exactly_at_the_threshold() -> void:
	g.press(Vector2(10, 10), 1.0)
	assert_eq(g.release(Vector2(10, 10), 1.0 + GrabGesture.HOLD_SEC), &"drop", "time")
	g.press(Vector2(10, 10), 3.0)
	assert_eq(g.release(Vector2(10 + GrabGesture.MOVE_PT, 10), 3.01), &"drop", "distance")


func test_release_without_press() -> void:
	assert_eq(g.release(Vector2.ZERO, 1.0), &"")
	assert_eq(g.update(Vector2.ZERO, 1.0), &"")


func test_cancel() -> void:
	g.press(Vector2(10, 10), 1.0)
	g.cancel()
	assert_eq(g.release(Vector2(10, 10), 1.1), &"")
