extends Node
## A buddy on the walkway (multi-display design D3): one model in walkway
## points, drawn by a Monster view in every strip window it overlaps. The first
## view (on the strip under the body's feet) plays; the others mirror it, so a
## body crossing from one display to the next looks like one buddy.
##
## Subclasses move `position` (feet point, walkway points) and call play().

signal clip_finished(clip: StringName)

const MonsterScene := preload("res://characters/monster/monster.tscn")

## Feet point in walkway points (x along the walkway, y from the strip top).
var position := Vector2.ZERO
var facing := 1
## Rotation around the feet in radians, while carried or tumbling (buddy-drag D3).
var tilt := 0.0
var hue := -1.0
## Height in points of every view (buddy-size D3).
var height_pt := Monster.DISPLAY_HEIGHT_PT
## Global screen px (DisplayServer space) the eye looks at, or null.
var look_target: Variant = null

var _views := {} # strip index -> Monster
var _primary := -1
var _clip: StringName = &"idle"


func _ready() -> void:
	Overlay.layout_changed.connect(_on_layout_changed)
	Overlay.content_visibility_changed.connect(func(v: bool) -> void:
		for m in _views.values():
			m.visible = v)


## Size of the body in points (at its default scale, no animation).
func bounds_pt() -> Rect2:
	var m := _any_view()
	if m == null:
		var h := height_pt
		return Rect2(-h * 0.5, -h, h, h)
	var b: Rect2 = m.get_local_bounds()
	return Rect2(b.position / Overlay.points_to_px(1.0), b.size / Overlay.points_to_px(1.0))


func half_width() -> float:
	return bounds_pt().size.x * 0.5


## The body's rect in walkway points (the box around it while it is tilted).
func rect_pt() -> Rect2:
	var b := bounds_pt()
	if tilt == 0.0:
		return Rect2(position + b.position, b.size)
	var r := Rect2(position + b.position.rotated(tilt), Vector2.ZERO)
	for corner in [Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]:
		r = r.expand(position + corner.rotated(tilt))
	return r


func current_clip() -> StringName:
	return _clip


func play(clip: StringName) -> void:
	_clip = clip
	var m = _views.get(_primary) # untyped: may be a freed view
	if m:
		m.play(clip)


func set_facing(direction: int) -> void:
	facing = -1 if direction < 0 else 1


func _any_view() -> Monster:
	for m in _views.values():
		if is_instance_valid(m):
			return m
	return null


func _on_layout_changed(old_walkway: Variant) -> void:
	position.x = Overlay.walkway.remap(position.x, old_walkway)
	_free_views()


func _free_views() -> void:
	for i in _views.keys():
		if is_instance_valid(_views[i]):
			_views[i].queue_free()
		_view_freed(i)
	_views.clear()
	_primary = -1


## Hooks for subclasses that draw extra things per strip window (session-avatars D5).
func _view_created(_i: int, _view: Node2D) -> void:
	pass


func _view_freed(_i: int) -> void:
	pass


func _process(_delta: float) -> void:
	_update_views()


func _new_view(i: int) -> Monster:
	var m := MonsterScene.instantiate() as Monster
	m.visible = Overlay.content_visible
	Overlay.strip_stage(i).add_child(m)
	m.hue = hue
	m.height_pt = height_pt
	m.set_facing(facing)
	m.clip_finished.connect(func(clip: StringName) -> void:
		if _views.get(_primary) == m:
			if m.current_clip != _clip:
				_clip = m.current_clip # a one-shot returned to idle
			clip_finished.emit(clip))
	return m


func _update_views() -> void:
	if Overlay.walkway.is_empty():
		return
	var wanted: Array[int] = Overlay.strips_overlapping(rect_pt())
	var primary: int = Overlay.walkway.index_at(position.x)
	if not primary in wanted:
		wanted.append(primary)
	for i in _views.keys():
		if not i in wanted:
			_views[i].queue_free()
			_views.erase(i)
			_view_freed(i)
	for i in wanted:
		if not _views.has(i) or not is_instance_valid(_views[i]):
			_views[i] = _new_view(i)
			_view_created(i, _views[i])
	if primary != _primary:
		# The primary view hands over: the new one takes the clip and pose.
		var old = _views.get(_primary) # untyped: may be a freed view
		var new: Monster = _views[primary]
		if old and is_instance_valid(old):
			new.mirror(old)
		else:
			new.play(_clip)
		new.mirroring = false # the primary view animates on its own
		_primary = primary
	var main: Monster = _views[_primary]
	if main.height_pt != height_pt:
		main.height_pt = height_pt
	if main.hue != hue:
		main.hue = hue
	if main.facing != facing:
		main.set_facing(facing)
	if look_target != null:
		main.look_at_point(Vector2(look_target) - Vector2(Overlay.strip_rect_px(_primary).position))
	else:
		main.clear_look_target()
	for i in _views:
		var m: Monster = _views[i]
		m.position = Overlay.walkway_to_local(i, position)
		m.rotation = tilt
		if i != _primary:
			m.mirror(main)


func _exit_tree() -> void:
	_free_views()
