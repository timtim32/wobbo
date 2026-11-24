extends Node2D
## Main scene: the overlay's content root. Hides and pauses all content while
## the user has hidden the buddies.

@onready var _content: Node2D = $Content
@onready var _avatars: Node = $Content/Avatars
@onready var _text_field: LineEdit = $UI/DebugTextField
@onready var _panel: Control = $UI/SessionPanel


func _ready() -> void:
	_avatars.avatar_text_requested.connect(func(avatar: Node) -> void: _text_field.open_at(avatar))
	Overlay.content_visibility_changed.connect(_apply_visibility)
	_apply_visibility(Overlay.content_visible)
	# The session panel and the debug text field sit on the home display (multi-display D9).
	Overlay.home_changed.connect(_move_ui)
	Overlay.layout_changed.connect(func(_old: Variant) -> void: _move_ui.call_deferred(Overlay.home_index()))
	_move_ui.call_deferred(Overlay.home_index())


func _move_ui(strip: int) -> void:
	if strip < 0 or strip >= Overlay.strip_count():
		return
	var target := Overlay.strip_ui(strip)
	for node: Control in [_panel, _text_field]:
		if node.get_parent() == target:
			continue
		if node == _text_field and _text_field.visible:
			_text_field.close()
		if node == _panel:
			Overlay.remove_region(_panel.REGION_ID)
		node.reparent(target, false)


func _apply_visibility(shown: bool) -> void:
	_content.visible = shown
	_content.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	if not shown:
		_avatars.remove_regions()
