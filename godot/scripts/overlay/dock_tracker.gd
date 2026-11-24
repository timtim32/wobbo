extends RefCounted
## Follows the auto-hidden Dock for OverlayController (dock-dodge D1-D3): whether
## it is shown, on which display, and how high it reaches. Not pure: it reads the
## Dock's preferences and frame through MacOverlay (or `defaults read` without the
## native build) and the pointer through DisplayServer. The decisions themselves
## are made by the pure DockWatch.
##
## `displays` arguments: [{id: int, frame_pt: Rect2 (native frame, points, when
## known), rect_px: Rect2i (the screen in global px, when Godot has it)}].

const DockWatch := preload("res://scripts/core/dock_watch.gd")

## Without the native build, the preferences come from `defaults read` this often (dock-dodge D2).
const PREFS_CLI_POLL_SEC := 5.0
## The Dock's frame is read every frame while the pointer is this close to a
## bottom edge or the Dock is shown, else this often (dock-dodge D1).
const NEAR_BOTTOM_PT := 160.0
const IDLE_POLL_SEC := 0.25

## The MacOverlay GDExtension singleton, or null when the native build is missing.
var native: Object = null
## The Dock's preferences as last read (dock-dodge D2), with defaults filled in.
var prefs: Dictionary = DockWatch.with_defaults({})
## Debug override for checks from game_eval: the display id the Dock counts as
## shown on (-1: hidden), or -2 to follow the Dock.
var forced := -2
## Left and right edge of the forced Dock as fractions of the display's width.
var forced_span := DockWatch.FULL_SPAN

var _watch := DockWatch.new()
var _shown_id := -1 # display id the Dock is shown on, or -1
var _cli_left := 0.0
var _ax := false # Accessibility access: the Dock's real frame is readable
var _prompted := false
var _poll_left := 0.0


## Display id the Dock is shown on, or -1.
func shown_id() -> int:
	return _shown_id


## Re-reads the preferences. Called on every layout poll (`poll_sec` apart), and
## with `now` when the app starts or comes to the front.
func read_prefs(poll_sec: float, now := false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if native and native.has_method("get_dock_prefs"):
		prefs = DockWatch.with_defaults(native.get_dock_prefs())
		var ax: bool = native.is_accessibility_trusted(false)
		if not ax and DockWatch.active(prefs) and not _prompted:
			_prompted = true # once per run: macOS shows its own dialog
			print("Overlay: asking for Accessibility access to see the Dock; following the pointer until then")
			native.is_accessibility_trusted(true)
		if ax != _ax:
			print("Overlay: Dock from %s" % ("its Accessibility frame" if ax else "the pointer"))
			_ax = ax
		return
	_cli_left -= poll_sec
	if not now and _cli_left > 0.0:
		return
	_cli_left = PREFS_CLI_POLL_SEC
	prefs = DockWatch.with_defaults(read_prefs_cli())


## Fallback without the native build (dock-dodge D2).
static func read_prefs_cli() -> Dictionary:
	var out := []
	if OS.execute("defaults", ["read", "com.apple.dock"], out) != 0 or out.is_empty():
		return {}
	return DockWatch.parse_defaults_output(String(out[0]))


## Follows the Dock for one frame. Returns true when the display it is shown on
## changed (see shown_id()).
func update(displays: Array, px_per_pt: float, delta: float) -> bool:
	var id := -1
	if forced != -2:
		id = forced
	elif _ax:
		if _shown_id < 0 and not _pointer_near_bottom(displays, px_per_pt):
			_poll_left -= delta
			if _poll_left > 0.0:
				return false
		_poll_left = IDLE_POLL_SEC
		var frames := displays.filter(func(d: Dictionary) -> bool: return d.has("frame_pt"))
		var frame: Rect2 = native.get_dock_frame() if DockWatch.active(prefs) else Rect2()
		id = _watch.update_frame(prefs, frames, frame)
	else: # also when inactive, so the watcher resets itself
		var rects := displays.filter(func(d: Dictionary) -> bool: return d.has("rect_px"))
		id = _watch.update(prefs, rects, DisplayServer.mouse_get_position(), px_per_pt,
			Time.get_ticks_msec() / 1000.0)
	if id == _shown_id:
		return false
	_shown_id = id
	return true


## How far content on a strip of display `display_id` must rise to stand on top
## of the shown Dock, in points; 0 while the Dock is hidden or on another
## display. `strip_rect_px`: the strip's rect without headroom.
func lift_pt(display_id: int, strip_rect_px: Rect2i, displays: Array, px_per_pt: float) -> float:
	if _shown_id < 0 or display_id != _shown_id:
		return 0.0
	var height := _watch.shown_height_pt() if _ax and _watch.frame_height_pt > 0.0 \
		else DockWatch.dock_height_pt(prefs)
	for d: Dictionary in displays:
		if d.id == _shown_id and d.has("rect_px"):
			var gap_pt: float = (d.rect_px.end.y - strip_rect_px.end.y) / px_per_pt
			return maxf(0.0, height - gap_pt)
	return 0.0


## Left and right edge of the shown Dock as fractions of its display's width;
## the whole display while only its height is known (without Accessibility).
func span() -> Vector2:
	if forced != -2:
		return forced_span
	return _watch.span if _ax else DockWatch.FULL_SPAN


func _pointer_near_bottom(displays: Array, px_per_pt: float) -> bool:
	var mouse := DisplayServer.mouse_get_position()
	for d: Dictionary in displays:
		if not d.has("rect_px"):
			continue
		var r: Rect2i = d.rect_px
		r.size.y += 1 # a pointer pushed against the bottom reports y == bottom
		if r.has_point(mouse) and r.end.y - mouse.y <= NEAR_BOTTOM_PT * px_per_pt:
			return true
	return false
