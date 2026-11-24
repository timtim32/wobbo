extends "res://tests/base_test.gd"
## Where a balloon goes (balloons-and-speech design D6).

const Layout := preload("res://scripts/core/balloon_layout.gd")

const SIZE := Vector2(200, 80)


func test_centred_over_a_head_in_the_middle() -> void:
	var p := Layout.place(500.0, 240.0, SIZE, 0.0, 1440.0)
	assert_eq(p.rect, Rect2(400, 240 - 6 - 10 - 80, 200, 80))
	assert_eq(p.tail_x, 100.0, "tail in the middle")


func test_kept_on_the_display_at_the_left_edge() -> void:
	var p := Layout.place(40.0, 240.0, SIZE, 0.0, 1440.0)
	assert_eq(p.rect.position.x, 8.0, "8 pt from the edge")
	assert_eq(p.tail_x, 32.0, "tail still under the head")


func test_kept_on_the_display_at_the_right_edge() -> void:
	var p := Layout.place(1435.0, 240.0, SIZE, 0.0, 1440.0)
	assert_eq(p.rect.end.x, 1432.0)
	assert_eq(p.tail_x, 200.0 - 17.0, "tail as far right as the corner allows")


func test_on_a_second_display() -> void:
	var p := Layout.place(1500.0, 240.0, SIZE, 1440.0, 3360.0)
	assert_eq(p.rect.position.x, 1448.0, "kept on the second display, not the first")


func test_room_per_size() -> void:
	# Floor at 360 - 8; head tops at Small (80 pt) and Extra large (170 pt).
	assert_eq(Layout.max_height(352.0 - 80.0), 272.0 - 20.0)
	assert_eq(Layout.max_height(352.0 - 170.0), 182.0 - 20.0)
	assert_eq(Layout.max_height(10.0), 0.0, "never negative")


func test_width_limits() -> void:
	assert_eq(Layout.width_for(40.0), 120.0)
	assert_eq(Layout.width_for(250.0), 250.0)
	assert_eq(Layout.width_for(900.0), 300.0)
