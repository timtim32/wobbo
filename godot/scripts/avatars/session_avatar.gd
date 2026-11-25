extends "res://scripts/walkway/walkway_body.gd"
## The avatar of one agent session (session-avatars design D4): a walkway body
## that does what its AvatarMood says. It walks in to its slot on the home
## display, strolls or stands there, travels along when the home display
## changes, and walks off beyond the nearest end of the walkway when it leaves.

signal gone(avatar: Node)
## A dropped buddy touched the floor at walkway x (buddy-drag D5).
signal landed(avatar: Node, x: float)

const Mood := preload("res://scripts/core/avatar_mood.gd")
const Cast := preload("res://scripts/core/avatar_cast.gd")
const SessionRegistry := preload("res://scripts/core/session_registry.gd")
const BuddySize := preload("res://scripts/core/buddy_size.gd")
const NameLabel := preload("res://scripts/avatars/name_label.gd")
const DockHop := preload("res://scripts/core/dock_hop.gd")
const SwingPhysics := preload("res://scripts/core/swing_physics.gd")
const Balloon := preload("res://scripts/avatars/balloon.gd")
const BalloonLayout := preload("res://scripts/core/balloon_layout.gd")

const STROLL_SPEED_PT := 60.0
const WALK_SPEED_PT := 180.0 # walking in and off: like travelling, a wide display takes ~10 s
const TRAVEL_SPEED_PT := 180.0
const BOTTOM_GAP_PT := 8.0
const MARGIN_PT := 4.0 # region slightly larger than the art (overlay-window risk S1)
const ARRIVE_PT := 2.0
## How far beyond the end of the walkway a buddy starts when it walks in (at Normal size).
const ENTER_OFFSET_PT := 60.0
## How far beyond the end of the walkway a leaving buddy walks before it is gone.
const EXIT_MARGIN_PT := 4.0
## The jump clip played on each hop onto or off the Dock (dock-dodge D4).
const HOP_CLIP: StringName = &"dock_hop"
const HOP_CLIP_SEC := 0.36
## Clips while carried and on landing (buddy-drag D4, D7).
const DANGLE_CLIP: StringName = &"dangle"
const LAND_CLIP: StringName = &"land"
const LAND_CLIP_SEC := 0.35
## Climbing between stacked displays (side-climb D3).
const CLIMB_CLIP: StringName = &"climb"
const CLIMB_SPEED_PT := 150.0
## Jumping down from the upper display: launch speed (inwards, upwards, at
## Normal size) and spin in turns per second, like a thrown buddy.
const JUMP_VX_PT := 140.0
const JUMP_VY_PT := 420.0
const JUMP_SPIN_TURNS := 1.1

var session_id := ""
var display_name := ""
var slot := 0
var slots := Cast.MAX_AVATARS
var region_id: StringName
var mood: Mood
## Set every frame by the Messages node (balloons-and-speech D1, D5).
var messages: Node = null
var balloon_content := {}
var balloon_region_id: StringName

var _state: StringName = &"idle"
var _activity_msec := 0
var _dir := 1.0
var _exit_x := NAN
var _gone := false
var _labels := {} # strip index -> NameLabel (session-avatars D5)
var _hop := DockHop.new()
var _lift := 0.0 # points above the floor, to stand on the shown Dock (dock-dodge D4)
var _hop_clip_left := 0.0
var _swing := SwingPhysics.new()
## &"" (on its own feet), &"held", &"falling" or &"landing" (buddy-drag D4).
var _carry: StringName = &""
## Position at the previous frame, and whether it changed (is_moving()).
var _prev_position := Vector2.INF
var _moving := false
var _land_clip_left := 0.0
var _balloon: Balloon = null
var _balloon_shown := false
## The climb in progress (side-climb D3), or empty: {link, side, lower_id, up,
## y: feet height in walkway y of the lower strip, goal: the same for the end}.
var _climb := {}
## The side chosen for the next climb link of the current trip (Walkway.ClimbSide).
var _route_side: Variant = null
## The jump down in progress, or empty: {link, lower_id}. The body falls as a
## thrown buddy (_carry = &"falling") onto the lower display's floor.
var _jump := {}


## Called before the avatar enters the tree.
func setup(session: SessionRegistry.Session, p_slot: int, p_hue: float, p_slots: int) -> void:
	session_id = session.id
	display_name = session.name
	slot = p_slot
	slots = p_slots
	hue = p_hue
	height_pt = BuddySize.height_of(Settings.buddy_size)
	_state = session.state
	_activity_msec = session.updated_msec
	region_id = StringName("avatar:" + session_id)
	balloon_region_id = StringName("balloon:" + session_id)
	name = "Avatar_" + session_id.validate_node_name()
	mood = Mood.new(_state, session_id.hash())


func _ready() -> void:
	super()
	clip_finished.connect(func(clip: StringName) -> void: mood.one_shot_finished(clip))
	Overlay.content_visibility_changed.connect(func(_v: bool) -> void: _update_label_visibility())
	Settings.changed.connect(func(key: StringName, value: Variant) -> void:
		if key == &"buddy_size":
			height_pt = BuddySize.height_of(String(value)) # buddy-size D3
		if key == &"show_names":
			_update_label_visibility())
	var seg := _home_segment()
	if seg:
		# Start just beyond the end of the walkway nearest to the slot: an outer
		# edge with no display beyond it, so it never pops up mid-screen.
		# Next to a climb route, the nearer end of the home display's run (side-climb D6).
		var home: int = Overlay.home_index()
		var run: Vector2 = Overlay.walkway.run_bounds(home)
		var slot_x := _slot_x(seg)
		var from_left: bool = slot_x - run.x < run.y - slot_x
		var off := ENTER_OFFSET_PT * _speed_scale()
		position = Vector2(run.x - off if from_left else run.y + off, _floor_y())
		_dir = 1.0 if from_left else -1.0
		only_run = home
	play(&"walk")


func leave(wave: bool) -> void:
	mood.leave(wave)


func is_going() -> bool:
	return mood.is_going()


## Whether it moved in the last frame (walking, travelling to another display,
## hopping, carried), so the frame rate stays up for it even while it sleeps.
func is_moving() -> bool:
	return _moving


## Whether a press may pick this buddy up: not while it walks off (buddy-drag spec).
func can_grab() -> bool:
	return not _gone and not is_going() and not is_climbing() and _jump.is_empty()


## True while it climbs between stacked displays (side-climb D3).
func is_climbing() -> bool:
	return not _climb.is_empty()


## Picks the buddy up at walkway point `point` on its body. Also catches a falling buddy.
func grab(point: Vector2) -> bool:
	if not can_grab():
		return false
	var b := bounds_pt()
	_swing.grab(position, tilt, point, b.get_center(), b.size.y)
	_carry = &"held"
	_land_clip_left = 0.0
	play(DANGLE_CLIP)
	_update_label_visibility()
	return true


## Lets go of a held buddy: it flies on and falls (buddy-drag D2).
func drop() -> void:
	if _carry == &"held":
		_swing.release()
		_carry = &"falling"


## &"" while on its own feet, else &"held", &"falling" or &"landing".
func carry_phase() -> StringName:
	return _carry


func is_carried() -> bool:
	return _carry != &""


## Ends a carry at once, standing on the floor below (a display change mid-drag).
func _abort_carry() -> void:
	_carry = &""
	tilt = 0.0
	position.y = _floor_y()
	_swing = SwingPhysics.new()
	_update_label_visibility()


func _on_layout_changed(old_walkway: Variant) -> void:
	super(old_walkway)
	if _carry != &"":
		_abort_carry()
	if is_climbing():
		_end_climb() # it stands on the floor below (side-climb D6)
	_end_jump()
	_route_side = null
	only_run = -1


## Walking speeds scale with the size, so the stride matches the ground (buddy-size D3).
func _speed_scale() -> float:
	return height_pt / BuddySize.height_of(BuddySize.DEFAULT)


func _home_segment() -> Walkway.Segment:
	if Overlay.walkway.is_empty():
		return null
	return Overlay.walkway.segments[Overlay.home_index()]


func _slot_x(seg: Walkway.Segment) -> float:
	return Cast.slot_center(seg.start, seg.width, slots, mini(slot, slots - 1))


func _floor_y() -> float:
	return Overlay.strip_height_pt() - BOTTOM_GAP_PT - _lift


## Hops onto the Dock while it is shown under the avatar, and back down when it
## hides or the avatar walks off its end (dock-dodge D4), never so high that the head or label leaves the strip.
func _update_lift(delta: float) -> void:
	var on_floor := Overlay.strip_height_pt() - BOTTOM_GAP_PT
	var ceiling := DockHop.max_lift(on_floor, bounds_pt().position.y, NameLabel.HEIGHT_PT + NameLabel.GAP_PT)
	var hops := _hop.hops
	var half := half_width()
	var target := Overlay.dock_lift_pt(Overlay.walkway.index_at(position.x), position.x - half, position.x + half)
	_lift = _hop.step(target, ceiling, delta)
	if _hop.hops != hops:
		_hop_clip_left = HOP_CLIP_SEC
	else:
		_hop_clip_left = maxf(0.0, _hop_clip_left - delta)


## Moves towards x; returns true when there.
func _walk_to(x: float, speed: float, delta: float) -> bool:
	var d := x - position.x
	if absf(d) <= ARRIVE_PT:
		position.x = x
		return true
	_dir = signf(d)
	position.x += _dir * minf(speed * delta, absf(d))
	return false


func _process(delta: float) -> void:
	_moving = position != _prev_position or _carry != &""
	_prev_position = position
	var seg := _home_segment()
	if seg == null or _gone:
		return
	var s: SessionRegistry.Session = Bridge.registry.get_session(session_id)
	if s:
		_state = s.state
		_activity_msec = s.updated_msec
	if _carry != &"":
		_process_carry(delta)
		return
	var half := half_width()
	var target := _slot_x(seg)
	if mood.phase == &"home" and Overlay.walkway.direction_to(Overlay.home_index(), position.x, half) != 0:
		mood.travel() # the home display changed (multi-display D7)
	var out: Dictionary = mood.update(_state, _activity_msec, Time.get_ticks_msec())
	if is_climbing():
		# A climb is finished first, whatever the mood wants meanwhile (side-climb D3).
		_step_climb(delta)
		if is_climbing():
			if current_clip() != CLIMB_CLIP:
				play(CLIMB_CLIP)
			_finish_frame(delta)
			return
		out.motion = &"none"
	match out.motion:
		&"walk_in":
			if _walk_to(target, WALK_SPEED_PT * _speed_scale(), delta):
				only_run = -1
				mood.arrive()
		&"travel":
			if _travel(target, delta):
				_route_side = null
				mood.arrive()
		&"walk_off":
			if is_nan(_exit_x):
				# Leave beyond the nearest end of the walkway, across other displays if
				# needed, but never over a climb route (side-climb D6).
				_exit_x = Overlay.walkway.exit_x(position.x, half, EXIT_MARGIN_PT)
				only_run = Overlay.walkway.index_at(position.x)
			if _walk_to(_exit_x, WALK_SPEED_PT * _speed_scale(), delta):
				_gone = true
				Overlay.remove_region(region_id)
				gone.emit(self)
				return
		&"stroll":
			var r := Cast.stroll_range(seg.width, slots, half)
			if absf(position.x - target) > r + ARRIVE_PT:
				_walk_to(target, STROLL_SPEED_PT * _speed_scale(), delta) # back into its own slot, no jump
			else:
				position.x += _dir * STROLL_SPEED_PT * _speed_scale() * delta
				if position.x > target + r:
					position.x = target + r
					_dir = -1.0
				elif position.x < target - r:
					position.x = target - r
					_dir = 1.0
	_update_lift(delta)
	_land_clip_left = maxf(0.0, _land_clip_left - delta)
	# The jump and landing clips win while they play; the mood's clip (re)starts afterwards.
	var clip: StringName = out.clip
	if _hop_clip_left > 0.0:
		clip = HOP_CLIP
	elif _land_clip_left > 0.0:
		clip = LAND_CLIP
	if clip != current_clip():
		play(clip)
	position.y = _floor_y()
	_finish_frame(delta)


func _finish_frame(delta: float) -> void:
	set_facing(int(_dir))
	look_target = Vector2(DisplayServer.mouse_get_position())
	super._process(delta)
	_place_labels()
	Overlay.set_region(region_id, rect_pt().grow(MARGIN_PT))
	_update_balloon()


# --- Climbing between stacked displays (side-climb D2, D3) ------------------------

## One frame of travelling to walkway x `target` on the home display, over climb
## routes where the way leads; returns true on arrival.
func _travel(target: float, delta: float) -> bool:
	var w: Walkway = Overlay.walkway
	var from: int = w.index_at(position.x)
	var to: int = Overlay.home_index()
	var step: Dictionary = w.next_step(from, position.x, to, target, half_width(), _route_side)
	if step.kind == &"climb":
		_start_climb(step.link, step.side, from)
		return false
	if step.has("side"):
		_route_side = step.side
	var there := _walk_to(step.x, TRAVEL_SPEED_PT * _speed_scale(), delta)
	return there and from == to and is_equal_approx(step.x, target)


func _start_climb(link: Walkway.Link, side: Walkway.ClimbSide, from: int) -> void:
	var up := from == link.lower
	if not up:
		_start_jump(link, side)
		return
	var floor_y := Overlay.strip_height_pt() - BOTTOM_GAP_PT
	# Heights in walkway y of the lower strip; the upper floor is upper_dy higher.
	var y := position.y if up else position.y - link.upper_dy
	var goal := floor_y - link.upper_dy if up else floor_y
	_climb = {"link": link, "side": side, "lower_id": Overlay.walkway.segments[link.lower].id,
		"up": up, "y": y, "goal": goal}
	_route_side = null
	_lift = 0.0
	_dir = float(side.dir)
	Overlay.begin_climb_room(link.lower)
	play(CLIMB_CLIP)
	_update_label_visibility()


func _step_climb(delta: float) -> void:
	var link: Walkway.Link = _climb.link
	var side: Walkway.ClimbSide = _climb.side
	var y: float = move_toward(_climb.y, _climb.goal, CLIMB_SPEED_PT * _speed_scale() * delta)
	_climb.y = y
	_dir = float(side.dir)
	var half := half_width()
	if y > link.top_y:
		position = Vector2(side.body_x(false, half), y) # on the lower display
	else:
		position = Vector2(side.body_x(true, half), y + link.upper_dy) # over its top edge
	if is_equal_approx(y, _climb.goal):
		var up: bool = _climb.up
		_end_climb()
		if up:
			_hop_clip_left = HOP_CLIP_SEC # the step up onto the floor
		else:
			_land_clip_left = LAND_CLIP_SEC


## Jumps off the upper display at the top of the side edge and falls, spinning,
## onto the lower display's floor, like a thrown buddy.
func _start_jump(link: Walkway.Link, side: Walkway.ClimbSide) -> void:
	var half := half_width()
	position = Vector2(side.body_x(false, half), position.y - link.upper_dy) # same spot, lower strip
	_jump = {"link": link, "lower_id": Overlay.walkway.segments[link.lower].id}
	_route_side = null
	_lift = 0.0
	Overlay.begin_climb_room(link.lower)
	var inward := -side.dir
	var b := bounds_pt()
	var scale := _speed_scale()
	_swing = SwingPhysics.new()
	_swing.throw(position, b.get_center(), b.size.y, Vector2(inward * JUMP_VX_PT, -JUMP_VY_PT) * scale,
		inward * JUMP_SPIN_TURNS * TAU)
	_dir = float(inward)
	_carry = &"falling"
	play(DANGLE_CLIP)
	_update_label_visibility()


func _end_jump() -> void:
	if _jump.is_empty():
		return
	var i: int = Overlay.walkway.index_of(_jump.lower_id)
	if i >= 0:
		Overlay.end_climb_room(i)
	_jump = {}


## Ends a climb where the body is; it stands on that floor from the next frame.
func _end_climb() -> void:
	var i: int = Overlay.walkway.index_of(_climb.lower_id)
	if i >= 0:
		Overlay.end_climb_room(i)
	_climb = {}
	_update_label_visibility()


func _extra_strips() -> Array[int]:
	if not is_climbing() and _jump.is_empty() and _carry == &"":
		return []
	# Climbing, jumping or carried: also drawn on the displays over the seam.
	var here: int = Overlay.walkway.index_at(position.x)
	var out: Array[int] = []
	for link in Overlay.walkway.climb_links_of(here):
		out.append(link.upper if here == link.lower else link.lower)
	return out


## Held, falling or landing (buddy-drag D4): the swing moves the body; the mood
## waits and takes over again once the buddy stands.
func _process_carry(delta: float) -> void:
	var w: Walkway = Overlay.walkway
	var strip: int = w.index_at(position.x)
	var half := half_width()
	# Within the run of displays it is on: side by side as before, but not over a
	# climb route sideways. Upwards it may leave the top where a display stands
	# on this one (side-climb).
	var run: Vector2 = w.run_bounds(strip)
	var top := -1.0e6 if w.open_above(strip, position.x, half) or not _jump.is_empty() else -Overlay.headroom_pt(strip)
	var limits := Rect2(run.x, top, run.y - run.x, 0.0)
	var target: Vector2 = Overlay.pointer_pt()
	if not w.same_run(w.index_at(target.x), strip):
		target = Overlay.pointer_on(strip)
	_update_lift(delta)
	_swing.step(delta, target, limits, _floor_y())
	if _jump.is_empty():
		var seam: Dictionary = w.over_seam(strip, _swing.feet, half, Overlay.strip_height_pt())
		if seam.strip != strip:
			_swing.shift(seam.point - _swing.feet)
	position = _swing.feet
	tilt = _swing.tilt
	if _carry == &"falling" and _swing.mode == &"landing":
		_carry = &"landing"
		_land_clip_left = LAND_CLIP_SEC
		play(LAND_CLIP)
		if _jump.is_empty():
			landed.emit(self, position.x) # a jump down keeps its slot
	elif _carry == &"landing" and _swing.mode == &"rest" and not _jump.is_empty():
		_end_jump()
		_carry = &""
		tilt = 0.0
		_update_label_visibility()
	elif _carry == &"landing" and _swing.mode == &"rest":
		_carry = &"" # the mood takes over next frame; `land` keeps playing until done
		tilt = 0.0
		_update_label_visibility()
	elif _carry != &"landing" and current_clip() != DANGLE_CLIP:
		play(DANGLE_CLIP)
	_finish_frame(delta)


func _view_created(i: int, _view: Node2D) -> void:
	var label := NameLabel.new()
	label.setup(display_name)
	label.visible = _labels_shown()
	Overlay.strip_stage(i).add_child(label)
	_labels[i] = label


func _view_freed(i: int) -> void:
	if _labels.has(i):
		if is_instance_valid(_labels[i]):
			_labels[i].queue_free()
		_labels.erase(i)


func _labels_shown() -> bool:
	return Overlay.content_visible and _carry == &"" and _climb.is_empty() and Settings.show_names and not _balloon_shown


func _update_label_visibility() -> void:
	for l in _labels.values():
		l.visible = _labels_shown()


## Keeps each window's label above the head, also while crossing displays.
func _place_labels() -> void:
	var head := position + Vector2(0.0, bounds_pt().position.y)
	for i in _labels:
		_labels[i].place(Overlay.walkway_to_local(i, head))


# --- Balloon (balloons-and-speech D5) ----------------------------------------------

func balloon_open() -> bool:
	return _balloon_shown


## Shows, places and registers the balloon above the head, or hides it: nothing
## to say, carried, walking off, or the buddies hidden.
func _update_balloon() -> void:
	var want := not balloon_content.is_empty() and _carry == &"" and not is_going() and not is_climbing() \
		and Overlay.content_visible and not Overlay.walkway.is_empty()
	if not want:
		hide_balloon()
		return
	var head := position + Vector2(0.0, bounds_pt().position.y)
	var strip: int = Overlay.walkway.index_at(head.x)
	if _balloon == null:
		_balloon = Balloon.new()
		_balloon.setup(session_id, display_name, hue)
	var layer: CanvasLayer = Overlay.strip_ui(strip)
	if _balloon.get_parent() != layer:
		if _balloon.get_parent():
			_balloon.get_parent().remove_child(_balloon) # crossing to another display
		layer.add_child(_balloon)
	_balloon.messages = messages
	_balloon.show_content(balloon_content)
	var seg: Walkway.Segment = Overlay.walkway.segments[strip]
	var size := _balloon.fit(BalloonLayout.max_height(head.y))
	var spot := BalloonLayout.place(head.x, head.y, size, seg.start, seg.end())
	_balloon.place(Overlay.walkway_to_local(strip, spot.rect.position), spot.tail_x)
	_balloon.visible = true
	Overlay.set_region(balloon_region_id, spot.rect)
	if messages:
		messages.set_hovered(session_id, spot.rect.has_point(Overlay.pointer_pt()))
	if not _balloon_shown:
		_balloon_shown = true
		_update_label_visibility()


func hide_balloon() -> void:
	if _balloon and _balloon.visible:
		_balloon.hide_balloon()
	Overlay.remove_region(balloon_region_id)
	if messages:
		messages.set_hovered(session_id, false)
	if _balloon_shown:
		_balloon_shown = false
		_update_label_visibility()


func _exit_tree() -> void:
	if is_climbing():
		_end_climb()
	_end_jump()
	Overlay.remove_region(region_id)
	Overlay.remove_region(balloon_region_id)
	if is_instance_valid(_balloon):
		_balloon.queue_free()
	super()
