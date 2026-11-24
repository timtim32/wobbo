extends PanelContainer
## One buddy's speech balloon (balloons-and-speech design D5, D6): an opaque white
## rounded panel with a tail, the session name in the buddy's colour, the text,
## and for a request its answer buttons, a text field and a time-left bar.
##
## The owning SessionAvatar puts it in a strip's UI layer, gives it content with
## show_content(), asks fit() for its size and place()s it. Actions go to the
## `Messages` node. Sizes are in window px; *_PT constants are points.

const Layout := preload("res://scripts/core/balloon_layout.gd")
const NameLabel := preload("res://scripts/avatars/name_label.gd")
const Protocol := preload("res://scripts/bridge/protocol.gd")
const SessionRegistry := preload("res://scripts/core/session_registry.gd")

const BODY_PT := 13.0
const HEADER_PT := 11.0
const BUTTON_PT := 12.0
const PAD_PT := 10.0
const SEP_PT := 6.0
const BAR_PT := 3.0
const BACKGROUND := Color(1.0, 1.0, 1.0)
const TEXT_COLOR := Color(0.12, 0.12, 0.14)
const MUTED := Color(0.45, 0.46, 0.5)
const BUTTON_BG := Color(0.92, 0.93, 0.95)
const BUTTON_HOVER := Color(0.85, 0.87, 0.9)
const DEFAULT_ACCENT := Color(0.25, 0.5, 0.2)
const NOTE_PT := 11.0
const ANSWER_HINT := "Answer in the session"
## Width of the content when the balloon has a text field.
const FIELD_WIDTH_PT := 220.0

var session_id := ""
var messages: Node = null

var _px := 1.0
var _accent := DEFAULT_ACCENT
var _key := ""
var _content := {}
var _tail_x := 0.0 # px from the left edge
var _field_focused := false

var _box := VBoxContainer.new()
var _name := Label.new()
var _count := Label.new()
var _close := Button.new()
var _body := Label.new()
var _note := Label.new() # choices and hint of an asked question (design D11)
var _buttons := HFlowContainer.new()
var _field := LineEdit.new()
var _bar := Control.new()


## Called before the balloon enters the tree. `hue` in degrees, or negative for
## the original green.
func setup(p_session_id: String, display_name: String, hue: float) -> void:
	session_id = p_session_id
	name = "Balloon_" + p_session_id.validate_node_name()
	_px = Overlay.points_to_px(1.0)
	if hue >= 0.0:
		_accent = Color.from_hsv(fposmod(hue, 360.0) / 360.0, 0.75, 0.55)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 6
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.set_corner_radius_all(int(Layout.CORNER_PT * _px))
	style.set_content_margin_all(PAD_PT * _px)
	style.content_margin_top = (PAD_PT - 3.0) * _px
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = int(6.0 * _px)
	style.shadow_offset = Vector2(0, 2.0 * _px)
	add_theme_stylebox_override("panel", style)
	_box.add_theme_constant_override("separation", int(SEP_PT * _px))
	add_child(_box)
	_build_header(display_name)
	_style_label(_body, BODY_PT, TEXT_COLOR, 400)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_box.add_child(_body)
	_style_label(_note, NOTE_PT, MUTED, 500)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_note)
	_buttons.add_theme_constant_override("h_separation", int(6.0 * _px))
	_buttons.add_theme_constant_override("v_separation", int(6.0 * _px))
	_box.add_child(_buttons)
	_build_field()
	_bar.custom_minimum_size.y = BAR_PT * _px
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_box.add_child(_bar)
	gui_input.connect(_on_gui_input)


func _build_header(display_name: String) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(6.0 * _px))
	_style_label(_name, HEADER_PT, _accent, 700)
	_name.text = display_name
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name)
	_style_label(_count, HEADER_PT, MUTED, 500)
	header.add_child(_count)
	_close.text = "×"
	_close.flat = true
	_close.focus_mode = Control.FOCUS_NONE
	_close.tooltip_text = ""
	_close.add_theme_font_override("font", NameLabel.system_font())
	_close.add_theme_font_size_override("font_size", int(14.0 * _px))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_close.add_theme_color_override(c, MUTED if c == "font_color" else TEXT_COLOR)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		_close.add_theme_stylebox_override(s, empty)
	_close.custom_minimum_size = Vector2(16.0, 14.0) * _px
	_close.pressed.connect(_on_close)
	header.add_child(_close)
	_box.add_child(header)


func _build_field() -> void:
	_field.placeholder_text = "Type an answer…"
	_field.add_theme_font_override("font", NameLabel.system_font())
	_field.add_theme_font_size_override("font_size", int(BUTTON_PT * _px))
	_field.add_theme_color_override("font_color", TEXT_COLOR)
	_field.add_theme_color_override("font_placeholder_color", MUTED)
	_field.add_theme_color_override("caret_color", TEXT_COLOR)
	for s in ["normal", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.97, 0.97, 0.98)
		box.border_color = _accent if s == "focus" else Color(0.82, 0.83, 0.86)
		box.set_border_width_all(maxi(1, int(_px)))
		box.set_corner_radius_all(int(5.0 * _px))
		box.content_margin_left = 6.0 * _px
		box.content_margin_right = 6.0 * _px
		box.content_margin_top = 3.0 * _px
		box.content_margin_bottom = 3.0 * _px
		_field.add_theme_stylebox_override(s, box)
	_field.gui_input.connect(_on_field_input)
	_field.text_submitted.connect(_on_field_submitted)
	_box.add_child(_field)


# --- Content ------------------------------------------------------------------------

## Shows `content` from Messages.content_for(); rebuilds only when it changed.
func show_content(content: Dictionary) -> void:
	var key := _key_of(content)
	if key == _key:
		_content = content
		return
	_release_field()
	_key = key
	_content = content
	var request: SessionRegistry.Request = content.get("request")
	var asks := request != null
	var is_permission := asks and request.kind == Protocol.REQUEST_PERMISSION
	_body.text = request.text if asks else String(content.get("text", ""))
	var asked: bool = content.get("type") == &"asked"
	var note := []
	if asked:
		var choices: Array = content.get("choices", [])
		if not choices.is_empty():
			note.append(" · ".join(choices.map(func(c: Variant) -> String: return String(c))))
		note.append(ANSWER_HINT)
	_note.text = "\n".join(note)
	_note.visible = asked
	var count := []
	if is_permission:
		count.append("Permission")
	if int(content.get("count", 1)) > 1:
		count.append("%d of %d" % [int(content.index), int(content.count)])
	_count.text = " · ".join(count)
	_count.visible = not count.is_empty()
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	if asks:
		var choices: Array[String] = request.choices
		if is_permission and choices.is_empty():
			choices = ["allow", "deny"]
		for value in choices:
			var label := value.capitalize() if is_permission else value
			_buttons.add_child(_button(label, is_permission and value == "allow",
				func() -> void: _answer(request.id, value, "")))
	_buttons.visible = _buttons.get_child_count() > 0
	_field.visible = asks and request.allow_text
	_field.text = ""
	_bar.visible = asks and request.timeout_s > 0
	_body.max_lines_visible = -1
	reset_size()


func _key_of(content: Dictionary) -> String:
	if content.is_empty():
		return ""
	if content.get("type") == &"request":
		return "r:%s:%d:%d" % [content.id, int(content.index), int(content.count)]
	if content.get("type") == &"asked":
		return "a:%s:%s" % [content.get("text", ""), ",".join(content.get("choices", []))]
	return "m:%s:%s" % [content.get("kind", ""), content.get("text", "")]


func is_request() -> bool:
	return _content.get("type") == &"request"


func is_asked() -> bool:
	return _content.get("type") == &"asked"


# --- Size and place -------------------------------------------------------------

## Fits the balloon in `max_height_pt` and returns its size in points. The body
## loses lines (ending in "…") when it does not fit; the sizes of the other
## parts come from the last layout, so a new content settles within a frame or two.
func fit(max_height_pt: float) -> Vector2:
	var inner := _content_width_pt()
	var width_pt := Layout.width_for(inner + 2.0 * PAD_PT)
	var inner_px := (width_pt - 2.0 * PAD_PT) * _px
	custom_minimum_size.x = width_pt * _px
	_body.custom_minimum_size.x = inner_px
	var max_px := max_height_pt * _px
	var spacing := float(_body.get_theme_constant("line_spacing"))
	var line_px := float(_body.get_line_height()) + spacing
	_body.size.x = inner_px # line count at the final width
	var lines := _body.get_line_count()
	var others := size.y - _body.size.y if _body.size.y > 0.0 else 0.0
	var fit_lines := maxi(1, int(floor((max_px - others + spacing) / maxf(1.0, line_px))))
	var shown := mini(lines, fit_lines)
	var want := fit_lines if lines > fit_lines else -1
	if _body.max_lines_visible != want:
		_body.max_lines_visible = want
	# A wrapping label that trims reports a minimum height of 1, so it is set here.
	_body.custom_minimum_size.y = shown * line_px - spacing
	reset_size()
	return size / _px


## The widest part's natural width in points: one line of text, the buttons in a row, the header.
func _content_width_pt() -> float:
	var font := NameLabel.system_font()
	var w := font.get_string_size(_body.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(BODY_PT * _px)).x
	var row := 0.0
	for b: Control in _buttons.get_children():
		row += b.get_combined_minimum_size().x + 6.0 * _px
	var header := font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(HEADER_PT * _px)).x \
		+ font.get_string_size(_count.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(HEADER_PT * _px)).x + 40.0 * _px
	var note := 0.0
	for line in _note.text.split("\n"):
		note = maxf(note, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(NOTE_PT * _px)).x)
	var widest := maxf(maxf(maxf(w, row), header), note if _note.visible else 0.0) / _px + 2.0
	return maxf(widest, FIELD_WIDTH_PT) if _field.visible else widest


## `top_left_px`: window-local position; `tail_x_pt`: the tail's x from the left edge.
func place(top_left_px: Vector2, tail_x_pt: float) -> void:
	position = top_left_px.round()
	if not is_equal_approx(_tail_x, tail_x_pt * _px):
		_tail_x = tail_x_pt * _px
		queue_redraw()


## The tail is drawn as a triangle with a colour per corner, the way StyleBoxFlat
## draws the panel. draw_colored_polygon() came out black in exported builds of
## Godot 4.7.2 (GL Compatibility), also with an explicit white texture.
func _draw() -> void:
	var half := Layout.TAIL_HALF_WIDTH_PT * _px
	var tip := Vector2(_tail_x, size.y + Layout.TAIL_PT * _px)
	var points := PackedVector2Array([Vector2(_tail_x - half, size.y - 1.0), Vector2(_tail_x + half, size.y - 1.0), tip])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array([0, 1, 2]), points,
		PackedColorArray([BACKGROUND, BACKGROUND, BACKGROUND]))


func _process(_delta: float) -> void:
	if _bar.visible:
		_bar.queue_redraw()


## The time left before the asker gives up, as a shrinking bar.
func _draw_bar() -> void:
	var request: SessionRegistry.Request = _content.get("request")
	if request == null or request.timeout_s <= 0:
		return
	var timeout_ms := request.timeout_s * 1000
	var left := 1.0 - float(Time.get_ticks_msec() - request.added_msec) / float(timeout_ms)
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(r, Color(0.9, 0.91, 0.93))
	_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(left, 0.0, 1.0), r.size.y)), _accent)


# --- Input ------------------------------------------------------------------------

## A click on a message balloon closes it (spec "How long a message stays"); a
## click on an asked question leads to the session (design D11).
func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not is_request():
		accept_event()
		if messages == null:
			return
		if is_asked():
			messages.go_to_session(session_id)
		else:
			messages.close_message(session_id)


func _on_close() -> void:
	if messages == null:
		return
	if is_request():
		_release_field()
		messages.dismiss(_request_id())
	elif is_asked():
		messages.close_asked(session_id)
	else:
		messages.close_message(session_id)


func _request_id() -> String:
	var request: SessionRegistry.Request = _content.get("request")
	return request.id if request else ""


func _answer(request_id: String, choice: String, text: String) -> void:
	_release_field()
	if messages:
		messages.answer(request_id, choice, text)


## The text field takes keyboard focus only when clicked (spec "Free-text answer").
func _on_field_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _field_focused:
		_field_focused = true
		Overlay.request_keyboard_focus(_field)
	var key := event as InputEventKey
	if key and key.pressed and key.keycode == KEY_ESCAPE:
		_field.accept_event()
		_release_field()


func _on_field_submitted(text: String) -> void:
	if text.strip_edges().is_empty() or not is_request():
		return
	_answer(_request_id(), "", text.strip_edges())


func _release_field() -> void:
	if _field_focused:
		_field_focused = false
		_field.release_focus()
		Overlay.release_all_keyboard_focus(_field)


func field_focused() -> bool:
	return _field_focused


## Gives back keyboard focus before the balloon hides or goes away.
func hide_balloon() -> void:
	_release_field()
	visible = false


func _exit_tree() -> void:
	_release_field()


# --- Helpers --------------------------------------------------------------------

func _style_label(label: Label, size_pt: float, color: Color, weight: int) -> void:
	var font := NameLabel.system_font()
	if weight != 600:
		var f := SystemFont.new()
		f.font_names = font.font_names
		f.font_weight = weight
		font = f
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", int(size_pt * _px))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _button(text: String, primary: bool, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", NameLabel.system_font())
	button.add_theme_font_size_override("font_size", int(BUTTON_PT * _px))
	var fg := Color.WHITE if primary else TEXT_COLOR
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(c, fg)
	for state in [["normal", 0.0], ["hover", 1.0], ["pressed", 2.0], ["focus", 0.0]]:
		var box := StyleBoxFlat.new()
		var base := _accent if primary else BUTTON_BG
		box.bg_color = base.darkened(0.12 * state[1]) if primary else (BUTTON_HOVER if state[1] > 0.0 else base)
		box.set_corner_radius_all(int(6.0 * _px))
		box.content_margin_left = 10.0 * _px
		box.content_margin_right = 10.0 * _px
		box.content_margin_top = 3.0 * _px
		box.content_margin_bottom = 3.0 * _px
		button.add_theme_stylebox_override(state[0], box)
	button.pressed.connect(on_press)
	return button
