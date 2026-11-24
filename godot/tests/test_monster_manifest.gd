extends "res://tests/base_test.gd"
## Checks that the exported monster parts match the SVG source (design D2).

const SVG_PATH := "res://../art/monster/monster.svg"
const MANIFEST_PATH := "res://assets/monster/manifest.json"
const PARTS_DIR := "res://assets/monster/parts/"
## Parts that rotate around their own joint: their pivot must lie on the part.
const LIMBS := ["arm_l", "arm_r", "ear_l", "ear_r", "leg_l", "leg_r", "eye_white", "pupil", "eyelid"]

var manifest: Dictionary


func before_each() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))


func _svg_parts() -> PackedStringArray:
	var svg := FileAccess.get_file_as_string(ProjectSettings.globalize_path(SVG_PATH).simplify_path())
	var names: PackedStringArray = []
	for m in RegEx.create_from_string('<g id="part-([a-z_]+)"').search_all(svg):
		names.append(m.get_string(1))
	return names


func test_every_svg_part_is_exported() -> void:
	var names := _svg_parts()
	assert_true(names.size() >= 16, "SVG has all parts (%d)" % names.size())
	for name in names:
		assert_true(manifest.parts.has(name), "manifest has %s" % name)
		assert_true(FileAccess.file_exists(PARTS_DIR + name + ".png"), "%s.png exists" % name)
	assert_eq(manifest.parts.size(), names.size(), "no extra parts in manifest")


func test_pivots_are_on_canvas_and_on_their_limb() -> void:
	var canvas := Rect2(Vector2.ZERO, Vector2(manifest.canvas[0], manifest.canvas[1]))
	for name: String in manifest.parts:
		var part: Dictionary = manifest.parts[name]
		var pivot := Vector2(part.pivot[0], part.pivot[1])
		assert_true(canvas.has_point(pivot), "%s pivot %s on canvas" % [name, pivot])
		if name in LIMBS:
			var rect := Rect2(part.rect[0], part.rect[1], part.rect[2], part.rect[3]).grow(1.0)
			assert_true(rect.has_point(pivot), "%s pivot %s inside its rect %s" % [name, pivot, rect])


func test_figure_matches_export_scale() -> void:
	var figure_h: float = manifest.figure_rect[3]
	var canvas_h: float = manifest.canvas[1]
	assert_eq(canvas_h, 440.0 * manifest.px_per_unit, "canvas height follows px_per_unit")
	assert_true(figure_h > canvas_h * 0.85 and figure_h <= canvas_h, "figure fills the canvas (%s)" % figure_h)


func test_part_textures_match_manifest_sizes() -> void:
	for name: String in manifest.parts:
		var tex: Texture2D = load(PARTS_DIR + name + ".png")
		assert_true(tex != null, "%s texture loads" % name)
		if tex:
			var part: Dictionary = manifest.parts[name]
			assert_eq(Vector2i(tex.get_size()), Vector2i(part.rect[2], part.rect[3]), "%s size" % name)


## Spike S1: the parts, recomposited at their offsets, must match a full render
## of the SVG (average channel difference below 1%).
static func recomposite(manifest: Dictionary, parts_dir: String) -> Image:
	var out := Image.create(int(manifest.canvas[0]), int(manifest.canvas[1]), false, Image.FORMAT_RGBA8)
	var names: Array = manifest.parts.keys()
	names.sort_custom(func(a, b): return manifest.parts[a].order < manifest.parts[b].order)
	for name: String in names:
		var part: Dictionary = manifest.parts[name]
		if not part.visible:
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(parts_dir + name + ".png"))
		img.convert(Image.FORMAT_RGBA8)
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(part.rect[0], part.rect[1]))
	return out


static func full_render(manifest: Dictionary) -> Image:
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(SVG_PATH).simplify_path()), manifest.px_per_unit)
	img.convert(Image.FORMAT_RGBA8)
	return img


static func average_difference(a: Image, b: Image) -> float:
	var total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			# Compare premultiplied colours, so fully transparent pixels count as equal.
			total += absf(ca.r * ca.a - cb.r * cb.a) + absf(ca.g * ca.a - cb.g * cb.a) \
				+ absf(ca.b * ca.a - cb.b * cb.a) + absf(ca.a - cb.a)
	return total / (a.get_width() * a.get_height() * 4.0)


func test_recomposited_parts_match_full_render() -> void:
	var full := full_render(manifest)
	var comp := recomposite(manifest, PARTS_DIR)
	assert_eq(comp.get_size(), full.get_size(), "same canvas size")
	var diff := average_difference(comp, full)
	print("    recomposite vs full render: average difference %.4f%%" % (diff * 100.0))
	assert_true(diff < 0.01, "average difference %.4f below 1%%" % diff)
	var out_dir := OS.get_environment("MONSTER_COMPARE_DIR")
	if not out_dir.is_empty():
		comp.save_png(out_dir.path_join("recomposite.png"))
		full.save_png(out_dir.path_join("full_render.png"))
