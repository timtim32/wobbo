extends Node2D
## Main scene: the overlay's content root. Hides and pauses all content while
## the user has hidden the buddies.

@onready var _content: Node2D = $Content
@onready var _avatars: Node = $Content/Avatars
@onready var _panel: Control = $UI/SessionPanel


func _ready() -> void:
	Overlay.content_visibility_changed.connect(_apply_visibility)
	_apply_visibility(Overlay.content_visible)
	# The session panel sits on the home display (multi-display D9).
	Overlay.home_changed.connect(_move_ui)
	Overlay.layout_changed.connect(func(_old: Variant) -> void: _move_ui.call_deferred(Overlay.home_index()))
	_move_ui.call_deferred(Overlay.home_index())


func _move_ui(strip: int) -> void:
	if strip < 0 or strip >= Overlay.strip_count():
		return
	var target := Overlay.strip_ui(strip)
	if _panel.get_parent() == target:
		return
	Overlay.remove_region(_panel.REGION_ID)
	_panel.reparent(target, false)


func _apply_visibility(shown: bool) -> void:
	_content.visible = shown
	_content.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	if not shown:
		_avatars.remove_regions()
