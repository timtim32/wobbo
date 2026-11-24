extends "res://tests/base_test.gd"
## Animation clips and blinking of the Monster (spec "Animation clips", "Idle blinking").

const MonsterScene := preload("res://characters/monster/monster.tscn")
const AvatarMood := preload("res://scripts/core/avatar_mood.gd")
const SessionAvatar := preload("res://scripts/avatars/session_avatar.gd")
const LOOPING: Array[StringName] = [&"idle", &"walk", &"sleep", &"thinking", &"working", &"waiting",
	&"work_hammer", &"work_laptop", &"work_wrench", &"work_papers", &"dangle"]
## Prop node -> the only clip that may show it (work-and-wait D3, D4).
const PROPS := {"arm_r/PropHammer": &"work_hammer", "arm_r/PropWrench": &"work_wrench",
	"PropLaptop": &"work_laptop", "PropPapers": &"work_papers", "PropPage": &"work_papers"}
const ONE_SHOT: Array[StringName] = [&"wave", &"happy", &"error", &"dock_hop", &"land"]

var monster: Node2D


func before_each() -> void:
	monster = MonsterScene.instantiate()
	monster.blink_seed = 1234
	(Engine.get_main_loop() as SceneTree).root.add_child(monster)


func after_each() -> void:
	monster.free()


func test_all_clips_exist_with_loop_modes() -> void:
	for clip in LOOPING:
		assert_true(monster.has_clip(clip), "%s exists" % clip)
		assert_eq(monster.body_player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)
	for clip in ONE_SHOT:
		assert_true(monster.has_clip(clip), "%s exists" % clip)
		assert_eq(monster.body_player.get_animation(clip).loop_mode, Animation.LOOP_NONE, "%s plays once" % clip)
	assert_true(monster.has_clip(&"blink"), "blink exists")
	assert_eq(monster.face_player.get_animation(&"blink").loop_mode, Animation.LOOP_NONE, "blink plays once")


func test_looping_clips_start_and_end_on_the_same_pose() -> void:
	for clip in LOOPING:
		var anim: Animation = monster.body_player.get_animation(clip)
		for t in anim.get_track_count():
			var n := anim.track_get_key_count(t)
			if n < 2:
				continue
			var first: Variant = anim.track_get_key_value(t, 0)
			var last: Variant = anim.track_get_key_value(t, n - 1)
			assert_eq(last, first, "%s %s" % [clip, anim.track_get_path(t)])
			assert_true(is_equal_approx(anim.track_get_key_time(t, n - 1), anim.length),
				"%s %s ends at the clip length" % [clip, anim.track_get_path(t)])


func test_one_shots_return_to_idle() -> void:
	for clip in ONE_SHOT:
		monster.play(clip)
		var length: float = monster.body_player.get_animation(clip).length
		monster.body_player.advance(length + 0.05)
		monster.body_player.advance(0.05)
		assert_eq(monster.current_clip, &"idle", "%s returns to idle" % clip)
		assert_eq(StringName(monster.body_player.current_animation), &"idle", "%s plays idle" % clip)


func test_idle_blinks_irregularly() -> void:
	monster.play(&"idle")
	var times: Array[float] = []
	var t := 0.0
	var last_count: int = monster.blink_count
	while t < 30.0:
		monster.tick_blink(0.05)
		t += 0.05
		if monster.blink_count != last_count:
			times.append(t)
			last_count = monster.blink_count
	assert_true(times.size() >= 5, "several blinks in 30 s (%d)" % times.size())
	var gaps: Array[float] = []
	for i in range(1, times.size()):
		gaps.append(snappedf(times[i] - times[i - 1], 0.05))
	assert_true(gaps.min() >= 1.95 and gaps.max() <= 6.05, "gaps between 2 and 6 s: %s" % [gaps])
	assert_true(gaps.max() - gaps.min() > 0.5, "not a fixed rhythm: %s" % [gaps])


func test_no_blinking_while_asleep() -> void:
	monster.play(&"sleep")
	var before: int = monster.blink_count
	for i in 600:
		monster.tick_blink(0.05)
	assert_eq(monster.blink_count, before, "no blinks in 30 s of sleep")
	var eyelid: Sprite2D = monster.skeleton.get_node("root/body/eye/Eyelid")
	assert_true(eyelid.visible and eyelid.scale.y > 0.99, "eye closed while asleep")
	monster.play(&"idle")
	assert_false(eyelid.visible, "eye opens again after sleep")


func _shown_in(anim: Animation, node: String) -> bool:
	var t := anim.find_track(NodePath("Skeleton2D/root/body/%s:visible" % node), Animation.TYPE_VALUE)
	if t < 0:
		return false
	for k in anim.track_get_key_count(t):
		if anim.track_get_key_value(t, k):
			return true
	return false


func test_props_only_in_their_own_clip() -> void:
	for clip in monster.body_player.get_animation_list():
		var anim: Animation = monster.body_player.get_animation(clip)
		for node: String in PROPS:
			var own: bool = String(clip).trim_suffix("_in").trim_suffix("_out") == String(PROPS[node])
			assert_eq(_shown_in(anim, node), own, "%s in %s" % [node, clip])
	for clip in [&"work_laptop", &"work_papers"]:
		var anim: Animation = monster.body_player.get_animation(clip)
		assert_false(_shown_in(anim, "arm_l/ArmL") or _shown_in(anim, "arm_r/ArmR"), "%s hides the hanging arms" % clip)
		assert_true(_shown_in(anim, "ArmFrontL") and _shown_in(anim, "ArmFrontR"), "%s shows the front arms" % clip)
	assert_true(_shown_in(monster.body_player.get_animation(&"idle"), "arm_l/ArmL"), "idle shows the left arm")


func test_props_start_hidden() -> void:
	for node: String in PROPS:
		assert_false(monster.get_node("Skeleton2D/root/body/" + node).visible, "%s hidden at rest" % node)


func _last(anim: Animation, path: String) -> Variant:
	var t := anim.find_track(NodePath(path), Animation.TYPE_VALUE)
	return anim.track_get_key_value(t, anim.track_get_key_count(t) - 1)


func test_transitions_take_and_put_away() -> void:
	for clip: StringName in PROPS.values():
		var t_in: Animation = monster.body_player.get_animation(StringName(String(clip) + "_in"))
		var t_out: Animation = monster.body_player.get_animation(StringName(String(clip) + "_out"))
		assert_eq(t_in.loop_mode, Animation.LOOP_NONE, "%s_in plays once" % clip)
		assert_eq(t_out.loop_mode, Animation.LOOP_NONE, "%s_out plays once" % clip)
		for node: String in PROPS:
			if PROPS[node] != clip:
				continue
			var path := "Skeleton2D/root/body/%s:visible" % node
			assert_true(_last(t_in, path), "%s_in ends holding %s" % [clip, node])
			assert_false(_last(t_out, path), "%s_out ends with %s away" % [clip, node])
		assert_true(_last(t_out, "Skeleton2D/root/body/arm_l/ArmL:visible"), "%s_out ends with the hanging arms" % clip)
		assert_true(monster.play(StringName(String(clip) + "_in")), "%s_in can be played" % clip)


func test_transitions_end_where_the_loop_starts() -> void:
	for clip in [&"work_hammer", &"work_wrench"]:
		var loop: Animation = monster.body_player.get_animation(clip)
		var t_in: Animation = monster.body_player.get_animation(StringName(String(clip) + "_in"))
		var path := "Skeleton2D/root/body/arm_r:rotation"
		var start: float = loop.track_get_key_value(loop.find_track(NodePath(path), Animation.TYPE_VALUE), 0)
		assert_true(is_equal_approx(float(_last(t_in, path)), start), "%s_in ends in the work pose" % clip)


func test_blended_switch_shows_the_new_clips_arms_and_props() -> void:
	# A blended play() skips discrete keys at time 0; Monster.play sets them itself.
	var b := monster.get_node("Skeleton2D/root/body")
	monster.play(&"work_laptop")
	monster.body_player.advance(0.3)
	monster.play(&"thinking")
	monster.body_player.advance(0.05)
	assert_false(b.get_node("PropLaptop").visible, "laptop gone")
	assert_false(b.get_node("ArmFrontL").visible, "front arms gone")
	assert_true(b.get_node("arm_l/ArmL").visible, "left arm back")
	assert_true(b.get_node("ArmRThink").visible and not b.get_node("arm_r/ArmR").visible, "thinking arm only")
	monster.play(&"work_hammer")
	monster.body_player.advance(0.05)
	assert_true(b.get_node("arm_r/PropHammer").visible and b.get_node("arm_r/ArmR").visible, "hammer in the hand")
	assert_false(b.get_node("ArmRThink").visible, "no third arm")
	assert_true(b.get_node("mouth/MouthNeutral").visible, "the new clip's mouth")


## The clip names an avatar asks for are written in AvatarMood and SessionAvatar,
## separately from Monster's lists (codebase-cleanup F15): each must exist there.
func test_every_clip_an_avatar_plays_exists() -> void:
	var known: Array = Monster.LOOPING_CLIPS + Monster.ONE_SHOT_CLIPS
	var played: Array = [&"idle", &"walk", &"sleep", &"wave"] # written out in AvatarMood.update() and leave()
	played.append_array(AvatarMood.STATE_CLIPS.values())
	played.append_array(AvatarMood.REACTIONS.values())
	played.append_array(AvatarMood.WORK_CLIPS)
	played.append_array([SessionAvatar.HOP_CLIP, SessionAvatar.DANGLE_CLIP, SessionAvatar.LAND_CLIP])
	for clip: StringName in played:
		assert_true(clip in known, "%s is in Monster's clip lists" % clip)
		assert_true(monster.has_clip(clip), "%s has an animation" % clip)
	for clip: StringName in AvatarMood.WORK_CLIPS:
		if clip == &"working":
			continue # the plain way of working has no prop, so no transitions
		for suffix in ["_in", "_out"]:
			var transition := StringName(String(clip) + suffix)
			assert_true(transition in Monster.ONE_SHOT_CLIPS, "%s is a one-shot clip" % transition)
			assert_true(monster.has_clip(transition), "%s has an animation" % transition)
