class_name Monster
extends Node2D
## The buddy character (spec avatar-character, character-rig D3-D7).
##
## The rig is a Skeleton2D with rigid parts. Part textures, sprite offsets and
## bone rest positions come from res://assets/monster/manifest.json, so a
## re-exported SVG updates the rig without editing this scene. The Monster's
## origin is the point between its feet.
##
## API: play(clip), face_left() / face_right(), look_at_point() /
## clear_look_target(), hue, get_local_bounds(). Signal clip_finished(clip).

signal clip_finished(clip: StringName)

const LookMath := preload("res://characters/monster/look_math.gd")
const MANIFEST_PATH := "res://assets/monster/manifest.json"
const PARTS_DIR := "res://assets/monster/parts/"

const DISPLAY_HEIGHT_PT := 110.0
## Hue of the skin green #6DB045, in degrees. Monster.hue is a target hue.
const BASE_SKIN_HUE := 97.6
## Pupil travel from the eye centre, in export pixels (white radius minus pupil radius, minus a margin).
const LOOK_MAX_OFFSET := 22.0
const LOOK_EASE := 10.0
const BLINK_MIN_SEC := 2.0
const BLINK_MAX_SEC := 6.0

const LOOPING_CLIPS: Array[StringName] = [&"idle", &"walk", &"sleep", &"thinking", &"working", &"waiting",
	&"work_hammer", &"work_laptop", &"work_wrench", &"work_papers", &"dangle"]
const ONE_SHOT_CLIPS: Array[StringName] = [&"wave", &"happy", &"error", &"dock_hop", &"land",
	&"work_hammer_in", &"work_hammer_out", &"work_laptop_in", &"work_laptop_out",
	&"work_wrench_in", &"work_wrench_out", &"work_papers_in", &"work_papers_out"]
const FACE_CLIPS: Array[StringName] = [&"blink"]

## Bone -> [parent bone, part whose pivot is the bone's joint]. "" = the origin.
const BONES := {
	&"root": [&"", ""],
	&"leg_l": [&"root", "leg_l"],
	&"leg_r": [&"root", "leg_r"],
	&"body": [&"root", "body"],
	&"arm_l": [&"body", "arm_l"],
	&"arm_r": [&"body", "arm_r"],
	&"ear_l": [&"body", "ear_l"],
	&"ear_r": [&"body", "ear_r"],
	&"eye": [&"body", "eye_white"],
	&"mouth": [&"body", "mouth_neutral"],
}

## Part -> sprite node path (relative to Skeleton2D) and the bone it hangs on.
const PARTS := {
	"leg_l": ["root/leg_l/LegL", &"leg_l"],
	"leg_r": ["root/leg_r/LegR", &"leg_r"],
	"arm_l": ["root/body/arm_l/ArmL", &"arm_l"],
	"arm_r": ["root/body/arm_r/ArmR", &"arm_r"],
	"ear_l": ["root/body/ear_l/EarL", &"ear_l"],
	"ear_r": ["root/body/ear_r/EarR", &"ear_r"],
	"body": ["root/body/Body", &"body"],
	"spots": ["root/body/Spots", &"body"],
	"cheeks": ["root/body/Cheeks", &"body"],
	"eye_white": ["root/body/eye/EyeWhite", &"eye"],
	"pupil": ["root/body/eye/Look/Pupil", &"eye"],
	"eyelid": ["root/body/eye/Eyelid", &"eye"],
	"brows": ["root/body/eye/Brows", &"eye"],
	"mouth_neutral": ["root/body/mouth/MouthNeutral", &"mouth"],
	"mouth_smile": ["root/body/mouth/MouthSmile", &"mouth"],
	"mouth_open": ["root/body/mouth/MouthOpen", &"mouth"],
	"mouth_laugh": ["root/body/mouth/MouthLaugh", &"mouth"],
	"arm_r_think": ["root/body/ArmRThink", &"body"],
	"fangs": ["root/body/mouth/Fangs", &"mouth"],
	# work-and-wait D3: props and front arms, hidden unless a work clip shows them.
	"prop_hammer": ["root/body/arm_r/PropHammer", &"arm_r"],
	"prop_wrench": ["root/body/arm_r/PropWrench", &"arm_r"],
	"arm_front_l": ["root/body/ArmFrontL", &"body"],
	"arm_front_r": ["root/body/ArmFrontR", &"body"],
	"prop_laptop": ["root/body/PropLaptop", &"body"],
	"prop_papers": ["root/body/PropPapers", &"body"],
	"prop_page": ["root/body/PropPage", &"body"],
}

## Target hue in degrees; a negative value means "unset" (original greens).
@export var hue: float = -1.0:
	set(value):
		hue = value
		_apply_hue()
## Height of the figure in points (buddy-size D1); the menu's Size sets it.
@export var height_pt: float = DISPLAY_HEIGHT_PT:
	set(value):
		height_pt = value
		if skeleton:
			_apply_scale()
## Extra pupil direction set by clips (-1..1 per axis), added to the look target.
@export var pupil_bias := Vector2.ZERO
## Seed for the blink timer; 0 = random. Used by tests.
@export var blink_seed: int = 0

## The body clip that is playing (or was last asked for).
var current_clip: StringName = &""
## 1 = facing right (as drawn), -1 = facing left (mirrored).
var facing := 1
var blink_count := 0
## A mirror view copies another monster each frame (multi-display D3) and does
## not blink or ease its pupil on its own.
var mirroring := false

var _manifest: Dictionary
var _origin := Vector2.ZERO
var _figure_rect := Rect2()
var _look_target: Variant = null
var _blink_left := 0.0
var _rng := RandomNumberGenerator.new()

@onready var skeleton: Skeleton2D = $Skeleton2D
@onready var body_player: AnimationPlayer = $BodyPlayer
@onready var face_player: AnimationPlayer = $FacePlayer
@onready var _look: Node2D = $Skeleton2D/root/body/eye/Look
@onready var _eyelid: Sprite2D = $Skeleton2D/root/body/eye/Eyelid


func _ready() -> void:
	if blink_seed != 0:
		_rng.seed = blink_seed
	_build_rig()
	skeleton.material = skeleton.material.duplicate()
	_apply_hue()
	_apply_scale()
	var overlay := get_node_or_null("/root/Overlay")
	if overlay:
		overlay.layout_changed.connect(func(_old: Variant) -> void: _apply_scale())
	body_player.animation_finished.connect(_on_body_finished)
	_schedule_blink()
	play(&"idle")


func _process(delta: float) -> void:
	if mirroring:
		return
	_update_look(delta)
	tick_blink(delta)


## Copies pose and expression from `src` (another view of the same buddy).
func mirror(src) -> void:
	mirroring = true
	if src.current_clip != current_clip and src.current_clip != &"":
		play(src.current_clip)
	var anim: String = src.body_player.current_animation
	if not anim.is_empty():
		if body_player.current_animation != anim:
			body_player.play(anim, 0.0)
		if absf(body_player.current_animation_position - src.body_player.current_animation_position) > 0.02:
			body_player.seek(src.body_player.current_animation_position, true)
		_apply_discrete(body_player.get_animation(anim), src.body_player.current_animation_position)
	var face: String = src.face_player.current_animation
	if not face.is_empty():
		if face_player.current_animation != face:
			face_player.play(face)
		face_player.seek(src.face_player.current_animation_position, true)
	_eyelid.visible = src._eyelid.visible
	_eyelid.scale = src._eyelid.scale
	_look.position = src._look.position
	if hue != src.hue:
		hue = src.hue
	if height_pt != src.height_pt:
		height_pt = src.height_pt
	if facing != src.facing:
		set_facing(src.facing)


# --- Rig (character-rig D3) ------------------------------------------------

func _build_rig() -> void:
	_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var parts: Dictionary = _manifest.parts
	var fr: Array = _manifest.figure_rect
	_figure_rect = Rect2(fr[0], fr[1], fr[2], fr[3])
	_origin = Vector2(_pivot(parts, "body").x, _figure_rect.end.y)
	# Bones: rest position relative to the parent bone's joint.
	for bone_name: StringName in BONES:
		var bone: Bone2D = skeleton.get_node(_bone_path(bone_name))
		var joint := _bone_joint(parts, bone_name)
		var parent: StringName = BONES[bone_name][0]
		var parent_joint := _bone_joint(parts, parent) if parent != &"" else _origin
		bone.position = joint - parent_joint
		bone.rotation = 0.0
		bone.scale = Vector2.ONE
		bone.rest = bone.transform
	# Sprites: placed at their own pivot, texture offset so the pivot is the joint.
	for part: String in PARTS:
		var sprite: Sprite2D = skeleton.get_node(PARTS[part][0])
		var info: Dictionary = parts[part]
		var pivot := _pivot(parts, part)
		var rect := Rect2(info.rect[0], info.rect[1], info.rect[2], info.rect[3])
		var bone_joint := _bone_joint(parts, PARTS[part][1])
		var holder := sprite.get_parent() as Node2D
		var holder_offset := Vector2.ZERO if holder is Bone2D else holder.position
		sprite.texture = load(PARTS_DIR + part + ".png")
		sprite.centered = false
		sprite.position = pivot - bone_joint - holder_offset
		sprite.offset = rect.position - pivot
		sprite.visible = info.visible
	_eyelid.scale = Vector2(1.0, 0.01)
	_eyelid.visible = false
	# One material for the whole monster; every canvas item uses its parent's.
	for node in skeleton.find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).use_parent_material = true
	# The blush stays pink on every colour, so it skips the hue shift.
	(skeleton.get_node(PARTS["cheeks"][0]) as CanvasItem).use_parent_material = false
	skeleton.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _bone_path(bone_name: StringName) -> NodePath:
	var path := String(bone_name)
	var parent: StringName = BONES[bone_name][0]
	while parent != &"":
		path = String(parent) + "/" + path
		parent = BONES[parent][0]
	return NodePath(path)


func _bone_joint(parts: Dictionary, bone_name: StringName) -> Vector2:
	var part: String = BONES[bone_name][1]
	return _origin if part.is_empty() else _pivot(parts, part)


func _pivot(parts: Dictionary, part: String) -> Vector2:
	var p: Array = parts[part].pivot
	return Vector2(p[0], p[1])


## Pixels per export pixel at the default display height.
func display_scale() -> float:
	var px := height_pt
	var overlay := get_node_or_null("/root/Overlay")
	if overlay:
		px = overlay.points_to_px(height_pt)
	return px / _figure_rect.size.y


func _apply_scale() -> void:
	var s := display_scale()
	skeleton.scale = Vector2(s * facing, s)


## The figure's bounding box in this node's local coordinates (no animation).
func get_local_bounds() -> Rect2:
	var s := display_scale()
	var r := Rect2((_figure_rect.position - _origin) * s, _figure_rect.size * s)
	if facing < 0:
		r.position.x = -r.end.x
	return r


# --- Facing (spec "Facing direction") ---------------------------------------

func face_left() -> void:
	set_facing(-1)


func face_right() -> void:
	set_facing(1)


func set_facing(direction: int) -> void:
	facing = -1 if direction < 0 else 1
	_apply_scale()


# --- Colour (character-rig D6) ----------------------------------------------

## The hue rotation in degrees that the shader applies (0 when hue is unset).
func get_hue_shift() -> float:
	return 0.0 if hue < 0.0 else wrapf(hue - BASE_SKIN_HUE, -180.0, 180.0)


func _apply_hue() -> void:
	if skeleton and skeleton.material:
		(skeleton.material as ShaderMaterial).set_shader_parameter(&"hue_shift", get_hue_shift())


# --- Eye (character-rig D5) -------------------------------------------------

func look_at_point(global_point: Vector2) -> void:
	_look_target = global_point


func clear_look_target() -> void:
	_look_target = null


func _update_look(delta: float) -> void:
	var goal := Vector2.ZERO
	if _look_target != null:
		var eye: Node2D = _look.get_parent()
		goal = LookMath.pupil_offset(eye.to_local(_look_target), LOOK_MAX_OFFSET)
	goal = (goal + pupil_bias * LOOK_MAX_OFFSET).limit_length(LOOK_MAX_OFFSET)
	_look.position = _look.position.lerp(goal, 1.0 - exp(-LOOK_EASE * delta))


# --- Clips (character-rig D4) -----------------------------------------------

## Plays a clip. Returns false (and logs a warning) for an unknown clip, in
## which case nothing changes.
func play(clip: StringName) -> bool:
	if clip in FACE_CLIPS:
		if current_clip == &"sleep":
			return true # eyes are closed anyway
		face_player.stop()
		face_player.play(clip)
		blink_count += 1
		return true
	if not (clip in LOOPING_CLIPS or clip in ONE_SHOT_CLIPS) or not body_player.has_animation(clip):
		push_warning("Monster: unknown clip '%s'" % clip)
		return false
	_set_eyes_closed(clip == &"sleep")
	current_clip = clip
	body_player.play(clip)
	_apply_discrete(body_player.get_animation(clip), 0.0)
	return true


## Sets the switching tracks (which arm, prop and mouth is visible) of `anim`
## at `time` right away. A blended play() does not apply discrete keys at time 0,
## so the previous clip's arms and props would stay visible (work-and-wait).
func _apply_discrete(anim: Animation, time: float) -> void:
	if anim == null:
		return
	var root := body_player.get_node(body_player.root_node)
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_VALUE \
				or anim.value_track_get_update_mode(t) != Animation.UPDATE_DISCRETE:
			continue
		var path := anim.track_get_path(t)
		var node := root.get_node_or_null(NodePath(path.get_concatenated_names()))
		if node:
			node.set_indexed(NodePath(path.get_concatenated_subnames()), anim.value_track_interpolate(t, time))


func has_clip(clip: StringName) -> bool:
	if clip in FACE_CLIPS:
		return face_player.has_animation(clip)
	return body_player.has_animation(clip)


func _on_body_finished(clip: StringName) -> void:
	if clip in ONE_SHOT_CLIPS and clip == current_clip:
		play(&"idle")
	clip_finished.emit(clip)


func _set_eyes_closed(closed: bool) -> void:
	face_player.stop()
	_eyelid.visible = closed
	_eyelid.scale = Vector2(1.0, 1.0 if closed else 0.01)


## Advances the auto-blink timer (spec "Idle blinking"). No blinking while asleep.
func tick_blink(delta: float) -> void:
	if current_clip == &"sleep":
		return
	_blink_left -= delta
	if _blink_left <= 0.0:
		play(&"blink")
		_schedule_blink()


func _schedule_blink() -> void:
	_blink_left = _rng.randf_range(BLINK_MIN_SEC, BLINK_MAX_SEC)
