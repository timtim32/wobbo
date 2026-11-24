extends "res://tests/base_test.gd"
## Growing the strip windows while a buddy is carried (buddy-drag D6).

const OverlayScript := preload("res://scripts/autoload/overlay_controller.gd")

var o: Node
var s


func before_each() -> void:
	o = OverlayScript.new() # not in the tree: no windows, no _ready
	o.walkway = Walkway.build([{"id": 1, "name": "A", "main": true,
		"rect_px": Rect2(0, 1244, 3024, 720)}], 2.0)
	s = OverlayScript.Strip.new()
	s.id = 1
	s.rect_px = Rect2i(0, 1244, 3024, 720)
	s.room_px = 1178
	o._strips.append(s)


func after_each() -> void:
	o.free()


func test_window_rect_grows_upwards_and_keeps_the_bottom() -> void:
	assert_eq(o._window_rect(s), Rect2i(0, 1244, 3024, 720), "off")
	o._headroom_on = true
	var r: Rect2i = o._window_rect(s)
	assert_eq(r, Rect2i(0, 66, 3024, 1898), "on")
	assert_eq(r.end.y, s.rect_px.end.y, "same bottom edge")
	assert_eq(o.strip_window_rect_px(0), r)


func test_headroom_in_points() -> void:
	assert_eq(o.headroom_pt(0), 589.0)
	assert_eq(o.headroom_pt(5), 0.0, "unknown strip")


func test_window_coordinates_round_trip() -> void:
	for on in [false, true]:
		o._headroom_on = on
		var head := Vector2(0.0, o._head_px(s))
		for p in [Vector2(100, 300), Vector2(700, -400), Vector2(10, -589)]:
			var window_px: Vector2 = o.walkway_to_local(0, p) + head
			if on:
				assert_true(window_px.y >= 0.0, "inside the grown window: %s" % window_px)
			assert_eq(o.local_to_walkway(0, window_px - head), p, "round trip %s (headroom %s)" % [p, on])


func test_reference_counting() -> void:
	o._headroom_on = true
	o._headroom_refs = 2
	o.end_headroom()
	assert_eq(o._headroom_linger, -1.0, "still one carry")
	o.end_headroom()
	assert_eq(o._headroom_linger, OverlayScript.HEADROOM_LINGER_SEC, "lingers before shrinking")
	o.end_headroom()
	assert_eq(o._headroom_refs, 0, "never below zero")
