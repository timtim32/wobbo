extends SceneTree
## Exports the monster's parts from art/monster/monster.svg (character-rig D2).
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tools/export_monster.gd
##
## Every part group is rasterised alone on the full canvas, cropped to its used
## rect and saved as res://assets/monster/parts/<name>.png. manifest.json lists
## each part's rect and pivot in export pixels. Output is deterministic.

const SVG_PATH := "res://../art/monster/monster.svg"
const OUT_DIR := "res://assets/monster/"
## Export pixels per SVG unit. The 440-unit artboard becomes 440 px, twice the
## Retina display size of a 110 pt monster.
const PX_PER_UNIT := 1.0

var _part_re := RegEx.create_from_string(
	'<g id="part-(?<name>[a-z_]+)"(?<hidden> style="display:none")?>(?<body>[\\s\\S]*?)</g>')
var _pivot_re := RegEx.create_from_string(
	'<circle class="pivot" cx="(?<x>-?[0-9.]+)" cy="(?<y>-?[0-9.]+)"')
var _svg_open_re := RegEx.create_from_string("<svg[^>]*>")
var _viewbox_re := RegEx.create_from_string('viewBox="0 0 (?<w>[0-9.]+) (?<h>[0-9.]+)"')


func _initialize() -> void:
	var err := export_parts()
	quit(0 if err == OK else 1)


func export_parts() -> Error:
	var svg_file := ProjectSettings.globalize_path(SVG_PATH).simplify_path()
	var svg := FileAccess.get_file_as_string(svg_file)
	if svg.is_empty():
		printerr("export_monster: cannot read %s" % svg_file)
		return ERR_FILE_CANT_READ
	var svg_open := _svg_open_re.search(svg).get_string()
	var vb := _viewbox_re.search(svg)
	var canvas := Vector2(vb.get_string("w").to_float(), vb.get_string("h").to_float()) * PX_PER_UNIT

	var parts_dir := ProjectSettings.globalize_path(OUT_DIR + "parts")
	DirAccess.make_dir_recursive_absolute(parts_dir)
	var parts := {}
	var figure := Rect2i()
	var order := 0
	for m in _part_re.search_all(svg):
		var name := m.get_string("name")
		var body := m.get_string("body")
		var pivot_m := _pivot_re.search(body)
		if pivot_m == null:
			printerr("export_monster: part '%s' has no pivot marker" % name)
			return ERR_INVALID_DATA
		var img := Image.new()
		var err := img.load_svg_from_string("%s<g>%s</g></svg>" % [svg_open, body], PX_PER_UNIT)
		if err != OK:
			printerr("export_monster: cannot rasterise '%s': %s" % [name, error_string(err)])
			return err
		var rect := img.get_used_rect()
		if rect.size == Vector2i.ZERO:
			printerr("export_monster: part '%s' is empty" % name)
			return ERR_INVALID_DATA
		err = img.get_region(rect).save_png(parts_dir.path_join(name + ".png"))
		if err != OK:
			return err
		var visible := m.get_string("hidden").is_empty()
		if visible:
			figure = rect if figure.size == Vector2i.ZERO else figure.merge(rect)
		var pivot := Vector2(pivot_m.get_string("x").to_float(), pivot_m.get_string("y").to_float()) * PX_PER_UNIT
		parts[name] = {
			"order": order,
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"pivot": [snappedf(pivot.x, 0.1), snappedf(pivot.y, 0.1)],
			"visible": visible,
		}
		order += 1
		print("  %-14s rect=%s pivot=%s%s" % [name, rect, pivot, "" if visible else " (hidden)"])

	var manifest := {
		"source": "art/monster/monster.svg",
		"px_per_unit": PX_PER_UNIT,
		"canvas": [canvas.x, canvas.y],
		"figure_rect": [figure.position.x, figure.position.y, figure.size.x, figure.size.y],
		"parts": parts,
	}
	var f := FileAccess.open(OUT_DIR + "manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t", true) + "\n")
	f.close()
	print("export_monster: %d parts, figure %s" % [parts.size(), figure])
	return OK
