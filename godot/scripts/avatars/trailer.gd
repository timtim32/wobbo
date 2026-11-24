extends Node
## Runs a trailer recording (TrailerMode, tools/record-trailer.sh). Pins the
## buddies to the main display, paints an opaque backdrop over its strip so the
## video shows nothing of the user's desktop, and plays Demo.TRAILER_STEPS. The
## real Dock is ignored; the show's "dock" cues slide in a pretend Dock with plain
## tiles instead (no real app icons), and the buddies above it jump onto it.
## Once every buddy has left, it ends on the title (trailer_title.gd).
##
## Handshake with the script through files in the trailer folder:
##   strip.json  Wobbo -> script: the strip to record, in pixels of the main display
##   go          script -> Wobbo: the recording runs, start the show
##   done        Wobbo -> script: the show is over, stop recording
##   quit        script -> Wobbo: recording stopped, quit (the backdrop stays until then)

const TrailerMode := preload("res://scripts/core/trailer_mode.gd")
const Demo := preload("res://scripts/avatars/demo_player.gd")
const TitleCard := preload("res://scripts/avatars/trailer_title.gd")

## Seconds to wait for the script's "go" or "quit" before giving up and quitting.
const WAIT_SEC := 60.0
## Seconds of empty backdrop after the last buddy has left.
const TAIL_SEC := 1.0
const SETTLE_SEC := 1.5
const DEFAULT_COLORS := [Color("#fbf6ec"), Color("#efe4cf")]
## The pretend Dock's left and right edge, as fractions of the display's width.
const DOCK_SPAN := Vector2(0.25, 0.75)

@export var demo_path: NodePath = ^"../Demo"
@export var avatars_path: NodePath = ^"../Content/Avatars"

var _dir := ""
var _phase := &"setup" # setup, ready, show, tail, title, done
var _wait := 0.0
var _backdrop: Backdrop
var _dock: FakeDock
@onready var _demo: Node = get_node_or_null(demo_path)
@onready var _avatars: Node = get_node_or_null(avatars_path)


## A vertical gradient over a whole strip, under every buddy and balloon.
class Backdrop:
	extends Node2D
	var colors: Array = DEFAULT_COLORS
	var size := Vector2.ZERO

	func _ready() -> void:
		z_as_relative = false
		z_index = RenderingServer.CANVAS_ITEM_Z_MIN

	func _draw() -> void:
		var top: Color = colors[0]
		var bottom: Color = colors[-1]
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))


## A Dock look-alike that slides up from the bottom edge, as tall as the lift the
## buddies get from the forced Dock.
class FakeDock:
	extends Node2D
	const SLIDE_SEC := 0.25
	const TILES := ["#5b8def", "#f2a541", "#4fb477", "#e5646e", "#9b7be0", "#3fb6c6", "#f07fb0", "#8a96a8"]
	var shown := false
	var span := DOCK_SPAN
	var strip_size := Vector2.ZERO
	var height_px := 0.0
	var _t := 0.0

	func _ready() -> void:
		z_as_relative = false
		z_index = RenderingServer.CANVAS_ITEM_Z_MIN + 1

	func _process(delta: float) -> void:
		var target := 1.0 if shown else 0.0
		var t := move_toward(_t, target, delta / SLIDE_SEC)
		if t != _t:
			_t = t
			queue_redraw()

	func _draw() -> void:
		if _t <= 0.0 or height_px <= 0.0:
			return
		var e := 1.0 - pow(1.0 - _t, 3.0) # ease out
		var h := height_px
		var x0 := span.x * strip_size.x
		var w := (span.y - span.x) * strip_size.x
		var top := strip_size.y - h * e
		var body := StyleBoxFlat.new()
		body.bg_color = Color(1, 1, 1, 0.55)
		body.border_color = Color(1, 1, 1, 0.9)
		body.set_border_width_all(maxi(1, roundi(h * 0.015)))
		body.set_corner_radius_all(roundi(h * 0.28))
		body.shadow_color = Color(0, 0, 0, 0.12)
		body.shadow_size = roundi(h * 0.12)
		draw_style_box(body, Rect2(x0, top, w, h))
		var pad := h * 0.13
		var tile := h - 2.0 * pad
		var count := mini(TILES.size(), int((w - pad) / (tile + pad)))
		var start := x0 + (w - (count * tile + (count - 1) * pad)) / 2.0
		for i in count:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(TILES[i])
			box.set_corner_radius_all(roundi(tile * 0.23))
			draw_style_box(box, Rect2(start + i * (tile + pad), top + pad, tile, tile))


func _ready() -> void:
	_dir = TrailerMode.dir()
	if _dir.is_empty() or Instance.duplicate or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(_dir)
	for file in ["strip.json", "go", "done", "quit"]:
		DirAccess.remove_absolute(_dir.path_join(file))
	# Kept in memory only (Settings.transient), whatever the user has chosen.
	Settings.overlay_visible = true
	Settings.debug_regions = false
	Settings.show_names = true
	Settings.buddy_size = _arg("--trailer-size=", "large")
	Settings.messages = "balloons"
	Settings.notify_done = true
	Settings.notify_errors = true
	_demo.cue.connect(_on_cue)
	print("Trailer: waiting for the strip, then for %s" % _dir.path_join("go"))


func _process(delta: float) -> void:
	_wait += delta
	if _dock and _dock.shown:
		var lift := Overlay.dock_lift_pt(Overlay.walkway.main_index()) * Overlay.walkway.px_per_pt
		if lift > 0.0 and lift != _dock.height_px:
			_dock.height_px = lift
			_dock.queue_redraw()
	match _phase:
		&"setup":
			if _setup():
				_phase = &"ready"
				_wait = 0.0
		&"ready":
			if _wait >= SETTLE_SEC and not FileAccess.file_exists(_dir.path_join("strip.json")):
				_write_strip()
			if _exists("go"):
				_phase = &"show"
				_wait = 0.0
				_demo.start(Demo.TRAILER_STEPS)
			elif _wait >= WAIT_SEC + SETTLE_SEC:
				_give_up("no go from the script")
		&"show":
			if not _demo.running and _avatars.avatars().is_empty():
				_phase = &"tail"
				_wait = 0.0
		&"tail":
			if _wait >= TAIL_SEC:
				_phase = &"title"
				_wait = 0.0
				var title := TitleCard.new()
				title.name = "TrailerTitle"
				title.size = _backdrop.size
				Overlay.strip_stage(Overlay.walkway.main_index()).add_child(title)
		&"title":
			if _wait >= TitleCard.DURATION_SEC:
				_phase = &"done"
				_wait = 0.0
				_touch("done")
				print("Trailer: show over")
		&"done":
			if _exists("quit") or _wait >= WAIT_SEC:
				get_tree().quit()


## Pins home to the main display and lays the backdrop on its strip. False while
## the overlay has no layout yet.
func _setup() -> bool:
	if Overlay.walkway.is_empty():
		return false
	var main := Overlay.walkway.main_index()
	var main_id := str(Overlay.walkway.segments[main].id)
	if Settings.screen != main_id:
		Settings.screen = main_id
	if Overlay.home_index() != main:
		return false
	_backdrop = Backdrop.new()
	_backdrop.name = "TrailerBackdrop"
	var colors := _arg("--trailer-bg=", "")
	if not colors.is_empty():
		_backdrop.colors = Array(colors.split(",")).map(func(c: String) -> Color: return Color(c.strip_edges()))
	Overlay.strip_stage(main).add_child(_backdrop)
	_dock = FakeDock.new()
	_dock.name = "TrailerDock"
	Overlay.strip_stage(main).add_child(_dock)
	Overlay.debug_force_dock(-1) # the real Dock (or the pointer near it) lifts no one
	_fit_backdrop()
	Overlay.layout_changed.connect(func(_old: Variant) -> void: _fit_backdrop())
	return true


func _fit_backdrop() -> void:
	var main := Overlay.walkway.main_index()
	_backdrop.size = Vector2(Overlay.strip_rect_px(main).size)
	_dock.strip_size = _backdrop.size
	for node: Node2D in [_backdrop, _dock]:
		if node.get_parent() != Overlay.strip_stage(main):
			node.reparent(Overlay.strip_stage(main), false)
		node.queue_redraw()


## The show's "dock" cue: the pretend Dock slides in or out, and the forced Dock
## lifts the buddies that stand above it (dock-dodge).
func _on_cue(action: String, argument: String) -> void:
	if action != "dock" or _dock == null:
		return
	var main := Overlay.walkway.main_index()
	if argument == "show":
		Overlay.debug_force_dock(Overlay.walkway.segments[main].id, DOCK_SPAN)
		_dock.span = DOCK_SPAN
		_dock.shown = true
	else:
		Overlay.debug_force_dock(-1)
		_dock.shown = false


## The strip in pixels of the main display as a screen recording sees it.
func _write_strip() -> void:
	var screen := DisplayServer.get_primary_screen()
	var factor := DisplayServer.screen_get_scale(screen) / DisplayServer.screen_get_max_scale()
	var rect := Overlay.strip_rect_px(Overlay.walkway.main_index())
	var local := Rect2(Vector2(rect.position - DisplayServer.screen_get_position(screen)) * factor,
		Vector2(rect.size) * factor)
	var screen_size := Vector2(DisplayServer.screen_get_size(screen)) * factor
	var info := {"x": roundi(local.position.x), "y": roundi(local.position.y),
		"w": roundi(local.size.x), "h": roundi(local.size.y),
		"screen_w": roundi(screen_size.x), "screen_h": roundi(screen_size.y),
		"show_sec": Demo.TRAILER_STEPS[-1][0]}
	var f := FileAccess.open(_dir.path_join("strip.json"), FileAccess.WRITE)
	if f == null:
		_give_up("cannot write strip.json (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(info))
	f.close()
	print("Trailer: strip %s" % JSON.stringify(info))


func _exists(file: String) -> bool:
	return FileAccess.file_exists(_dir.path_join(file))


func _touch(file: String) -> void:
	var f := FileAccess.open(_dir.path_join(file), FileAccess.WRITE)
	if f:
		f.close()


func _give_up(reason: String) -> void:
	push_warning("Trailer: %s; quitting." % reason)
	get_tree().quit(1)


static func _arg(prefix: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return fallback
