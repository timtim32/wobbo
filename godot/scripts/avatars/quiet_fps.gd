extends Node
## Lowers the frame rate while nothing moves (session-avatars design D8). Lives
## outside Content, so it keeps running while the buddies are hidden.

const QuietMode := preload("res://scripts/core/quiet_mode.gd")
const TrailerMode := preload("res://scripts/core/trailer_mode.gd")
## Frame rate while a buddy is carried or falling, for a smooth swing (buddy-drag D6).
const CARRY_FPS := 60

@export var avatars_path: NodePath
@export var messages_path: NodePath

var quiet := false
## Off only for checks from game_eval, where the user's pointer may rest on a strip.
var check_pointer := true
var quiet_fps := QuietMode.QUIET_FPS
var _normal_fps := 30
@onready var _avatars: Node = get_node_or_null(avatars_path)
@onready var _messages: Node = get_node_or_null(messages_path)



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_normal_fps = Engine.max_fps if Engine.max_fps > 0 else 30
	if TrailerMode.active():
		set_process(false) # a recording keeps the full frame rate, also for the title without buddies
		return
	# For CPU measurements (session-avatars spike S1): Godot ... -- --quiet-fps=10
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quiet-fps="):
			quiet_fps = int(arg.trim_prefix("--quiet-fps="))


func _process(_delta: float) -> void:
	var list: Array = []
	if _avatars:
		list = _avatars.avatars().map(func(a) -> Dictionary: return {"asleep": a.mood.asleep, "going": a.is_going(), "moving": a.is_moving()})
	var now_quiet := QuietMode.is_quiet(Overlay.content_visible, list, Settings.debug_regions,
		check_pointer and _pointer_on_strip(),
		_messages != null and _messages.any_balloon_open())
	var carrying := Overlay.headroom_active()
	if carrying:
		now_quiet = false
	quiet = now_quiet
	var fps := quiet_fps if quiet else (CARRY_FPS if carrying else _normal_fps)
	if Engine.max_fps != fps:
		Engine.max_fps = fps


func _pointer_on_strip() -> bool:
	var p := Vector2(DisplayServer.mouse_get_position())
	for i in Overlay.strip_count():
		if Rect2(Overlay.strip_rect_px(i)).has_point(p):
			return true
	return false
