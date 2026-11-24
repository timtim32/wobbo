extends "res://tests/base_test.gd"
## Detecting the auto-hidden Dock from the pointer (dock-dodge D1).

const DockWatch := preload("res://scripts/core/dock_watch.gd")

## Two displays side by side, 2 px per point: A is 2000x1200, B is 1600x1000.
const A := 1
const B := 2
var displays := [
	{"id": A, "rect_px": Rect2i(0, 0, 2000, 1200)},
	{"id": B, "rect_px": Rect2i(2000, 0, 1600, 1000)},
]
var prefs := DockWatch.with_defaults({"autohide": true, "tilesize": 50, "show_delay_sec": 0.2})
var watch: DockWatch


func before_each() -> void:
	watch = DockWatch.new()


func _at(x: int, y: int, t: float, p := prefs) -> int:
	return watch.update(p, displays, Vector2i(x, y), 2.0, t)


func test_defaults() -> void:
	var p := DockWatch.with_defaults({"autohide": 1, "tilesize": 53, "orientation": 7})
	assert_eq(p.autohide, true)
	assert_eq(p.tilesize, 53.0)
	assert_eq(p.orientation, "bottom", "mistyped key")
	assert_eq(p.show_delay_sec, DockWatch.DEFAULT_SHOW_DELAY_SEC)
	assert_eq(DockWatch.with_defaults({"autohide": "1"}).autohide, true, "string from defaults read")


func test_height() -> void:
	assert_eq(DockWatch.dock_height_pt(prefs), 50.0 + DockWatch.DOCK_PADDING_PT)
	var mag := DockWatch.with_defaults({"tilesize": 50, "magnification": true, "largesize": 90})
	assert_eq(DockWatch.dock_height_pt(mag), 90.0 + DockWatch.DOCK_PADDING_PT)


func test_inactive_without_autohide_or_on_the_side() -> void:
	var off := DockWatch.with_defaults({"autohide": false})
	var left := DockWatch.with_defaults({"autohide": true, "orientation": "left"})
	for p in [off, left]:
		assert_eq(_at(1000, 1199, 0.0, p), -1)
		assert_eq(_at(1000, 1199, 5.0, p), -1)


func test_shown_after_the_delay() -> void:
	assert_eq(_at(1000, 1199, 0.0), -1)
	assert_eq(_at(1000, 1198, 0.1), -1, "still arming on the second edge row")
	assert_eq(_at(1000, 1199, 0.2), A)


func test_pointer_pushed_against_the_bottom() -> void:
	# macOS reports the pointer at y == bottom (1200), just outside the rect.
	assert_eq(_at(1000, 1200, 0.0), -1)
	assert_eq(_at(1000, 1200, 0.2), A)


func test_brief_touch() -> void:
	assert_eq(_at(1000, 1199, 0.0), -1)
	assert_eq(_at(1000, 1100, 0.1), -1)
	assert_eq(_at(1000, 1199, 0.15), -1, "the timer restarted")
	assert_eq(_at(1000, 1199, 0.3), -1)
	assert_eq(_at(1000, 1199, 0.4), A)


func test_stays_shown_within_the_dock() -> void:
	_at(1000, 1199, 0.0)
	_at(1000, 1199, 0.2)
	var top := 1199 - int((50.0 + DockWatch.DOCK_PADDING_PT) * 2.0)
	assert_eq(_at(400, top, 1.0), A, "top row of the Dock")
	assert_eq(_at(400, top - 1, 1.1), -1, "just above the Dock")
	assert_eq(_at(400, 1199, 1.2), -1, "back on the edge: arming again")


func test_magnified_dock_stays_shown() -> void:
	var mag := DockWatch.with_defaults({"autohide": true, "tilesize": 40, "magnification": true,
		"largesize": 100, "show_delay_sec": 0.0})
	assert_eq(_at(1000, 1199, 0.0, mag), A)
	assert_eq(_at(1000, 1199 - 200, 0.5, mag), A, "within the magnified height")


func test_other_display() -> void:
	_at(1000, 1199, 0.0)
	assert_eq(_at(1000, 1199, 0.2), A)
	assert_eq(_at(2500, 990, 0.3), -1, "moved to B, inside B's Dock height")
	assert_eq(_at(2500, 999, 0.4), -1)
	assert_eq(_at(2500, 999, 0.7), B, "B's bottom edge shows it there")


func test_pointer_outside_every_display() -> void:
	_at(1000, 1199, 0.0)
	_at(1000, 1199, 0.2)
	assert_eq(_at(3000, 1100, 0.3), -1, "below B, outside every display")


# --- From the Dock's real frame (Accessibility) --------------------------------

## The same two displays in points (top-left origin): A 1000x600, B 800x500 to its right.
var frames := [
	{"id": A, "frame_pt": Rect2(0, 0, 1000, 600)},
	{"id": B, "frame_pt": Rect2(1000, 0, 800, 500)},
]


func _dock(top: float, x := 150.0, w := 700.0, h := 73.0) -> Rect2:
	return Rect2(x, top, w, h)


func test_frame_hidden_below_the_display() -> void:
	assert_eq(watch.update_frame(prefs, frames, _dock(600.0)), -1)
	assert_eq(watch.frame_height_pt, 73.0)


func test_frame_slides_in_and_stays() -> void:
	assert_eq(watch.update_frame(prefs, frames, _dock(600.0)), -1)
	assert_eq(watch.update_frame(prefs, frames, _dock(590.0)), A, "shown as soon as it appears")
	assert_eq(watch.update_frame(prefs, frames, _dock(527.0)), A)
	assert_eq(watch.update_frame(prefs, frames, _dock(527.0)), A, "fully shown")


func test_frame_floating_above_the_edge() -> void:
	# Measured on macOS 27: hidden at the edge (982), fully shown with its top at
	# 899, so 83 pt in view for a 73 pt frame; sliding away passes 972.
	var mac := [{"id": A, "frame_pt": Rect2(0, 0, 1512, 982)}]
	assert_eq(watch.update_frame(prefs, mac, _dock(982.0)), -1, "hidden")
	assert_eq(watch.update_frame(prefs, mac, _dock(970.0)), A, "appearing")
	assert_eq(watch.update_frame(prefs, mac, _dock(899.0)), A, "fully shown")
	assert_eq(watch.update_frame(prefs, mac, _dock(899.0)), A, "stays shown")
	assert_eq(watch.shown_height_pt(), 83.0)
	assert_eq(watch.update_frame(prefs, mac, _dock(972.0)), -1, "sliding away")
	assert_eq(watch.update_frame(prefs, mac, _dock(982.0)), -1, "hidden again")


func test_frame_sliding_away_counts_as_hidden() -> void:
	watch.update_frame(prefs, frames, _dock(527.0))
	assert_eq(watch.update_frame(prefs, frames, _dock(540.0)), -1, "sliding down")
	assert_eq(watch.update_frame(prefs, frames, _dock(580.0)), -1)
	assert_eq(watch.update_frame(prefs, frames, _dock(560.0)), A, "coming back up")


func test_frame_on_the_other_display() -> void:
	assert_eq(watch.update_frame(prefs, frames, _dock(440.0, 1100.0, 600.0, 73.0)), B)


func test_frame_ignored_without_autohide() -> void:
	var off := DockWatch.with_defaults({"autohide": false})
	assert_eq(watch.update_frame(off, frames, _dock(527.0)), -1, "an always-visible Dock")


func test_frame_unknown() -> void:
	watch.update_frame(prefs, frames, _dock(527.0))
	assert_eq(watch.update_frame(prefs, frames, Rect2()), -1)


func test_frame_stacked_displays() -> void:
	# C below A: a hidden Dock on A has its top on C's top edge, which is not "shown on C".
	var stacked := [
		{"id": A, "frame_pt": Rect2(0, 0, 1000, 600)},
		{"id": 3, "frame_pt": Rect2(0, 600, 1000, 600)},
	]
	assert_eq(watch.update_frame(prefs, stacked, _dock(600.0)), -1)
	assert_eq(watch.update_frame(prefs, stacked, _dock(1150.0)), 3, "shown on C")


## Output of `defaults read com.apple.dock`, shortened; the nested tilesize must be ignored.
const DEFAULTS_SAMPLE := """{
    autohide = 1;
    "autohide-delay" = "0.1";
    largesize = 80;
    magnification = 0;
    orientation = bottom;
    "persistent-apps" =     (
                {
            "tile-data" =             {
                "file-label" = Safari;
                tilesize = 99;
            };
        }
    );
    tilesize = 53;
    "wvous-br-corner" = 14;
}"""


func test_defaults_output_reads_top_level_keys() -> void:
	assert_eq(DockWatch.parse_defaults_output(DEFAULTS_SAMPLE), {"autohide": "1", "show_delay_sec": "0.1",
		"largesize": "80", "magnification": "0", "orientation": "bottom", "tilesize": "53"})


func test_defaults_output_without_keys() -> void:
	assert_eq(DockWatch.parse_defaults_output("{\n    tilesize = 64;\n}"), {"tilesize": "64"}, "only what is there")
	assert_eq(DockWatch.parse_defaults_output(""), {}, "no output")


func test_defaults_output_through_with_defaults() -> void:
	var p := DockWatch.with_defaults(DockWatch.parse_defaults_output(DEFAULTS_SAMPLE))
	assert_eq(p.autohide, true)
	assert_eq(p.tilesize, 53.0)
	assert_eq(p.show_delay_sec, 0.1)
	assert_eq(p.magnification, false)


# --- The Dock's horizontal span (only buddies above it hop up) -----------------

func test_span_from_the_frame() -> void:
	assert_eq(watch.span, DockWatch.FULL_SPAN, "unknown before a frame")
	watch.update_frame(prefs, frames, _dock(527.0, 150.0, 700.0))
	assert_eq(watch.span, Vector2(0.15, 0.85), "fractions of A's width")
	watch.update_frame(prefs, frames, _dock(440.0, 1200.0, 400.0))
	assert_eq(watch.span, Vector2(0.25, 0.75), "fractions of B's width, from B's left edge")
	watch.update_frame(prefs, frames, Rect2())
	assert_eq(watch.span, DockWatch.FULL_SPAN, "unknown again")


func test_overlaps() -> void:
	var span := Vector2(0.3, 0.7)
	assert_true(DockWatch.overlaps(span, 0.4, 0.5), "fully above")
	assert_true(DockWatch.overlaps(span, 0.25, 0.35), "partly above, left end")
	assert_true(DockWatch.overlaps(span, 0.65, 0.75), "partly above, right end")
	assert_false(DockWatch.overlaps(span, 0.0, 0.1), "beside it, left")
	assert_false(DockWatch.overlaps(span, 0.9, 1.0), "beside it, right")
	assert_false(DockWatch.overlaps(span, 0.2, 0.3), "touching is not above")
	assert_true(DockWatch.overlaps(DockWatch.FULL_SPAN, 0.0, 0.05), "unknown span covers everything")
