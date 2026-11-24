extends SceneTree
## Renders Wobbo's app icon (standalone-app design D11) from the monster drawing:
## the monster in its neutral pose on a rounded square, like macOS app icons.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tools/export_app_icon.gd
##
## Writes res://assets/app_icon.png (1024×1024). The macOS export turns it into
## the .icns. Output is deterministic.

const SVG_PATH := "res://../art/monster/monster.svg"
const OUT_PATH := "res://assets/app_icon.png"
const SIZE := 1024
## macOS icon grid: an 824-point rounded square centred on the 1024 canvas.
const TILE := 824
const RADIUS := 185.0
## How tall the monster stands on the tile.
const MONSTER_HEIGHT := 640
const TOP := Color(0.87, 0.93, 1.0)
const BOTTOM := Color(0.69, 0.82, 0.97)


func _initialize() -> void:
	quit(0 if export_icon() == OK else 1)


func export_icon() -> Error:
	var svg := FileAccess.get_file_as_string(ProjectSettings.globalize_path(SVG_PATH).simplify_path())
	if svg.is_empty():
		printerr("App icon: cannot read %s" % SVG_PATH)
		return ERR_FILE_NOT_FOUND
	var probe := Image.new()
	var err := probe.load_svg_from_string(svg, 1.0)
	if err != OK:
		return err
	var scale := float(MONSTER_HEIGHT) / float(probe.get_used_rect().size.y)
	var art := Image.new()
	art.load_svg_from_string(svg, scale)
	var monster := art.get_region(art.get_used_rect())

	var icon := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	icon.fill(Color(0, 0, 0, 0))
	var origin := (SIZE - TILE) / 2
	for y in TILE:
		var row := TOP.lerp(BOTTOM, float(y) / float(TILE - 1))
		for x in TILE:
			var alpha := _tile_coverage(x, y)
			if alpha > 0.0:
				icon.set_pixel(origin + x, origin + y, Color(row, alpha))
	var at := Vector2i((SIZE - monster.get_width()) / 2, origin + (TILE - monster.get_height()) / 2 + 24)
	icon.blend_rect(monster, Rect2i(Vector2i.ZERO, monster.get_size()), at)
	err = icon.save_png(OUT_PATH)
	if err == OK:
		print("App icon: wrote %s (%d×%d)" % [OUT_PATH, SIZE, SIZE])
	return err


## How much of pixel (x, y) the rounded square covers, with a one-pixel soft edge.
static func _tile_coverage(x: int, y: int) -> float:
	var cx := clampf(x + 0.5, RADIUS, TILE - RADIUS)
	var cy := clampf(y + 0.5, RADIUS, TILE - RADIUS)
	var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
	return clampf(RADIUS - d + 0.5, 0.0, 1.0)
