extends Node2D
## Monster preview (character-rig D8): one monster per clip along the overlay strip,
## labelled, with hues spread around the colour wheel and pupils that follow
## the cursor. Run with project_run(mode="custom", scene=".../monster_preview.tscn").
## Nothing in it is clickable, so the whole strip stays click-through.

const MonsterScene := preload("res://characters/monster/monster.tscn")
const CLIPS: Array[StringName] = [&"idle", &"walk", &"wave", &"sleep", &"thinking",
	&"working", &"happy", &"error", &"waiting", &"dock_hop", &"dangle", &"land", &"blink"]
## Pause before a one-shot clip is played again.
const REPLAY_DELAY_SEC := 1.2
## Candidate skin hues for the avatars (session-avatars spike S2), shown by
## hue_preview.tscn: all idle, labelled with their hue.
const HUE_CANDIDATES: Array[float] = [97.6, 150.0, 180.0, 205.0, 235.0, 265.0, 295.0, 330.0, 355.0, 25.0]

@export var show_hues := false
## Shows waiting and the work clips instead (work-and-wait spike S1).
@export var show_work := false
const WORK_CLIPS: Array[StringName] = [&"waiting", &"working", &"work_hammer", &"work_laptop", &"work_wrench",
	&"work_papers"]

var monsters: Array[Node2D] = []
var _labels: Array[Label] = []


func _ready() -> void:
	var clips: Array[StringName] = WORK_CLIPS if show_work else CLIPS
	for i in clips.size():
		var m: Node2D = MonsterScene.instantiate()
		m.name = "Monster_%s" % clips[i]
		m.hue = HUE_CANDIDATES[i] if show_hues else fmod(97.6 + i * 36.0, 360.0)
		add_child(m)
		monsters.append(m)
		var label := Label.new()
		label.text = ("hue %.0f" % HUE_CANDIDATES[i]) if show_hues else String(clips[i])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", int(Overlay.points_to_px(3)))
		label.add_theme_font_size_override("font_size", int(Overlay.points_to_px(13)))
		add_child(label)
		_labels.append(label)
		m.clip_finished.connect(_on_clip_finished.bind(m, clips[i]))
		_start(m, &"idle" if show_hues else clips[i])
	Overlay.layout_changed.connect(func(_old: Variant) -> void: _layout())
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var step := size.x / monsters.size()
	for i in monsters.size():
		var m := monsters[i]
		m.position = Vector2(step * (i + 0.5), size.y - Overlay.points_to_px(8))
		var bounds: Rect2 = m.get_local_bounds()
		var label := _labels[i]
		label.size = Vector2(step, Overlay.points_to_px(20))
		label.position = Vector2(step * i, m.position.y + bounds.position.y - Overlay.points_to_px(28))


func _start(m: Node2D, clip: StringName) -> void:
	if clip == &"blink":
		m.play(&"idle")
		m.set_process(true)
		_blink_forever(m)
	elif show_work and m.has_clip(StringName(String(clip) + "_in")):
		m.play(StringName(String(clip) + "_in")) # take the prop; _on_clip_finished goes on
	else:
		m.play(clip)


## Work preview: take the prop, work for a while, put it away, pause, again.
func _work_cycle(m: Node2D, clip: StringName, finished: StringName) -> void:
	if finished == StringName(String(clip) + "_in"):
		m.play(clip)
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(m):
			m.play(StringName(String(clip) + "_out"))
	elif finished == StringName(String(clip) + "_out"):
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(m):
			m.play(StringName(String(clip) + "_in"))


func _blink_forever(m: Node2D) -> void:
	while is_instance_valid(m):
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(m):
			m.play(&"blink")


func _on_clip_finished(finished: StringName, m: Node2D, clip: StringName) -> void:
	if show_work:
		_work_cycle(m, clip, finished)
		return
	if finished == clip and clip in [&"wave", &"happy", &"error", &"dock_hop"]:
		await get_tree().create_timer(REPLAY_DELAY_SEC).timeout
		if is_instance_valid(m):
			m.play(clip)


func _process(_delta: float) -> void:
	var cursor := Vector2(DisplayServer.mouse_get_position() - DisplayServer.window_get_position())
	for m in monsters:
		m.look_at_point(cursor)
