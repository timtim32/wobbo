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


# --- Climb links between stacked displays (side-climb D1, D2, D6) ---------------

# The user's desk: an HP (1920x1080 pt) standing on the built-in display
# (1512x982 pt), sticking out 229 pt left and 179 pt right. Global px at scale 2.
const HP_TOP := {"id": 2, "name": "HP", "main": false,
	"rect_px": Rect2(0, 1440, 3840, 720), "frame_px": Rect2(0, 0, 3840, 2160)}
const BUILTIN_BELOW := {"id": 1, "name": "Built-in", "main": true,
	"rect_px": Rect2(458, 3404, 3024, 720), "frame_px": Rect2(458, 2160, 3024, 1964)}


func test_stacked_displays_get_a_climb_link_with_both_sides() -> void:
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP], 2.0)
	assert_eq(w.segments[0].id, 2, "HP first (further left)")
	assert_eq(w.links.size(), 1)
	var link = w.links[0]
	assert_eq(link.kind, &"climb")
	assert_eq(link.lower, 1)
	assert_eq(link.upper, 0)
	assert_eq(link.sides.size(), 2)
	assert_eq(link.sides[0].dir, 1, "right edge first")
	assert_eq(link.sides[0].lower_x, 3432.0, "right end of the built-in strip")
	assert_eq(link.sides[0].upper_x, 1741.0, "the same desk x on the HP")
	assert_eq(link.sides[1].dir, -1)
	assert_eq(link.sides[1].lower_x, 1920.0)
	assert_eq(link.sides[1].upper_x, 229.0)
	assert_eq(link.top_y, -622.0, "the built-in display's top, above its strip")
	assert_eq(link.top_y + link.upper_dy, 360.0, "is the bottom of the HP strip")


func test_side_by_side_at_different_heights_is_an_edge() -> void:
	var a := BUILTIN.duplicate()
	a.frame_px = Rect2(0, 1238, 3024, 1964)
	var b := WIDE.duplicate()
	b.frame_px = Rect2(3024, 0, 6880, 2880)
	var w = Walkway.build([a, b], 2.0)
	assert_eq(w.links[0].kind, &"edge")


func test_narrow_display_centred_above_is_an_edge() -> void:
	var lower := {"id": 1, "name": "Wide", "main": true,
		"rect_px": Rect2(0, 2160, 6880, 720), "frame_px": Rect2(0, 1000, 6880, 1880)}
	var upper := {"id": 2, "name": "Small", "main": false,
		"rect_px": Rect2(1000, 280, 3024, 720), "frame_px": Rect2(1000, -964, 3024, 1964)}
	var w = Walkway.build([lower, upper], 2.0)
	assert_eq(w.links[0].kind, &"edge")


func test_upper_flush_with_one_edge_gives_one_side() -> void:
	var lower := {"id": 1, "name": "Built-in", "main": true,
		"rect_px": Rect2(0, 3404, 3024, 720), "frame_px": Rect2(0, 2160, 3024, 1964)}
	var upper := {"id": 2, "name": "HP", "main": false,
		"rect_px": Rect2(1024, 1440, 2000, 720), "frame_px": Rect2(1024, 0, 2000, 2160)}
	var w = Walkway.build([lower, upper], 2.0)
	var link = w.links[0]
	assert_eq(link.kind, &"climb")
	assert_eq(link.sides.size(), 1)
	assert_eq(link.sides[0].dir, 1, "the right edges line up; the left edge has nothing above")


func test_three_displays_with_one_stacked_pair() -> void:
	var right := {"id": 3, "name": "Right", "main": false,
		"rect_px": Rect2(3482, 3404, 3024, 720), "frame_px": Rect2(3482, 2160, 3024, 1964)}
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP, right], 2.0)
	assert_eq(w.links[0].kind, &"climb")
	assert_eq(w.links[1].kind, &"edge", "built-in and Right stand side by side")


func test_no_frames_means_edges() -> void:
	var w = Walkway.build([BUILTIN, WIDE], 2.0)
	assert_eq(w.links[0].kind, &"edge")


func test_route_up_takes_the_nearer_side() -> void:
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP], 2.0)
	var half := 30.0
	# Near the built-in's right edge, home spot in the middle of the HP.
	var step: Dictionary = w.next_step(1, 3300.0, 0, 960.0, half)
	assert_eq(step.kind, &"walk")
	assert_eq(step.x, 3432.0 - half, "to the foot of the right edge")
	assert_eq(step.side.dir, 1)
	step = w.next_step(1, 3432.0 - half, 0, 960.0, half, step.side)
	assert_eq(step.kind, &"climb")
	# Near the left edge.
	step = w.next_step(1, 2000.0, 0, 960.0, half)
	assert_eq(step.side.dir, -1)
	assert_eq(step.x, 1920.0 + half)


func test_route_down_walks_to_the_top_of_the_edge() -> void:
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP], 2.0)
	var step: Dictionary = w.next_step(0, 1600.0, 1, 3300.0, 30.0)
	assert_eq(step.side.dir, 1)
	assert_eq(step.x, 1741.0 - 30.0, "above the built-in's right edge, on the HP")


func test_kept_side_wins() -> void:
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP], 2.0)
	var left = w.links[0].sides[1]
	var step: Dictionary = w.next_step(1, 3300.0, 0, 960.0, 30.0, left)
	assert_eq(step.side, left, "no turning around halfway")


func test_route_over_edges_walks_straight() -> void:
	var w = Walkway.build([BUILTIN, WIDE], 2.0)
	var step: Dictionary = w.next_step(0, 100.0, 1, 3000.0, 30.0)
	assert_eq(step.kind, &"walk")
	assert_eq(step.x, 3000.0)


func test_exit_stays_on_own_side_of_a_climb() -> void:
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP], 2.0)
	assert_eq(w.exit_x(1800.0, 30.0, 4.0), 1920.0 + 34.0, "HP's right end, not across the built-in")
	assert_eq(w.exit_x(100.0, 30.0, 4.0), -34.0)
	assert_eq(w.exit_x(3000.0, 30.0, 4.0), 3432.0 + 34.0)
	var flat = Walkway.build([BUILTIN, WIDE], 2.0)
	assert_eq(flat.exit_x(1000.0, 30.0, 4.0), -34.0, "as before without climb links")


func test_across_maps_the_top_of_the_lower_display_to_the_upper_strip() -> void:
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP], 2.0)
	var link = w.links[0]
	var p: Vector2 = w.across(1, 0, Vector2(3400.0, link.top_y))
	assert_eq(p, Vector2(1709.0, 360.0), "the bottom edge of the HP strip, above the same desk x")
	assert_eq(w.across(0, 1, p), Vector2(3400.0, link.top_y), "and back")


func test_over_the_seam_upwards_and_back() -> void:
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP], 2.0)
	var stay: Dictionary = w.over_seam(1, Vector2(2500.0, -600.0), 30.0, 360.0)
	assert_eq(stay.strip, 1, "still below the built-in's top edge")
	var up: Dictionary = w.over_seam(1, Vector2(2500.0, -630.0), 30.0, 360.0)
	assert_eq(up.strip, 0, "over the top: on the HP")
	assert_eq(up.point, Vector2(809.0, 352.0))
	var down: Dictionary = w.over_seam(0, Vector2(809.0, 370.0), 30.0, 360.0)
	assert_eq(down.strip, 1, "below the HP strip: back on the built-in")
	var aside: Dictionary = w.over_seam(0, Vector2(100.0, 370.0), 30.0, 360.0)
	assert_eq(aside.strip, 0, "nothing below the part of the HP that sticks out")


func test_open_above() -> void:
	var w = Walkway.build([BUILTIN_BELOW, HP_TOP], 2.0)
	assert_true(w.open_above(1, 2500.0, 30.0), "the HP stands on the built-in")
	assert_false(w.open_above(0, 900.0, 30.0), "nothing on top of the HP")
	var flat = Walkway.build([BUILTIN, WIDE], 2.0)
	assert_false(flat.open_above(0, 500.0, 30.0))
