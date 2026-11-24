extends CanvasLayer
## Debug region view (overlay-window D9, multi-display D9): outlines every
## strip and every interactive region, in each strip window, while
## Settings.debug_regions is on and the overlay is shown.

const STRIP_COLOR := Color(1.0, 0.35, 0.2, 0.9)
const REGION_COLOR := Color(0.2, 0.8, 1.0, 0.95)

var _drawers: Array[Node2D] = []


func _ready() -> void:
	layer = 100
	Settings.changed.connect(func(_k: StringName, _v: Variant) -> void: _refresh())
	Overlay.content_visibility_changed.connect(func(_v: bool) -> void: _refresh())
	Overlay.layout_changed.connect(func(_old: Variant) -> void: _rebuild.call_deferred())
	_rebuild.call_deferred()


func is_active() -> bool:
	return Settings.debug_regions and Overlay.content_visible


## One drawer per strip, inside that strip's stage (so it draws in its window).
func _rebuild() -> void:
	for d in _drawers:
		if is_instance_valid(d):
			d.queue_free()
	_drawers.clear()
	for i in Overlay.strip_count():
		var d := Node2D.new()
		d.name = "DebugOutlines"
		d.z_index = 100
		d.draw.connect(_draw_strip.bind(d, i))
		Overlay.strip_stage(i).add_child(d)
		_drawers.append(d)
	_refresh()


func _refresh() -> void:
	set_process(is_active())
	for d in _drawers:
		if is_instance_valid(d):
			d.visible = is_active()
			d.queue_redraw()


func _process(_delta: float) -> void:
	for d in _drawers:
		if is_instance_valid(d):
			d.queue_redraw()


func _draw_strip(d: Node2D, i: int) -> void:
	if i >= Overlay.strip_count():
		return
	var width := maxf(1.0, Overlay.points_to_px(1.0))
	# The whole window, also its headroom above the strip while a buddy is carried (buddy-drag D6).
	var size := Vector2(Overlay.strip_window_rect_px(i).size)
	var top := Vector2(0.0, Overlay.strip_rect_px(i).size.y - size.y)
	d.draw_rect(Rect2(top, size).grow(-width * 0.5), STRIP_COLOR, false, width)
	var font := ThemeDB.fallback_font
	var font_size := int(Overlay.points_to_px(11))
	var regions := Overlay.get_regions()
	for id: StringName in regions:
		var r: Rect2 = regions[id]
		if not i in Overlay.strips_overlapping(r):
			continue
		var local := Rect2(Overlay.walkway_to_local(i, r.position), r.size * Overlay.points_to_px(1.0))
		d.draw_rect(local, REGION_COLOR, false, width)
		d.draw_string(font, local.position + Vector2(0, -width * 2), String(id),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, REGION_COLOR)
