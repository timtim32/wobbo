extends Label
## An avatar's name label in one strip window (session-avatars design D5):
## white system-font text on a rounded dark pill, at most 140 pt wide, cut
## with "…", centred above the avatar's head. Not interactive.

const FONT_PT := 12.0
const HEIGHT_PT := 20.0
const PAD_PT := 7.0
const MAX_WIDTH_PT := 140.0
const GAP_PT := 6.0
const BACKGROUND := Color(0.08, 0.08, 0.1, 0.72)

static var _font: Font


static func system_font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray([".AppleSystemUIFont", "Helvetica Neue", "Helvetica"])
		f.font_weight = 600
		_font = f
	return _font


func setup(label_text: String) -> void:
	text = label_text
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_text = true
	z_index = 5
	var px: float = Overlay.points_to_px(1.0)
	var font_size := int(round(FONT_PT * px))
	add_theme_font_override("font", system_font())
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", Color.WHITE)
	var box := StyleBoxFlat.new()
	box.bg_color = BACKGROUND
	box.set_corner_radius_all(int(HEIGHT_PT * px * 0.5))
	box.content_margin_left = PAD_PT * px
	box.content_margin_right = PAD_PT * px
	add_theme_stylebox_override("normal", box)
	var text_width := system_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	size = Vector2(minf(text_width + 2.0 * PAD_PT * px + 2.0, MAX_WIDTH_PT * px), HEIGHT_PT * px)


## Places the label centred above `head_top` (window-local px).
func place(head_top: Vector2) -> void:
	position = (head_top - Vector2(size.x * 0.5, size.y + GAP_PT * Overlay.points_to_px(1.0))).round()
