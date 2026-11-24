extends LineEdit
## Temporary debug text field (task 4.4): opened from an avatar's context menu
## ("Type here (debug)") in debug mode, requests keyboard focus while open, closes on Esc or Enter.

const REGION_ID := &"debug_text_field"
const SIZE_PT := Vector2(220, 30)
## How far above the anchor's feet the field's top edge sits.
const ABOVE_FEET_PT := 160.0

var _anchor: Node # a walkway body (position in walkway points)


func _ready() -> void:
	hide()
	placeholder_text = "Type here, Enter/Esc to close"
	text_submitted.connect(func(t: String) -> void:
		print("DebugTextField: submitted '%s'" % t)
		close())
	Overlay.content_visibility_changed.connect(func(v: bool) -> void:
		if not v: close())
	Settings.changed.connect(func(k: StringName, v: Variant) -> void:
		if k == &"debug_regions" and not v: close())


func open_at(anchor: Node) -> void:
	if visible or not Settings.debug_regions:
		return
	_anchor = anchor
	text = ""
	size = SIZE_PT * Overlay.points_to_px(1.0)
	add_theme_font_size_override("font_size", int(Overlay.points_to_px(13)))
	_follow_anchor()
	show()
	Overlay.request_keyboard_focus(self)
	print("DebugTextField: opened")
	_log_focus("after open")


func close() -> void:
	if not visible:
		return
	hide()
	_anchor = null
	Overlay.remove_region(REGION_ID)
	Overlay.release_keyboard_focus(self)
	print("DebugTextField: closed")
	_log_focus("after close")


func _log_focus(label: String) -> void:
	if Overlay.native == null:
		return
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		print("DebugTextField: %s frontmost=%s overlay_active=%s has_focus=%s" % [
			label, Overlay.native.get_frontmost_app_bundle_id(), Overlay.native.is_app_active(), has_focus()]))


func _process(_delta: float) -> void:
	if visible:
		_follow_anchor()


func _follow_anchor() -> void:
	if _anchor == null:
		return
	var strip := Overlay.strip_index_of_window(get_window())
	if strip < 0:
		return
	var local := Overlay.walkway_to_local(strip, _anchor.position)
	var strip_w := float(Overlay.strip_rect_px(strip).size.x)
	var x := clampf(local.x - size.x * 0.5, 0.0, strip_w - size.x)
	var y := local.y - Overlay.points_to_px(ABOVE_FEET_PT)
	position = Vector2(x, y)
	Overlay.set_region(REGION_ID, Overlay.local_rect_to_walkway(strip, Rect2(position, size)))


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		close()
		accept_event()


func _exit_tree() -> void:
	Overlay.release_all_keyboard_focus(self)
