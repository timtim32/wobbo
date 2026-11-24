extends PanelContainer
## Debug panel (claude-bridge design D9, spec session-tracking "Debug panel"):
## lists sessions with agent, name, state and last message, and lets the user
## answer or dismiss pending requests. Shown only in debug mode; it registers
## its rect as an overlay region so the rest of the strip stays click-through.
## A debug view next to the buddies' balloons (balloons-and-speech D10): answering
## here or in a balloon removes the request from both.

const Protocol := preload("res://scripts/bridge/protocol.gd")
const SessionRegistry := preload("res://scripts/core/session_registry.gd")

const REGION_ID := &"session_panel"
const WIDTH_PT := 360.0
const MARGIN_PT := 10.0

var _list := VBoxContainer.new()
var _dirty := true
var _focused_field: LineEdit = null
var _shrink_frames := 0


func _ready() -> void:
	var style := StyleBoxFlat.new()
	# Opaque: semi-transparent colours look washed out on the transparent overlay.
	style.bg_color = Color(0.08, 0.09, 0.1, 1.0)
	style.set_corner_radius_all(int(Overlay.points_to_px(8)))
	style.set_content_margin_all(Overlay.points_to_px(8))
	add_theme_stylebox_override("panel", style)
	_list.add_theme_constant_override("separation", int(Overlay.points_to_px(6)))
	add_child(_list)
	for sig in [&"session_added", &"session_changed", &"session_removed", &"message_received",
			&"request_added", &"request_removed"]:
		Bridge.connect(sig, func(_a: Variant = null, _b: Variant = null) -> void: _dirty = true)
	Settings.changed.connect(func(_k: StringName, _v: Variant) -> void: _dirty = true)
	Overlay.content_visibility_changed.connect(func(_v: bool) -> void: _dirty = true)


func is_active() -> bool:
	return Settings.debug_regions and Overlay.content_visible


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild()
	if _shrink_frames > 0:
		_shrink_frames -= 1
		reset_size()
	if visible:
		var strip := Overlay.strip_index_of_window(get_window())
		if strip >= 0:
			Overlay.set_region(REGION_ID, Overlay.local_rect_to_walkway(strip, get_global_rect()))


func _rebuild() -> void:
	_release_field()
	# Remove the old rows at once: rows that are only queued for deletion still
	# take part in this frame's layout and make the panel flash taller.
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	visible = is_active()
	if not visible:
		Overlay.remove_region(REGION_ID)
		return
	var header := "Bridge: 127.0.0.1:%d" % Bridge.port if Bridge.is_running() else "Bridge: not running"
	_list.add_child(_label(header, 11, Color(0.6, 0.65, 0.7)))
	var sessions: Array = Bridge.registry.sessions()
	if sessions.is_empty():
		_list.add_child(_label("No sessions", 12, Color(0.8, 0.8, 0.8)))
	for s in sessions:
		_add_session(s)
	position = Vector2.ONE * Overlay.points_to_px(MARGIN_PT)
	custom_minimum_size.x = Overlay.points_to_px(WIDTH_PT)
	_shrink_frames = 2 # shrink to the new content once layout has settled, not every frame


func _add_session(s) -> void:
	var state := String(s.state)
	if s.state == Protocol.STATE_WORKING and not s.tool.is_empty():
		state += " (%s)" % s.tool
	_list.add_child(_label("%s · %s — %s" % [s.agent, s.name, state], 13, _state_color(s.state)))
	if not s.last_message.is_empty():
		_list.add_child(_label("“%s”" % s.last_message, 12, Color(0.9, 0.9, 0.9)))
	if not s.last_problem.is_empty():
		_list.add_child(_label("problem: %s" % s.last_problem.left(120), 11, Color(1, 0.6, 0.5)))
	for request in Bridge.registry.requests_of(s.id):
		_add_request(request)


func _add_request(request: SessionRegistry.Request) -> void:
	var box := VBoxContainer.new()
	var prefix := "Permission: " if request.kind == Protocol.REQUEST_PERMISSION else "Question: "
	box.add_child(_label(prefix + request.text, 12, Color(1, 0.9, 0.5)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(Overlay.points_to_px(4)))
	var choices: Array[String] = request.choices
	if request.kind == Protocol.REQUEST_PERMISSION and choices.is_empty():
		choices = ["allow", "deny"]
	for choice in choices:
		row.add_child(_button(choice, func() -> void: Bridge.answer_request(request.id, choice)))
	row.add_child(_button("Dismiss", func() -> void: Bridge.dismiss_request(request.id)))
	box.add_child(row)
	if request.allow_text:
		var field := LineEdit.new()
		field.placeholder_text = "Type an answer, Enter to send"
		field.add_theme_font_size_override("font_size", int(Overlay.points_to_px(12)))
		field.custom_minimum_size.y = Overlay.points_to_px(24)
		field.gui_input.connect(func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if mb and mb.pressed and _focused_field != field:
				_release_field()
				_focused_field = field
				Overlay.request_keyboard_focus(field))
		field.text_submitted.connect(func(t: String) -> void:
			_release_field()
			Bridge.answer_request(request.id, "", t))
		box.add_child(field)
	_list.add_child(box)


func _release_field() -> void:
	if _focused_field and is_instance_valid(_focused_field):
		Overlay.release_all_keyboard_focus(_focused_field)
	_focused_field = null


func _label(text: String, size_pt: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label needs its width up front, or it measures itself as very tall.
	label.custom_minimum_size.x = Overlay.points_to_px(WIDTH_PT - 16.0)
	label.add_theme_font_size_override("font_size", int(Overlay.points_to_px(size_pt)))
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", int(Overlay.points_to_px(12)))
	for state in [["normal", Color(0.22, 0.25, 0.3)], ["hover", Color(0.3, 0.35, 0.42)],
			["pressed", Color(0.4, 0.46, 0.55)], ["focus", Color(0.22, 0.25, 0.3)]]:
		var box := StyleBoxFlat.new()
		box.bg_color = state[1]
		box.set_corner_radius_all(int(Overlay.points_to_px(4)))
		box.content_margin_left = Overlay.points_to_px(8)
		box.content_margin_right = Overlay.points_to_px(8)
		box.content_margin_top = Overlay.points_to_px(3)
		box.content_margin_bottom = Overlay.points_to_px(3)
		button.add_theme_stylebox_override(state[0], box)
	button.pressed.connect(on_press)
	return button


func _state_color(state: StringName) -> Color:
	match state:
		Protocol.STATE_WORKING: return Color(0.5, 0.8, 1.0)
		Protocol.STATE_THINKING: return Color(0.75, 0.7, 1.0)
		Protocol.STATE_WAITING: return Color(1.0, 0.85, 0.4)
		Protocol.STATE_DONE: return Color(0.55, 0.95, 0.55)
		Protocol.STATE_ERROR: return Color(1.0, 0.5, 0.45)
		Protocol.STATE_ENDED: return Color(0.6, 0.6, 0.6)
	return Color(0.85, 0.85, 0.85)


func _exit_tree() -> void:
	_release_field()
	Overlay.remove_region(REGION_ID)
