extends "res://tests/base_test.gd"
## Rig, facing, eye and colour of the Monster scene (design D3, D5, D6).

const MonsterScene := preload("res://characters/monster/monster.tscn")
const LookMath := preload("res://characters/monster/look_math.gd")

var monster: Node2D
var manifest: Dictionary


func before_each() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/monster/manifest.json"))
	monster = MonsterScene.instantiate()
	monster.position = Vector2(500, 300)
	(Engine.get_main_loop() as SceneTree).root.add_child(monster)


func after_each() -> void:
	monster.free()


func _expected_top_left(part: String, scale: float) -> Vector2:
	var info: Dictionary = manifest.parts[part]
	var origin := Vector2(manifest.parts.body.pivot[0], manifest.figure_rect[1] + manifest.figure_rect[3])
	return monster.global_position + (Vector2(info.rect[0], info.rect[1]) - origin) * scale


func test_rest_pose_matches_manifest() -> void:
	monster.body_player.play(&"RESET")
	monster.body_player.advance(0.01)
	var s: float = monster.display_scale()
	for part: String in monster.PARTS:
		var sprite: Sprite2D = monster.skeleton.get_node(monster.PARTS[part][0])
		assert_true(sprite.texture != null, "%s has a texture" % part)
		if part == "pupil" or part == "eyelid":
			continue # pupil eases with the look target, eyelid is scaled to 0.01 when open
		var top_left: Vector2 = sprite.global_transform * sprite.offset
		var expected := _expected_top_left(part, s)
		assert_true(top_left.distance_to(expected) < 0.01,
			"%s top-left %s, expected %s" % [part, top_left, expected])


func test_display_height_is_110_points() -> void:
	var overlay := monster.get_node("/root/Overlay")
	var height: float = monster.get_local_bounds().size.y
	assert_true(absf(height - overlay.points_to_px(110.0)) < 0.01, "height %s" % height)


func test_unknown_clip_keeps_current_clip() -> void:
	monster.play(&"walk")
	assert_false(monster.play(&"moonwalk"), "unknown clip is refused")
	assert_eq(monster.current_clip, &"walk")
	assert_eq(StringName(monster.body_player.current_animation), &"walk")


func test_facing_mirrors_in_place() -> void:
	var before: Vector2 = monster.global_position
	var bounds_right: Rect2 = monster.get_local_bounds()
	monster.face_left()
	assert_eq(monster.global_position, before, "position unchanged")
	assert_true(monster.skeleton.scale.x < 0.0, "mirrored")
	var bounds_left: Rect2 = monster.get_local_bounds()
	assert_true(absf(bounds_left.position.x + bounds_right.end.x) < 0.01, "bounds mirrored around the origin")
	monster.face_right()
	assert_true(monster.skeleton.scale.x > 0.0, "facing right again")


func test_pupil_offset_clamping() -> void:
	assert_eq(LookMath.pupil_offset(Vector2(3, 4), 22.0), Vector2(3, 4), "inside")
	assert_eq(LookMath.pupil_offset(Vector2(22, 0), 22.0), Vector2(22, 0), "on the edge")
	var far: Vector2 = LookMath.pupil_offset(Vector2(300, -400), 22.0)
	assert_true(absf(far.length() - 22.0) < 0.001, "far outside is clamped to the edge")
	assert_true(far.normalized().is_equal_approx(Vector2(0.6, -0.8)), "same direction")
	assert_eq(LookMath.pupil_offset(Vector2.ZERO, 22.0), Vector2.ZERO, "zero")


func test_pupil_stays_inside_eye_and_returns() -> void:
	var look: Node2D = monster.skeleton.get_node("root/body/eye/Look")
	monster.look_at_point(monster.global_position + Vector2(5000, -5000))
	for i in 120:
		monster._update_look(1.0 / 30.0)
	assert_true(look.position.length() <= monster.LOOK_MAX_OFFSET + 0.001, "inside the white")
	assert_true(look.position.x > 0.0 and look.position.y < 0.0, "towards the upper right")
	monster.clear_look_target()
	for i in 120:
		monster._update_look(1.0 / 30.0)
	assert_true(look.position.length() < 0.5, "back to the centre")


func test_default_hue_and_per_instance_material() -> void:
	assert_eq(monster.get_hue_shift(), 0.0, "unset hue gives no shift")
	var other: Node2D = MonsterScene.instantiate()
	monster.add_sibling(other)
	monster.hue = 280.0
	assert_true(absf(monster.get_hue_shift() - (-177.6)) < 0.01, "280 deg target")
	var mine: ShaderMaterial = monster.skeleton.material
	var theirs: ShaderMaterial = other.skeleton.material
	assert_true(mine != theirs, "each monster has its own material")
	assert_true(absf(float(mine.get_shader_parameter(&"hue_shift")) + 177.6) < 0.01, "shader gets the shift")
	assert_eq(float(theirs.get_shader_parameter(&"hue_shift")), 0.0, "other monster unchanged")
	other.free()


func test_height_scales_the_figure() -> void:
	# buddy-size D1: the bounds follow height_pt.
	var m: Node2D = preload("res://characters/monster/monster.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	var normal: float = m.get_local_bounds().size.y
	m.height_pt = 170.0
	var big: float = m.get_local_bounds().size.y
	assert_true(absf(big / normal - 170.0 / 110.0) < 0.01, "170 pt is 170/110 of 110 pt (%f)" % (big / normal))
	m.free()
