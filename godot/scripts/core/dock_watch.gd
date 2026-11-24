extends RefCounted
## Whether the auto-hidden Dock is shown, and on which display (dock-dodge
## design D1). Pure: Dock preferences, displays, the Dock's frame or the
## pointer, and time are passed in.
##
## update_frame(): from the Dock's real frame (Accessibility API). The Dock
## counts as shown while it is in view and not sliding away.
## update(): fallback without Accessibility access, following the pointer: the
## Dock counts as shown on a display once the pointer has rested on its bottom
## edge for the show delay, and stays shown while the pointer stays within the
## Dock's height from that edge.

## Rows at the bottom of a display that count as its bottom edge.
const EDGE_PX := 2
## Space around the icons: the Dock's height is the icon size plus this (dock-dodge spike S2).
const DOCK_PADDING_PT := 20.0
## Show delay when `autohide-delay` is not set (dock-dodge spike S1).
const DEFAULT_SHOW_DELAY_SEC := 0.2
## A Dock with less than this in view counts as hidden.
const VISIBLE_MIN_PT := 1.0
## A shown Dock floats this far above the screen edge (measured: 10 pt on
## macOS 27); learned from the frame once seen, at most MAX_BOTTOM_MARGIN_PT.
const DEFAULT_BOTTOM_MARGIN_PT := 10.0
const MAX_BOTTOM_MARGIN_PT := 24.0
## The Dock's span when only its height is known: the whole display.
const FULL_SPAN := Vector2(0.0, 1.0)

const DEFAULT_PREFS := {
	"autohide": false,
	"orientation": "bottom",
	"tilesize": 48.0,
	"magnification": false,
	"largesize": 64.0,
	"show_delay_sec": DEFAULT_SHOW_DELAY_SEC,
}

## Height of the Dock's icon area as last seen by update_frame(), 0 before that.
var frame_height_pt := 0.0
## Gap between a fully shown Dock and the screen edge.
var bottom_margin_pt := DEFAULT_BOTTOM_MARGIN_PT
## Left and right edge of the shown Dock as fractions of its display's width,
## as last seen by update_frame(); (0, 1) when unknown (the pointer fallback).
var span := FULL_SPAN
var _shown := -1
var _prev_visible := 0.0
var _prev_display := -1
var _arming := -1
var _arming_since := 0.0


## `raw` with every missing or mistyped key replaced by its default.
static func with_defaults(raw: Dictionary) -> Dictionary:
	var out := DEFAULT_PREFS.duplicate()
	for key: String in DEFAULT_PREFS:
		if not raw.has(key):
			continue
		var v: Variant = raw[key]
		match [typeof(DEFAULT_PREFS[key]), typeof(v)]:
			[TYPE_BOOL, TYPE_BOOL], [TYPE_BOOL, TYPE_INT], [TYPE_BOOL, TYPE_FLOAT]:
				out[key] = bool(v)
			[TYPE_BOOL, TYPE_STRING]: # `defaults read` prints 1/0
				out[key] = String(v).strip_edges() in ["1", "true", "YES"]
			[TYPE_FLOAT, TYPE_INT], [TYPE_FLOAT, TYPE_FLOAT]:
				out[key] = float(v)
			[TYPE_FLOAT, TYPE_STRING]:
				if String(v).strip_edges().is_valid_float():
					out[key] = String(v).strip_edges().to_float()
			[TYPE_STRING, TYPE_STRING]:
				out[key] = String(v).strip_edges()
	return out


## The Dock's preferences in the output of `defaults read com.apple.dock`, used
## without the native build (dock-dodge D2): the top-level keys, renamed like
## MacOverlay.get_dock_prefs(), with their values as strings (see with_defaults()).
static func parse_defaults_output(text: String) -> Dictionary:
	var names := {"autohide": "autohide", "orientation": "orientation", "tilesize": "tilesize",
		"magnification": "magnification", "largesize": "largesize", "autohide-delay": "show_delay_sec"}
	# Top-level keys are indented by exactly four spaces; nested ones by more.
	var re := RegEx.create_from_string("^    \"?([\\w-]+)\"?\\s*=\\s*\"?([^\";]*)\"?;$")
	var prefs := {}
	for line in text.split("\n"):
		var m := re.search(line)
		if m and names.has(m.get_string(1)):
			prefs[names[m.get_string(1)]] = m.get_string(2)
	return prefs


## True when the Dock hides automatically at the bottom, the only case handled.
static func active(prefs: Dictionary) -> bool:
	return bool(prefs.get("autohide", false)) and String(prefs.get("orientation", "bottom")) == "bottom"


## The Dock's height in points, including magnified icons while hovering.
static func dock_height_pt(prefs: Dictionary) -> float:
	var icons := float(prefs.get("tilesize", DEFAULT_PREFS.tilesize))
	if bool(prefs.get("magnification", false)):
		icons = maxf(icons, float(prefs.get("largesize", DEFAULT_PREFS.largesize)))
	return icons + DOCK_PADDING_PT


## How far a fully shown Dock reaches above the screen edge, 0 when unknown.
func shown_height_pt() -> float:
	return frame_height_pt + bottom_margin_pt if frame_height_pt > 0.0 else 0.0


## Returns the id of the display the Dock is shown on, or -1, from the Dock's
## frame. `displays`: [{id: int, frame_pt: Rect2}] and `dock_frame`, both in
## points with a top-left origin; an empty `dock_frame` means unknown. A hidden
## Dock sits just below its display, a shown one has its top inside it.
func update_frame(prefs: Dictionary, displays: Array, dock_frame: Rect2) -> int:
	if not active(prefs) or dock_frame.size.y <= 0.0:
		_reset()
		return -1
	frame_height_pt = dock_frame.size.y
	var cx := dock_frame.get_center().x
	for d: Dictionary in displays:
		var f: Rect2 = d.frame_pt
		var visible := f.end.y - dock_frame.position.y
		if cx < f.position.x or cx >= f.end.x or visible < -1.0 \
				or visible > dock_frame.size.y + MAX_BOTTOM_MARGIN_PT:
			continue
		if visible > dock_frame.size.y:
			bottom_margin_pt = visible - dock_frame.size.y
		if f.size.x > 0.0:
			span = Vector2((dock_frame.position.x - f.position.x) / f.size.x,
				(dock_frame.end.x - f.position.x) / f.size.x)
		var receding: bool = d.id == _prev_display and visible < _prev_visible - 0.25
		_prev_visible = visible
		_prev_display = d.id
		_shown = d.id if visible >= VISIBLE_MIN_PT and not receding else -1
		return _shown
	_reset()
	return -1


## Returns the id of the display the Dock is shown on, or -1, from the pointer.
## `displays`: [{id: int, rect_px: Rect2i}] full screen rects in global px,
## `pointer_px`: global px, `px_per_pt`: pixels per point in that space.
func update(prefs: Dictionary, displays: Array, pointer_px: Vector2i, px_per_pt: float, now_sec: float) -> int:
	if not active(prefs):
		_reset()
		return -1
	var display := _display_at(displays, pointer_px)
	if display.is_empty():
		_reset()
		return -1
	var id: int = display.id
	var rect: Rect2i = display.rect_px
	var from_bottom := rect.end.y - 1 - pointer_px.y # 0 on the last row
	if _shown == id:
		if from_bottom <= dock_height_pt(prefs) * px_per_pt:
			return _shown
		_shown = -1
	elif _shown != -1:
		_shown = -1 # the pointer left the Dock's display
	if from_bottom < EDGE_PX:
		if _arming != id:
			_arming = id
			_arming_since = now_sec
		if now_sec - _arming_since >= float(prefs.get("show_delay_sec", DEFAULT_SHOW_DELAY_SEC)):
			_shown = id
			_arming = -1
	else:
		_arming = -1
	return _shown


## True when something from `left` to `right` (fractions of the display's
## width) is partly over a Dock spanning `dock_span` (see `span`).
static func overlaps(dock_span: Vector2, left: float, right: float) -> bool:
	return right > dock_span.x and left < dock_span.y


func _reset() -> void:
	_shown = -1
	span = FULL_SPAN
	_arming = -1
	_prev_visible = 0.0
	_prev_display = -1


## The display under `point`, counting the row just below it: macOS reports a
## pointer pushed against the bottom of the screen at y == bottom.
static func _display_at(displays: Array, point: Vector2i) -> Dictionary:
	for d: Dictionary in displays:
		var r := Rect2i(d.rect_px)
		if Rect2i(r.position, r.size + Vector2i(0, 1)).has_point(point):
			return d
	return {}
