extends Node
## The avatars of all agent sessions (session-avatars design D1, D7). Turns the
## Bridge's sessions into SessionAvatar nodes, using the pure AvatarCast for
## who is on screen, in which slot and colour, and routes clicks.

## "Type here (debug)" in an avatar's context menu (send-home D4).
signal avatar_text_requested(avatar: Node)

const Cast := preload("res://scripts/core/avatar_cast.gd")
const Protocol := preload("res://scripts/bridge/protocol.gd")
const SessionAvatar := preload("res://scripts/avatars/session_avatar.gd")
const SessionRegistry := preload("res://scripts/core/session_registry.gd")
const ClickAction := preload("res://scripts/core/click_action.gd")
const GrabGesture := preload("res://scripts/core/grab_gesture.gd")

const REPLAN_SEC := 0.5
const DEFAULT_BODY_WIDTH_PT := 100.0

var _avatars := {} # session id -> SessionAvatar
var _away := {} # session id -> away mark (send-home D1, D2)
var _replan_left := 0.0
## The left press on an avatar that may become a grab (buddy-drag D1).
var _gesture := GrabGesture.new()
var _pressed: Node = null
var _press_point := Vector2.ZERO
## Avatars that hold the overlay's headroom while carried or falling (buddy-drag D6).
var _headroom := {}


func _ready() -> void:
	for sig in [&"session_added", &"session_changed", &"session_removed"]:
		Bridge.connect(sig, func(_id: String) -> void: _replan.call_deferred())
	Overlay.region_input.connect(_on_region_input)
	Overlay.region_released.connect(_on_region_released)
	Overlay.layout_changed.connect(func(_old: Variant) -> void: _replan.call_deferred())
	Overlay.home_changed.connect(func(_i: int) -> void: _replan.call_deferred())


func avatars() -> Array:
	return _avatars.values()


## Slots that fit on the home display (session-avatars D2).
func slot_count() -> int:
	if Overlay.walkway.is_empty():
		return Cast.MAX_AVATARS
	var seg := Overlay.walkway.segments[Overlay.home_index()]
	var body := DEFAULT_BODY_WIDTH_PT
	for a in _avatars.values():
		body = a.bounds_pt().size.x
		break
	return Cast.slot_count(seg.width, body)


func _process(delta: float) -> void:
	_replan_left -= delta
	if _replan_left <= 0.0:
		_replan()
	_update_grab()
	_update_headroom()


func _replan() -> void:
	_replan_left = REPLAN_SEC
	if Overlay.walkway.is_empty():
		return
	_update_away()
	var slots := slot_count()
	var sessions := Bridge.registry.sessions().map(func(s) -> Dictionary:
		return {"id": s.id, "name": s.name, "state": s.state, "updated_msec": s.updated_msec,
			"away": _away.has(s.id)})
	var shown := _avatars.values().map(func(a) -> Dictionary:
		return {"id": a.session_id, "slot": a.slot, "hue": a.hue, "leaving": a.is_going()})
	for act in Cast.plan(sessions, shown, slots):
		match act.kind:
			"enter":
				_spawn(Bridge.registry.get_session(act.id), act.slot, act.hue, slots)
			"leave":
				var a: SessionAvatar = _avatars.get(act.id)
				if a:
					a.leave(act.wave)
	for a in _avatars.values():
		a.slots = slots


## Sends a session's buddy home: it walks off and the session stays away
## until it is used again (send-home D1). Returns false for an unknown session.
func send_home(session_id: String) -> bool:
	var s: SessionRegistry.Session = Bridge.registry.get_session(session_id)
	if s == null:
		return false
	_away[session_id] = Cast.away_mark(s)
	var a: SessionAvatar = _avatars.get(session_id)
	if a and not a.is_going():
		a.leave(false)
	print("Avatars: %s sent home" % s.name)
	return true


## Auto-home after 15 minutes asleep, and the return of sessions used again.
func _update_away() -> void:
	var now := Time.get_ticks_msec()
	for a in _avatars.values():
		if not a.is_going() and a.mood.wants_home(now):
			send_home(a.session_id)
	for id in _away.keys():
		var s: SessionRegistry.Session = Bridge.registry.get_session(id)
		if s == null or s.state == Protocol.STATE_ENDED:
			_away.erase(id)
		elif Cast.comes_back(_away[id], s):
			_away.erase(id)
			print("Avatars: %s is back" % s.name)


func _spawn(session: SessionRegistry.Session, slot: int, hue: float, slots: int) -> void:
	if session == null:
		return
	var a := SessionAvatar.new()
	a.setup(session, slot, hue, slots)
	a.gone.connect(_on_gone)
	a.landed.connect(_on_landed)
	_avatars[session.id] = a
	add_child(a)
	print("Avatars: %s enters slot %d, hue %.0f" % [session.name, slot, hue])


func _on_gone(a: Node) -> void:
	if _avatars.get(a.session_id) == a:
		_avatars.erase(a.session_id)
	print("Avatars: %s left" % a.display_name)
	a.queue_free()
	_replan.call_deferred() # a waiting newcomer can take the freed slot


func _on_region_input(id: StringName, event: InputEventMouseButton, point: Vector2) -> void:
	if not String(id).begins_with("avatar:"):
		return
	var a: SessionAvatar = _avatars.get(String(id).trim_prefix("avatar:"))
	if a == null:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_press(a, point)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_open_menu.call_deferred(a)


# --- Picking up and dropping (buddy-drag D1, D5) ------------------------------

## A left press on an avatar: a falling buddy is caught at once, any other one
## waits to see whether this becomes a click or a grab.
func _press(a: Node, point: Vector2) -> void:
	_pressed = a
	_press_point = point
	_gesture.press(point, _now())
	if a.is_carried() and a.grab(point):
		_gesture.update(point, _now() + GrabGesture.HOLD_SEC) # already a grab
		_hold_headroom(a)


func _update_grab() -> void:
	if not _gesture.is_pressed():
		return
	if not is_instance_valid(_pressed):
		_gesture.cancel()
		_pressed = null
		return
	if _gesture.update(Overlay.pointer_pt(), _now()) == &"grab":
		if _pressed.grab(_press_point):
			_hold_headroom(_pressed)
			print("Avatars: %s picked up" % _pressed.display_name)


func _on_region_released(id: StringName, point: Vector2) -> void:
	var a = _pressed # untyped: may be freed by now
	if a == null or not is_instance_valid(a) or id != a.region_id:
		return
	_pressed = null
	match _gesture.release(point, _now()):
		&"click":
			go_to_session(a.session_id)
		&"drop":
			if a.carry_phase() == &"held":
				a.drop()
				print("Avatars: %s dropped" % a.display_name)


## The slot after a landing (buddy-drag D5): the nearest one on the home display,
## swapping with whoever had it. Elsewhere it keeps its slot and travels home.
func _on_landed(a: Node, x: float) -> void:
	var home: int = Overlay.home_index()
	if Overlay.walkway.is_empty() or Overlay.walkway.index_at(x) != home:
		return
	var seg := Overlay.walkway.segments[home]
	var slot := Cast.drop_slot(x, seg.start, seg.width, slot_count())
	if slot == a.slot:
		return
	for b in _avatars.values():
		if b != a and b.slot == slot:
			b.slot = a.slot
			print("Avatars: %s moves to slot %d" % [b.display_name, b.slot])
	a.slot = slot
	print("Avatars: %s dropped into slot %d" % [a.display_name, slot])


func _hold_headroom(a: Node) -> void:
	if not _headroom.has(a):
		_headroom[a] = true
		Overlay.begin_headroom()


## Lets the strips shrink once a carried buddy stands again (or is gone).
func _update_headroom() -> void:
	for a in _headroom.keys():
		if not is_instance_valid(a) or not a.is_carried():
			_headroom.erase(a)
			Overlay.end_headroom()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## The avatar's context menu: a native macOS menu at the pointer (send-home D4).
func _open_menu(a: Node) -> void:
	if not is_instance_valid(a) or not NativeMenu.has_feature(NativeMenu.FEATURE_POPUP_MENU):
		return
	var menu := build_menu(a)
	NativeMenu.set_popup_close_callback(menu, func() -> void: NativeMenu.free_menu.call_deferred(menu))
	NativeMenu.popup(menu, DisplayServer.mouse_get_position())


func build_menu(a: Node) -> RID:
	var menu := NativeMenu.create_menu()
	var id: String = a.session_id
	NativeMenu.add_item(menu, "Send home", func(_tag: Variant) -> void: send_home(id))
	if Settings.debug_regions:
		NativeMenu.add_item(menu, "Type here (debug)", func(_tag: Variant) -> void:
			if is_instance_valid(a):
				avatar_text_requested.emit(a))
	return menu


## A left click (go-to-session D3, always-go-to-session): bring the app that runs
## the session's agent to the front, whatever the session is doing; a session
## that has ended does nothing.
func go_to_session(session_id: String) -> String:
	var s: SessionRegistry.Session = Bridge.registry.get_session(session_id)
	if s == null:
		return ""
	var decision := ClickAction.for_left_click(s.state, s.ppid)
	if decision.action != "go":
		print("Avatars: click on %s does nothing: %s" % [s.name, decision.reason])
		return ""
	if Overlay.native == null:
		print("Avatars: no MacOverlay to activate the app of %s" % s.name)
		return ""
	var app: String = Overlay.native.activate_app_of(s.ppid)
	if not s.focus_url.is_empty():
		OS.shell_open(s.focus_url) # straight to the session in its host app (go-to-session D4)
	if app.is_empty() and s.focus_url.is_empty():
		print("Avatars: no app was found for %s (agent process %d)" % [s.name, s.ppid])
	else:
		print("Avatars: going to %s (%s%s)" % [s.name, app, ", " + s.focus_url if s.focus_url else ""])
	return app if not app.is_empty() else s.focus_url


## Removes every avatar's region and hides its balloon (while the buddies are hidden).
func remove_regions() -> void:
	for a in _avatars.values():
		Overlay.remove_region(a.region_id)
		a.hide_balloon()
