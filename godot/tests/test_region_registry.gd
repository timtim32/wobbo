extends "res://tests/base_test.gd"

const RegionRegistry := preload("res://scripts/core/region_registry.gd")

var reg: RegionRegistry


func before_each() -> void:
	reg = RegionRegistry.new()
	reg.set_region(&"a", Rect2(100, 50, 40, 40)) # x 100..140, y 50..90
	reg.set_region(&"b", Rect2(300, 50, 40, 40)) # x 300..340


func test_point_inside_one_region() -> void:
	assert_eq(reg.region_at(Vector2(120, 70)), &"a")
	assert_eq(reg.region_at(Vector2(320, 70)), &"b")
	assert_eq(reg.passthrough_target(Vector2(120, 70)), &"a")


func test_point_between_regions_passes_through() -> void:
	assert_eq(reg.region_at(Vector2(200, 70)), &"")
	assert_eq(reg.passthrough_target(Vector2(200, 70)), &"")
	assert_eq(reg.region_at(Vector2(120, 10)), &"", "above region")


func test_edges_are_half_open() -> void:
	assert_eq(reg.region_at(Vector2(100, 50)), &"a", "top-left corner is inside")
	assert_eq(reg.region_at(Vector2(139.9, 89.9)), &"a", "just before bottom-right is inside")
	assert_eq(reg.region_at(Vector2(140, 70)), &"", "right edge is outside")
	assert_eq(reg.region_at(Vector2(120, 90)), &"", "bottom edge is outside")
	assert_eq(reg.region_at(Vector2(99.9, 70)), &"", "just left of the left edge is outside")


func test_overlap_last_registered_wins() -> void:
	reg.set_region(&"c", Rect2(130, 60, 40, 40))
	assert_eq(reg.region_at(Vector2(135, 70)), &"c")
	assert_eq(reg.region_at(Vector2(110, 70)), &"a")


func test_update_and_remove() -> void:
	reg.set_region(&"a", Rect2(500, 50, 40, 40))
	assert_eq(reg.region_at(Vector2(120, 70)), &"", "old position no longer hits")
	assert_eq(reg.region_at(Vector2(520, 70)), &"a", "new position hits")
	reg.remove_region(&"a")
	assert_eq(reg.region_at(Vector2(520, 70)), &"")
	assert_false(reg.has_region(&"a"))
	reg.remove_region(&"missing") # no error


func test_negative_size_rect_is_normalised() -> void:
	reg.set_region(&"n", Rect2(700, 90, -40, -40))
	assert_eq(reg.region_at(Vector2(680, 70)), &"n")


func test_drag_capture_while_cursor_leaves_region() -> void:
	assert_eq(reg.press(Vector2(120, 70)), &"a")
	assert_true(reg.is_capturing())
	assert_eq(reg.passthrough_target(Vector2(120, 70)), RegionRegistry.CAPTURE, "inside region")
	assert_eq(reg.passthrough_target(Vector2(250, 70)), RegionRegistry.CAPTURE, "between regions")
	assert_eq(reg.passthrough_target(Vector2(320, 70)), RegionRegistry.CAPTURE, "over another region")
	assert_eq(reg.release(), &"a")
	assert_false(reg.is_capturing())
	assert_eq(reg.passthrough_target(Vector2(250, 70)), &"", "passes through after release")


func test_drag_capture_survives_region_removal() -> void:
	reg.press(Vector2(120, 70))
	reg.remove_region(&"a")
	assert_eq(reg.passthrough_target(Vector2(120, 70)), RegionRegistry.CAPTURE)
	reg.release()
	assert_eq(reg.passthrough_target(Vector2(120, 70)), &"")


func test_press_outside_does_not_capture() -> void:
	assert_eq(reg.press(Vector2(200, 70)), &"")
	assert_false(reg.is_capturing())
	assert_eq(reg.release(), &"")


func test_clear_drops_regions_and_capture() -> void:
	reg.press(Vector2(120, 70))
	reg.clear()
	assert_true(reg.is_empty())
	assert_false(reg.is_capturing())
	assert_eq(reg.passthrough_target(Vector2(120, 70)), &"")
