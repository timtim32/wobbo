extends "res://tests/base_test.gd"
## Walkway geometry, display matching and home display (multi-display D2, D6).

const Displays := preload("res://scripts/core/displays.gd")
const HomeDisplay := preload("res://scripts/core/home_display.gd")

# This machine: built-in 1512x982 pt (left, lower), ultrawide 3440x1440 pt (right, higher); max scale 2.
const BUILTIN := {"id": 1, "name": "Built-in", "main": true, "rect_px": Rect2(0, 2482, 3024, 720)}
const WIDE := {"id": 2, "name": "LG", "main": false, "rect_px": Rect2(3024, 2160, 6880, 720)}


func test_one_display() -> void:
	var w = Walkway.build([BUILTIN], 2.0)
	assert_eq(w.segments.size(), 1)
	assert_eq(w.total_width(), 1512.0)
	assert_eq(w.index_at(100.0), 0)
	assert_eq(w.index_at(5000.0), 0, "clamped to the last segment")


func test_two_side_by_side_ordered_left_to_right() -> void:
	var w = Walkway.build([WIDE, BUILTIN], 2.0)
	assert_eq(w.segments[0].id, 1, "built-in first (leftmost)")
	assert_eq(w.segments[1].start, 1512.0)
	assert_eq(w.total_width(), 1512.0 + 3440.0)
	assert_eq(w.index_at(1511.9), 0)
	assert_eq(w.index_at(1512.0), 1)
	assert_eq(w.to_local(1, 1600.0), 88.0)
	assert_eq(w.main_index(), 0)
	assert_eq(w.index_of(2), 1)


func test_three_displays() -> void:
	var left := {"id": 3, "name": "Left", "main": false, "rect_px": Rect2(-3840, 2000, 3840, 720)}
	var w = Walkway.build([BUILTIN, WIDE, left], 2.0)
	assert_eq(w.segments.map(func(s): return s.id), [3, 1, 2])
	assert_eq(w.segments[1].start, 1920.0)


func test_display_removed_remaps_to_nearest_edge() -> void:
	var before = Walkway.build([BUILTIN, WIDE], 2.0)
	var after = Walkway.build([BUILTIN], 2.0)
	assert_eq(after.remap(3000.0, before), 1512.0, "body on the removed right display enters at the right edge")
	assert_eq(after.remap(700.0, before), 700.0, "body on a remaining display keeps its place")


func test_display_added_keeps_positions() -> void:
	var before = Walkway.build([WIDE], 2.0)
	var after = Walkway.build([BUILTIN, WIDE], 2.0)
	assert_eq(after.remap(100.0, before), 1612.0, "same spot on the same display, now further along")


func test_match_native_displays_to_godot_screens() -> void:
	var native := [
		{"id": 1, "name": "Built-in", "frame": Rect2(0, 0, 1512, 982), "scale": 2.0, "main": true},
		{"id": 2, "name": "LG", "frame": Rect2(1512, -619, 3440, 1440), "scale": 1.0, "main": false},
	]
	var godot := [Rect2(0, 1238, 3024, 1964), Rect2(3024, 0, 6880, 2880)]
	var m := Displays.match(native, godot, 2.0)
	assert_eq(m[0].screen, 0)
	assert_eq(m[1].screen, 1)
	assert_eq(m[1].name, "LG")
	assert_eq(Displays.match(native, [Rect2(0, 0, 10, 10)], 2.0)[0].screen, -1, "no matching screen")


func test_home_chosen_display() -> void:
	var h := HomeDisplay.new()
	assert_eq(h.update("2", [1, 2], 1, 1, 0.0), 2)
	assert_eq(h.update("2", [1, 2], 1, 1, 10.0), 2, "stays, wherever the pointer is")


func test_home_chosen_display_missing_falls_back_to_main() -> void:
	var h := HomeDisplay.new()
	assert_eq(h.update("2", [1], 1, 1, 0.0), 1)
	assert_eq(h.update("2", [1, 2], 1, 1, 1.0), 2, "comes back when reconnected")


func test_home_automatic_with_dwell() -> void:
	var h := HomeDisplay.new()
	assert_eq(h.update("auto", [1, 2], 1, 1, 0.0), 1)
	assert_eq(h.update("auto", [1, 2], 1, 2, 1.0), 1, "pointer just arrived")
	assert_eq(h.update("auto", [1, 2], 1, 2, 2.5), 1, "1.5 s is not enough")
	assert_eq(h.update("auto", [1, 2], 1, 2, 3.0), 2, "after 2 s it becomes home")


func test_home_automatic_ignores_brief_visits() -> void:
	var h := HomeDisplay.new()
	h.update("auto", [1, 2], 1, 1, 0.0)
	h.update("auto", [1, 2], 1, 2, 1.0)
	assert_eq(h.update("auto", [1, 2], 1, 1, 1.5), 1, "back before the dwell")
	assert_eq(h.update("auto", [1, 2], 1, 2, 2.0), 1, "dwell restarts")
	assert_eq(h.update("auto", [1, 2], 1, 2, 3.9), 1)
	assert_eq(h.update("auto", [1, 2], 1, 2, 4.0), 2)


func test_home_automatic_when_home_disconnects() -> void:
	var h := HomeDisplay.new()
	h.update("auto", [1, 2], 1, 2, 0.0)
	h.update("auto", [1, 2], 1, 2, 3.0)
	assert_eq(h.update("auto", [1], 1, 1, 4.0), 1, "home display gone: main display")


func test_views_needed_for_a_body() -> void:
	var w = Walkway.build([BUILTIN, WIDE], 2.0)
	assert_eq(w.indices_overlapping(Rect2(100, 0, 60, 100)), [0] as Array[int], "on the built-in display")
	assert_eq(w.indices_overlapping(Rect2(1490, 0, 60, 100)), [0, 1] as Array[int], "crossing: two views")
	assert_eq(w.indices_overlapping(Rect2(1600, 0, 60, 100)), [1] as Array[int], "fully on the external display")


func test_travel_decisions() -> void:
	var w = Walkway.build([BUILTIN, WIDE], 2.0)
	assert_eq(w.direction_to(1, 700.0, 30.0), 1, "home on the right: walk right")
	assert_eq(w.direction_to(0, 3000.0, 30.0), -1, "home on the left: walk left")
	assert_eq(w.direction_to(1, 1530.0, 30.0), 1, "half across: keep going")
	assert_eq(w.direction_to(1, 1545.0, 30.0), 0, "fully on the home display: arrived")
	assert_true(w.fully_on(0, 30.0, 30.0) and not w.fully_on(0, 29.0, 30.0), "edges")


func test_screen_menu_items() -> void:
	const ScreenMenu := preload("res://scripts/core/screen_menu.gd")
	var displays := [{"id": 1, "name": "Built-in Retina Display", "main": true}, {"id": 2, "name": "LG HDR WQHD", "main": false}]
	var items := ScreenMenu.items(displays, "auto", "")
	assert_eq(items.map(func(i): return i.label), ["Automatic (follow the mouse)", "", "Built-in Retina Display (main)", "LG HDR WQHD"])
	assert_eq(items.filter(func(i): return i.checked).size(), 1, "exactly one checked")
	assert_true(items[0].checked)
	var chosen := ScreenMenu.items(displays, "2", "LG HDR WQHD")
	assert_true(chosen[3].checked and not chosen[0].checked)
	var missing := ScreenMenu.items([displays[0]], "2", "LG HDR WQHD")
	assert_eq(missing[-1].label, "LG HDR WQHD (not connected)")
	assert_true(missing[-1].checked and missing[-1].disabled)
