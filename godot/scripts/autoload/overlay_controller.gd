extends Node
## `Overlay` autoload (OverlayController): a transparent, click-through strip
## window at the bottom of every display, forming one walkway in points
## (overlay-window D1-D5, multi-display D1-D5).
##
## Coordinates: content works in walkway points. x runs along all strips, left
## to right; y is measured from the top of a strip (same on every display).
## Each strip i has a window whose local pixels are walkway points scaled by
## points_to_px(1), offset by the strip's walkway start.
##
## Responsibilities: keeps one strip window per display in step with the
## displays (layout, visibility, native window level); converts between walkway
## points and window pixels; chooses the home display; follows the auto-hidden
## Dock through DockTracker (dock-dodge); grows the strips while a buddy is carried (headroom,
## buddy-drag D6); keeps the interactive regions and lets every other click
## through; routes mouse buttons in regions and hands focus back after a click;
## gives keyboard focus on request. The public API is every function, property
## and signal without a leading underscore.

signal layout_changed(old_walkway: Variant)
signal content_visibility_changed(visible: bool)
## A mouse button event inside a registered region (point in walkway points).
signal region_input(id: StringName, event: InputEventMouseButton, point: Vector2)
## All mouse buttons went up after a press in region `id` (buddy-drag D1), also
## when the release happened outside our windows. `point` is the pointer in walkway points.
signal region_released(id: StringName, point: Vector2)
## The buddies' home display changed (multi-display D6); `index` is its strip.
signal home_changed(index: int)
## The auto-hidden Dock was shown on strip `strip`, or hidden (-1) (dock-dodge D3).
signal dock_changed(strip: int)

const RegionRegistry := preload("res://scripts/core/region_registry.gd")
const FocusTracker := preload("res://scripts/core/focus_tracker.gd")
const Displays := preload("res://scripts/core/displays.gd")
const HomeDisplay := preload("res://scripts/core/home_display.gd")
const DockTracker := preload("res://scripts/overlay/dock_tracker.gd")
const DockWatch := preload("res://scripts/core/dock_watch.gd")
const TrailerMode := preload("res://scripts/core/trailer_mode.gd")

## Strip height in points (overlay-window design D1).
const STRIP_HEIGHT_PT := 360
const LAYOUT_POLL_SEC := 1.0
const NATIVE_CLASS := "MacOverlay"
## A tiny triangle outside the window: as the pass-through polygon it lets every
## click through, since no point of the window is inside it.
const _PASS_ALL_POLYGON := [Vector2(-4, -4), Vector2(-3, -4), Vector2(-3, -3)]
## A strip window without visible content is hidden after this long (multi-display D10).
const HIDE_EMPTY_AFTER_SEC := 1.0
## Headroom (buddy-drag D6): strips stay grown this long after the last carry ends,
## and window rects are re-checked this long after each grow or shrink (buddy-drag spike S1).
const HEADROOM_LINGER_SEC := 0.3
const RECT_CHECK_SEC := 1.0


## One display's strip: its window, stage for content, and last pass-through.
class Strip:
	extends RefCounted
	var id: int
	var name: String
	var main: bool
	var rect_px: Rect2i # global px (DisplayServer space), without headroom
	var room_px := 0 # px between the usable area's top and the strip's top (buddy-drag D6)
	var window: Window # the root window for the main display, else a Window node
	var stage: Node2D # content views and debug drawing for this strip
	var ui: CanvasLayer # panels (the debug session panel) in this strip's window
	var applied := "" # last applied pass-through key ("" = none yet)
	var empty_for := 0.0 # seconds without visible content


var walkway := Walkway.build([], 1.0)
## False while the user has hidden the buddies via the menu bar.
var content_visible := true
## The MacOverlay GDExtension singleton, or null when the native build is missing.
var native: Object = null
## Fallback from overlay-window spike S2 (overlay-window D5): give focus back after a click.
## Always on in the app; a switch for checks from game_eval.
var restore_frontmost_on_click := true

var _strips: Array[Strip] = []
var _registry := RegionRegistry.new()
var _focus := FocusTracker.new()
var _poll_left := 0.0
var _hover_strip := -1 # strip the cursor is over, or -1
var _hover_target: StringName = &"" # region (or capture) the cursor is over, or &""
var _signature := ""
var _display_cache: Array = []
var _home := HomeDisplay.new()
var _home_id := -1
var _dock_tracker := DockTracker.new()
## The Dock's preferences as last read (dock-dodge D2), with defaults filled in.
var dock_prefs: Dictionary:
	get:
		return _dock_tracker.prefs
var _headroom_refs := 0
var _headroom_on := false
var _headroom_linger := -1.0
var _rect_check_left := 0.0


func _ready() -> void:
	if Instance.duplicate:
		# Another Wobbo runs; this one quits (standalone-app D6).
		set_process(false)
		set_process_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Process after content nodes, so pass-through uses this frame's regions.
	process_priority = 1000
	_init_native()
	_dock_tracker.native = native
	_update_layout(true)
	for i in _strips.size():
		var s := _strips[i]
		print("Overlay: strip %d '%s' (id %d%s) rect=%s walkway %.0f..%.0f pt" % [
			i, s.name, s.id, ", main" if s.main else "", s.rect_px, walkway.segments[i].start,
			walkway.segments[i].end()])
	set_content_visible(Settings.overlay_visible)
	Settings.changed.connect(_on_setting_changed)
	_dock_tracker.read_prefs(LAYOUT_POLL_SEC, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready() and not Instance.duplicate:
		_update_layout()
		_dock_tracker.read_prefs(LAYOUT_POLL_SEC, true)


func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = LAYOUT_POLL_SEC
		_update_layout()
		_ensure_native_windows()
		_dock_tracker.read_prefs(LAYOUT_POLL_SEC)
	_update_dock(delta)
	_update_home()
	_update_strip_visibility(delta)
	_update_headroom(delta)
	if _registry.is_capturing() and DisplayServer.mouse_get_button_state() == 0:
		# Safety net: the button-up happened outside our windows and never reached us.
		_on_click_released(_registry.release())
	_update_passthrough()


# --- Geometry ---------------------------------------------------------------

## Pixels per point in every strip window (Godot's global scale, multi-display D4).
func points_to_px(points: float) -> float:
	return points * walkway.px_per_pt


func strip_height_pt() -> float:
	return STRIP_HEIGHT_PT


func strip_count() -> int:
	return _strips.size()


func strip_window(i: int) -> Window:
	return _strips[i].window


func strip_stage(i: int) -> Node2D:
	return _strips[i].stage


## A CanvasLayer in strip i's window for UI that should sit on that display.
func strip_ui(i: int) -> CanvasLayer:
	return _strips[i].ui


## The strip's window rect in global px (DisplayServer space).
func strip_rect_px(i: int) -> Rect2i:
	return _strips[i].rect_px


## Index of the main display's strip (the root window).
func root_strip() -> int:
	for i in _strips.size():
		if _strips[i].window == get_window():
			return i
	return 0


func strip_index_of_window(window: Window) -> int:
	for i in _strips.size():
		if _strips[i].window == window:
			return i
	return -1


func walkway_to_local(i: int, point: Vector2) -> Vector2:
	return Vector2(point.x - walkway.segments[i].start, point.y) * walkway.px_per_pt


func local_to_walkway(i: int, px: Vector2) -> Vector2:
	var p: Vector2 = px / walkway.px_per_pt
	return Vector2(p.x + walkway.segments[i].start, p.y)


func local_rect_to_walkway(i: int, rect: Rect2) -> Rect2:
	return Rect2(local_to_walkway(i, rect.position), rect.size / walkway.px_per_pt)


## Strips whose span overlaps `rect` (walkway points) horizontally.
func strips_overlapping(rect: Rect2) -> Array[int]:
	return walkway.indices_overlapping(rect)


## Display under the mouse pointer (its id), or -1.
func display_under_pointer() -> int:
	var mouse := DisplayServer.mouse_get_position()
	for d in _display_cache:
		if d.screen >= 0 and _screen_rect_px(d.screen).has_point(mouse):
			return d.id
	return -1


## The whole of Godot screen `screen` in global px (DisplayServer space).
func _screen_rect_px(screen: int) -> Rect2i:
	return Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))


## Connected displays as last seen by the layout poll: [{id, name, main, scale, screen}].
func displays() -> Array:
	return _display_cache


# --- The auto-hidden Dock (dock-dodge D2, D3); the tracking is in DockTracker ---

## How far content on strip `i` must rise to stand on top of the shown Dock, in
## points; 0 while the Dock is hidden or shown on another display. With `left`
## and `right` (walkway x), also 0 when that stretch is not over the Dock.
func dock_lift_pt(i: int, left := NAN, right := NAN) -> float:
	if i < 0 or i >= _strips.size():
		return 0.0
	var seg := walkway.segments[i]
	if not is_nan(left) and seg.width > 0.0 and not DockWatch.overlaps(_dock_tracker.span(),
			(left - seg.start) / seg.width, (right - seg.start) / seg.width):
		return 0.0
	return _dock_tracker.lift_pt(seg.id, _strips[i].rect_px, _dock_displays(), walkway.px_per_pt)


## Debug, for checks from game_eval and the trailer's pretend Dock: pretend the
## Dock is shown on display `id` (-1: hidden); -2 follows the Dock again. `span`:
## its left and right edge as fractions of the display's width (default: all of it).
func debug_force_dock(id: int, span := DockWatch.FULL_SPAN) -> void:
	_dock_tracker.forced = id
	_dock_tracker.forced_span = span


func _update_dock(delta: float) -> void:
	if not _dock_tracker.update(_dock_displays(), walkway.px_per_pt, delta):
		return
	var id := _dock_tracker.shown_id()
	var strip: int = walkway.index_of(id) if id >= 0 else -1
	print("Overlay: Dock %s" % ("hidden" if strip < 0 else "shown on strip %d (lift %.0f pt)" % [strip, dock_lift_pt(strip)]))
	dock_changed.emit(strip)


## The displays as DockTracker takes them: id, the native frame when known, and
## the screen's current rect when Godot has the screen.
func _dock_displays() -> Array:
	var out := []
	for d in _display_cache:
		var entry := {"id": d.id}
		if d.has("frame_pt"):
			entry.frame_pt = d.frame_pt
		if d.screen >= 0:
			entry.rect_px = _screen_rect_px(d.screen)
		out.append(entry)
	return out


# --- Home display (multi-display D6) ----------------------------------------

## Strip index of the home display.
func home_index() -> int:
	var i: int = walkway.index_of(_home_id)
	return i if i >= 0 else walkway.main_index()


func _update_home() -> void:
	if walkway.is_empty():
		return
	var ids: Array = walkway.segments.map(func(s) -> int: return s.id)
	var main_id: int = walkway.segments[walkway.main_index()].id
	var id := _home.update(Settings.screen, ids, main_id,
		display_under_pointer(), Time.get_ticks_msec() / 1000.0)
	if id != _home_id:
		_home_id = id
		home_changed.emit(home_index())


# --- Layout (overlay-window D2, multi-display D1/D2) ---------------------------

func _displays() -> Array:
	var rects := []
	for i in DisplayServer.get_screen_count():
		rects.append(Rect2(_screen_rect_px(i)))
	if native:
		return Displays.match(native.get_displays(), rects, DisplayServer.screen_get_max_scale())
	var list := []
	for i in rects.size():
		list.append({"id": i + 1, "name": "Display %d" % (i + 1), "main": i == DisplayServer.get_primary_screen(),
			"scale": DisplayServer.screen_get_scale(i), "screen": i})
	return list


func _strip_rect(screen: int, px_per_pt: float) -> Rect2i:
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var height := mini(int(round(STRIP_HEIGHT_PT * px_per_pt)), usable.size.y)
	return Rect2i(usable.position.x, usable.end.y - height, usable.size.x, height)


func _update_layout(force := false) -> void:
	var px_per_pt := DisplayServer.screen_get_max_scale()
	var wanted := []
	_display_cache = _displays()
	for d in _display_cache:
		if d.screen < 0:
			continue
		if not d.main and TrailerMode.active():
			continue # the trailer is recorded on the main display only
		wanted.append({"id": d.id, "name": d.name, "main": d.main, "rect_px": Rect2(_strip_rect(d.screen, px_per_pt))})
	var signature := var_to_str(wanted) + str(px_per_pt)
	if not force and signature == _signature:
		return
	_signature = signature
	var old_walkway := walkway
	walkway = Walkway.build(wanted, px_per_pt)
	_sync_strips()
	_hover_strip = -1
	_hover_target = &""
	layout_changed.emit(old_walkway)
	_update_home()


## Creates, moves and removes strip windows to match `walkway` (one per segment,
## in walkway order). The main display keeps the root window.
func _sync_strips() -> void:
	var by_id := {}
	for s in _strips:
		by_id[s.id] = s
	var next: Array[Strip] = []
	for seg in walkway.segments:
		var s: Strip = by_id.get(seg.id)
		if s == null:
			s = Strip.new()
			s.id = seg.id
		by_id.erase(seg.id)
		s.name = seg.name
		s.main = seg.main
		s.rect_px = Rect2i(seg.rect_px)
		s.room_px = _room_px(s)
		var want_root: bool = seg.main
		if want_root and s.window != get_window():
			_free_window(s)
			s.window = get_window()
		elif not want_root and (s.window == null or s.window == get_window()):
			s.window = _new_strip_window(s.name)
		if s.stage == null or not is_instance_valid(s.stage) or s.stage.get_parent() != _stage_parent(s.window):
			if s.stage and is_instance_valid(s.stage):
				s.stage.queue_free()
			s.stage = Node2D.new()
			s.stage.name = "Stage_%d" % s.id
			_stage_parent(s.window).add_child(s.stage)
		if s.ui == null or not is_instance_valid(s.ui) or s.ui.get_parent() != _stage_parent(s.window):
			if s.ui and is_instance_valid(s.ui):
				for child in s.ui.get_children():
					s.ui.remove_child(child) # moved to the home strip by their owner
				s.ui.queue_free()
			s.ui = CanvasLayer.new()
			s.ui.name = "UI_%d" % s.id
			s.ui.layer = 10
			_stage_parent(s.window).add_child(s.ui)
		_place_window(s)
		s.applied = ""
		next.append(s)
	for s: Strip in by_id.values():
		_free_window(s)
		if s.stage and is_instance_valid(s.stage):
			s.stage.queue_free()
		if s.ui and is_instance_valid(s.ui):
			s.ui.queue_free()
	_strips = next
	_ensure_native_windows()


## Hides strip windows (other than the root) that show nothing, so they cost no
## rendering, and shows them again as soon as content appears (multi-display D10).
func _update_strip_visibility(delta: float) -> void:
	for s in _strips:
		if s.window == get_window() or s.window == null or not is_instance_valid(s.window):
			continue
		var has_content := false
		for child in s.stage.get_children() + s.ui.get_children():
			if child is CanvasItem and (child as CanvasItem).visible:
				has_content = true
				break
		if has_content:
			s.empty_for = 0.0
			if not s.window.visible:
				s.window.show()
				s.applied = ""
				if native:
					native.configure_window(_handle_of(s.window))
		else:
			s.empty_for += delta
			if s.window.visible and s.empty_for >= HIDE_EMPTY_AFTER_SEC:
				s.window.hide()


func _stage_parent(window: Window) -> Node:
	return self if window == get_window() else window


func _new_strip_window(display_name: String) -> Window:
	var w := Window.new()
	w.title = "Wobbo (%s)" % display_name
	w.borderless = true
	w.transparent = true
	w.transparent_bg = true
	w.always_on_top = true
	w.unfocusable = true
	w.unresizable = true
	w.wrap_controls = false
	w.window_input.connect(_on_window_input.bind(w))
	add_child(w)
	return w


func _free_window(s: Strip) -> void:
	if s.window and s.window != get_window() and is_instance_valid(s.window):
		s.window.queue_free()
	s.window = null


func _place_window(s: Strip, show := true) -> void:
	var rect := _window_rect(s)
	if s.window == get_window():
		DisplayServer.window_set_position(rect.position)
		DisplayServer.window_set_size(rect.size)
	else:
		s.window.position = rect.position
		s.window.size = rect.size
		if show:
			s.window.show()
	# Content keeps its place on screen: everything moves down by the headroom (buddy-drag D6).
	var head := _head_px(s)
	s.window.canvas_transform = Transform2D(0.0, Vector2(0.0, head))
	if s.ui and is_instance_valid(s.ui):
		s.ui.offset = Vector2(0.0, head)
	if native and s.window.visible:
		native.configure_window(_handle_of(s.window)) # a resize resets the level (buddy-drag spike S1)


# --- Headroom while a buddy is carried (buddy-drag D6) -----------------------

## Grows every strip window up to the top of its display's usable area, until the
## matching end_headroom(). Content stays where it is on screen; walkway y < 0
## then lies in the grown part. Reference counted.
func begin_headroom() -> void:
	_headroom_refs += 1
	_headroom_linger = -1.0
	if not _headroom_on:
		_set_headroom(true)


func end_headroom() -> void:
	if _headroom_refs <= 0:
		return
	_headroom_refs -= 1
	if _headroom_refs == 0:
		_headroom_linger = HEADROOM_LINGER_SEC


func headroom_active() -> bool:
	return _headroom_on


## Room above strip i up to the top of the usable area, in points (also while
## the strips are not grown): the highest a carried body may go is -headroom_pt(i).
func headroom_pt(i: int) -> float:
	if i < 0 or i >= _strips.size():
		return 0.0
	return _strips[i].room_px / walkway.px_per_pt


## The strip window's current rect in global px (grown while headroom is on).
func strip_window_rect_px(i: int) -> Rect2i:
	return _window_rect(_strips[i])


## The pointer in walkway points, on the strip under it or else the strip whose
## columns contain it (y < 0 above the strip top).
func pointer_pt() -> Vector2:
	var mouse := DisplayServer.mouse_get_position()
	if _strips.is_empty():
		return Vector2(mouse)
	var best := 0
	for i in _strips.size():
		var r := _window_rect(_strips[i])
		if r.has_point(mouse):
			best = i
			break
		if mouse.x >= r.position.x and mouse.x < r.end.x:
			best = i
	return local_to_walkway(best, Vector2(mouse - _strips[best].rect_px.position))


func _set_headroom(on: bool) -> void:
	_headroom_on = on
	for s in _strips:
		_place_window(s, false)
		s.applied = ""
	_rect_check_left = RECT_CHECK_SEC
	print("Overlay: headroom %s" % ("on" if on else "off"))


func _update_headroom(delta: float) -> void:
	if _headroom_linger >= 0.0:
		_headroom_linger -= delta
		if _headroom_linger < 0.0 and _headroom_refs == 0 and _headroom_on:
			_set_headroom(false)
	if _rect_check_left <= 0.0:
		return
	_rect_check_left -= delta
	# macOS sometimes keeps an old size when size and position change in one frame (buddy-drag spike S1).
	for s in _strips:
		var want := _window_rect(s)
		var have: Rect2i
		if s.window == get_window():
			have = Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		elif s.window and is_instance_valid(s.window) and s.window.visible:
			var wid := s.window.get_window_id()
			have = Rect2i(DisplayServer.window_get_position(wid), DisplayServer.window_get_size(wid))
		else:
			continue
		if have != want:
			_place_window(s, false)


func _window_rect(s: Strip) -> Rect2i:
	if not _headroom_on:
		return s.rect_px
	return Rect2i(s.rect_px.position.x, s.rect_px.position.y - s.room_px, s.rect_px.size.x,
		s.rect_px.size.y + s.room_px)


## How far the window reaches above the strip, in px (0 without headroom).
func _head_px(s: Strip) -> int:
	return s.room_px if _headroom_on else 0


func _room_px(s: Strip) -> int:
	for d in _display_cache:
		if d.id == s.id and d.screen >= 0:
			return maxi(0, s.rect_px.position.y - DisplayServer.screen_get_usable_rect(d.screen).position.y)
	return 0


# --- Regions and pass-through (overlay-window D3, multi-display D5) -----------

## Registers an interactive region, in walkway points.
func set_region(id: StringName, rect: Rect2) -> void:
	if content_visible:
		_registry.set_region(id, rect)


func remove_region(id: StringName) -> void:
	_registry.remove_region(id)


func get_regions() -> Dictionary:
	return _registry.get_regions()


func _strip_under_mouse() -> int:
	var mouse := DisplayServer.mouse_get_position()
	for i in _strips.size():
		if _window_rect(_strips[i]).has_point(mouse):
			return i
	return -1


func _update_passthrough() -> void:
	var hover_strip := -1
	var target: StringName = &""
	if content_visible:
		hover_strip = _strip_under_mouse()
		if hover_strip >= 0 or _registry.is_capturing():
			var i := hover_strip if hover_strip >= 0 else maxi(_hover_strip, 0)
			var point := local_to_walkway(i, Vector2(DisplayServer.mouse_get_position() - _strips[i].rect_px.position))
			target = _registry.passthrough_target(point)
			if _registry.is_capturing() and hover_strip < 0:
				hover_strip = i
	if target != &"" and target != _hover_target and restore_frontmost_on_click and native \
			and not _focus.has_requests():
		# Entering a region: remember who is frontmost before a click could activate us.
		native.remember_frontmost_app()
	_hover_strip = hover_strip
	_hover_target = target
	for i in _strips.size():
		var s := _strips[i]
		var rect := Rect2()
		var outside := true
		if i == hover_strip and target == RegionRegistry.CAPTURE:
			rect = Rect2(Vector2.ZERO, Vector2(_window_rect(s).size))
			outside = false
		elif i == hover_strip and target != &"":
			var r: Rect2 = _registry.get_region(target)
			rect = Rect2(walkway_to_local(i, r.position) + Vector2(0.0, _head_px(s)), r.size * walkway.px_per_pt)
			outside = false
		var key := "outside" if outside else str(rect)
		if key == s.applied:
			continue
		s.applied = key
		var polygon := PackedVector2Array(_PASS_ALL_POLYGON) if outside else PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		if s.window == get_window():
			DisplayServer.window_set_mouse_passthrough(polygon)
		else:
			s.window.mouse_passthrough_polygon = polygon


func _input(event: InputEvent) -> void:
	_handle_mouse(event, root_strip())


func _on_window_input(event: InputEvent, window: Window) -> void:
	_handle_mouse(event, strip_index_of_window(window))


func _handle_mouse(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or i < 0 or i >= _strips.size():
		return
	var point := local_to_walkway(i, mb.position - Vector2(0.0, _head_px(_strips[i])))
	if mb.pressed and not _registry.is_capturing():
		var id := _registry.press(point)
		if id != &"":
			region_input.emit(id, mb, point)
			if restore_frontmost_on_click and native and not _focus.has_requests():
				native.remember_frontmost_app() # no-op if we are already frontmost
				# macOS activates us on mouse-down; hand focus back at the end of
				# this frame, so the focus flicker lasts one frame (overlay-window S2).
				_restore_after_click.call_deferred()
	elif not mb.pressed and mb.button_mask == 0:
		_on_click_released(_registry.release())
	_update_passthrough()


func _restore_after_click(only_if_active := false) -> void:
	# Deferred: a click may have opened something that requested focus meanwhile.
	if not restore_frontmost_on_click or native == null or _focus.has_requests():
		return
	if only_if_active and not native.is_app_active():
		return
	native.restore_frontmost_app()


func _on_click_released(region_id: StringName) -> void:
	# Safety net in case we became active again during the click or drag.
	if region_id != &"":
		_restore_after_click(true)
		region_released.emit(region_id, pointer_pt())


# --- Visibility (menu-bar-control) -----------------------------------------

func set_content_visible(visible: bool) -> void:
	content_visible = visible
	if not visible:
		_registry.clear()
	for s in _strips:
		s.applied = ""
	_update_passthrough()
	content_visibility_changed.emit(visible)


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"overlay_visible":
		set_content_visible(value)


# --- Keyboard focus (overlay-window D5) --------------------------------------

## Gives the overlay keyboard focus until the matching release. Reference
## counted per owner. A Control owner also gets grab_focus() in its own window.
func request_keyboard_focus(owner: Object) -> void:
	var window := _window_of(owner)
	if _focus.request(owner.get_instance_id()):
		if native:
			native.remember_frontmost_app()
		_set_focusable(window, true)
		if native:
			native.activate_window(_handle_of(window))
		else:
			DisplayServer.window_move_to_foreground(window.get_window_id())
	if owner is Control:
		(owner as Control).grab_focus()


func release_keyboard_focus(owner: Object) -> void:
	if _focus.release(owner.get_instance_id()):
		_hand_focus_back(_window_of(owner))


## Drops every request of `owner`, e.g. when it is freed.
func release_all_keyboard_focus(owner: Object) -> void:
	if _focus.release_all(owner.get_instance_id()):
		_hand_focus_back(_window_of(owner))


func _window_of(owner: Object) -> Window:
	return (owner as Node).get_window() if owner is Node and (owner as Node).is_inside_tree() else get_window()


func _set_focusable(window: Window, focusable: bool) -> void:
	if window == get_window():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, not focusable)
	else:
		window.unfocusable = not focusable


func _hand_focus_back(window: Window) -> void:
	var focused := window.gui_get_focus_owner()
	if focused:
		focused.release_focus()
	_set_focusable(window, false)
	if native:
		native.restore_frontmost_app()


# --- Native GDExtension (overlay-window D4) ----------------------------------

func _init_native() -> void:
	if DisplayServer.get_name() == "headless":
		return # no window to configure
	if Engine.has_singleton(NATIVE_CLASS):
		native = Engine.get_singleton(NATIVE_CLASS)
	elif ClassDB.class_exists(NATIVE_CLASS):
		native = ClassDB.instantiate(NATIVE_CLASS)
	if native == null:
		push_warning("Overlay: %s GDExtension not found; running without Spaces, fullscreen and accessory-app behaviour." % NATIVE_CLASS)
		return
	native.set_accessory_app()
	native.configure_window(_handle_of(get_window()))
	print("Overlay: %s active, window level %d." % [NATIVE_CLASS, native.get_window_level_of(_handle_of(get_window()))])


## Godot resets the window level on some window changes, so re-apply the native
## configuration after layout changes and on every poll (cheap when unchanged).
func _ensure_native_windows() -> void:
	if native == null:
		return
	for s in _strips:
		# A hidden Window has no native window (Godot destroys it); it is
		# configured again when it is shown (_update_strip_visibility).
		if s.window and is_instance_valid(s.window) and s.window.visible \
				and native.configure_window(_handle_of(s.window)):
			print_verbose("Overlay: native configuration re-applied for strip %d." % s.id)


func _handle_of(window: Window) -> int:
	return DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, window.get_window_id())
