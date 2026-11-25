extends StatusIndicator
## macOS menu bar icon and app menu (overlay-window D7, spec menu-bar-control).

## Submenus get explicit ids too: without one an item's id is its index, which
## collides with these (and _sync would then rename a submenu).
enum Item { TOGGLE_VISIBLE, DEBUG_REGIONS, QUIT, DEMO, SHOW_NAMES, CLAUDE, LOGIN, SCREEN = 50, SIZE, MESSAGES }

const ScreenMenu := preload("res://scripts/core/screen_menu.gd")
const BuddySize := preload("res://scripts/core/buddy_size.gd")
const MessagePolicy := preload("res://scripts/core/message_policy.gd")
const AppMenu := preload("res://scripts/core/app_menu.gd")
## Ids in the "Messages" submenu after the output radio items (balloons-and-speech D8).
const MESSAGES_DONE_ID := 100
const MESSAGES_ERRORS_ID := 101

@onready var _menu: PopupMenu = $Menu
@onready var _demo: Node = get_node_or_null("../Demo")
@onready var _messages: Node = get_node_or_null("../Messages")
@onready var _setup: Node = get_node_or_null("../ClaudeSetup")
@onready var _welcome: Node = get_node_or_null("../Welcome")
var _screen_menu := PopupMenu.new()
var _screen_values: Array[String] = []
var _size_menu := PopupMenu.new()
var _size_values: Array[String] = []
var _messages_menu := PopupMenu.new()
var _messages_values: Array[String] = []
## macOS's login item state as last read; asking takes 150-450 ms, so it is read
## on a worker thread and the menu only uses this (quick-menu D1).
var _login_status := "not_registered"
var _login_task := -1
var _login_toggles := 0 # a read that started before a toggle is stale


func _ready() -> void:
	_menu.clear()
	_menu.add_item("Hide Wobbos", Item.TOGGLE_VISIBLE)
	_screen_menu.name = "ScreenMenu"
	_menu.add_child(_screen_menu)
	_menu.add_submenu_node_item("Screen", _screen_menu, Item.SCREEN)
	_screen_menu.id_pressed.connect(_on_screen_pressed)
	_size_menu.name = "SizeMenu"
	_menu.add_child(_size_menu)
	_menu.add_submenu_node_item("Size", _size_menu, Item.SIZE) # buddy-size D5
	_size_menu.id_pressed.connect(_on_size_pressed)
	_messages_menu.name = "MessagesMenu"
	_menu.add_child(_messages_menu)
	_menu.add_submenu_node_item("Messages", _messages_menu, Item.MESSAGES) # balloons-and-speech D8
	_messages_menu.id_pressed.connect(_on_messages_pressed)
	_menu.add_check_item("Show Names", Item.SHOW_NAMES)
	_menu.add_item("Play Demo", Item.DEMO)
	_menu.add_separator()
	_menu.add_item("Connect to Claude Code…", Item.CLAUDE) # standalone-app D9
	_menu.add_check_item("Open at Login", Item.LOGIN) # standalone-app D7
	_menu.add_separator()
	if Settings.debug_build: # open-source-readiness D2
		_menu.add_check_item("Debug regions", Item.DEBUG_REGIONS)
		_menu.add_separator()
	_menu.add_item("Quit %s" % ProjectSettings.get_setting("application/config/name", "Wobbo"), Item.QUIT)
	_menu.id_pressed.connect(_on_id_pressed)
	menu = get_path_to(_menu)
	Settings.changed.connect(func(_k: StringName, _v: Variant) -> void: _sync())
	Overlay.layout_changed.connect(func(_old: Variant) -> void: _rebuild_screens())
	_menu.about_to_popup.connect(_rebuild_screens)
	_menu.about_to_popup.connect(_on_menu_opening)
	if _setup:
		_setup.state_changed.connect(func(_c: bool) -> void: _sync_app_items())
		_setup.busy_changed.connect(func(_b: bool) -> void: _sync_app_items())
		_setup.refresh()
	if _demo:
		_demo.running_changed.connect(func(_r: bool) -> void: _sync())
	_sync()
	_read_login_status()
	_make_icon_template.call_deferred()


func _exit_tree() -> void:
	if _login_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_login_task)
		_login_task = -1


## Godot does not mark the status icon as a template image, so macOS would draw
## the black silhouette as-is (invisible on a dark menu bar). Let the native
## extension flag it, so macOS tints it for light and dark menu bars.
func _make_icon_template() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	if Overlay.native == null:
		push_warning("MenuBar: no MacOverlay; the menu bar icon is not tinted for dark menu bars.")
		return
	var count: int = Overlay.native.set_status_item_icons_template()
	if count == 0:
		push_warning("MenuBar: no status item found to mark as template.")


func _sync() -> void:
	_menu.set_item_text(_menu.get_item_index(Item.TOGGLE_VISIBLE),
		"Hide Wobbos" if Settings.overlay_visible else "Show Wobbos")
	if Settings.debug_build:
		_menu.set_item_checked(_menu.get_item_index(Item.DEBUG_REGIONS), Settings.debug_regions)
	_menu.set_item_checked(_menu.get_item_index(Item.SHOW_NAMES), Settings.show_names)
	_menu.set_item_text(_menu.get_item_index(Item.DEMO), "Stop Demo" if _demo and _demo.running else "Play Demo")
	_rebuild_screens()
	_rebuild_sizes()
	_rebuild_messages()
	_sync_app_items()


func _on_menu_opening() -> void:
	if _setup:
		_setup.refresh() # re-read unless fresh; the item updates when done
	_read_login_status()
	_sync_app_items()


func _login_location() -> String:
	var native: Object = Overlay.native
	return native.bundle_location() if native else "elsewhere"


## Starts one background read of the login state (quick-menu D1, D2); the item
## updates when it is back.
func _read_login_status() -> void:
	var native: Object = Overlay.native
	if native == null or _login_task >= 0 \
			or not AppMenu.needs_login_status(OS.has_feature("template"), _login_location()):
		return
	var toggles := _login_toggles
	_login_task = WorkerThreadPool.add_task(func() -> void:
		_login_status_read.call_deferred(native.login_item_status(), toggles))


func _login_status_read(status: String, toggles: int) -> void:
	WorkerThreadPool.wait_for_task_completion(_login_task)
	_login_task = -1
	if toggles == _login_toggles and status != _login_status:
		_login_status = status
		_sync_app_items()


## The Claude Code item and "Open at Login" (standalone-app D7, D9).
func _sync_app_items() -> void:
	var claude := AppMenu.claude_item(_setup != null and _setup.connected, _setup != null and _setup.busy)
	var i := _menu.get_item_index(Item.CLAUDE)
	_menu.set_item_text(i, claude.label)
	_menu.set_item_disabled(i, _setup == null or claude.disabled)
	var login := AppMenu.login_item(OS.has_feature("template"), _login_location(),
		_login_status if Overlay.native else "unavailable")
	i = _menu.get_item_index(Item.LOGIN)
	_menu.set_item_disabled(i, not login.enabled)
	_menu.set_item_checked(i, login.checked)


func _toggle_login_item() -> void:
	var native: Object = Overlay.native
	if native == null:
		return
	var turn_on: bool = native.login_item_status() != "enabled"
	var err: String = native.set_login_item(turn_on)
	var status: String = native.login_item_status()
	_login_status = status
	_login_toggles += 1
	print("MenuBar: Open at Login %s -> %s%s" % ["on" if turn_on else "off", status, "" if err.is_empty() else " (%s)" % err])
	if turn_on and status == "requires_approval":
		native.open_login_items_settings()
	elif not err.is_empty():
		OS.alert("Open at Login could not be changed: %s" % err, "Wobbo")
	_sync_app_items()


## Rebuilds the "Size" submenu: one radio item per size, the setting checked.
func _rebuild_sizes() -> void:
	_size_menu.clear()
	_size_values.clear()
	for item in BuddySize.items(Settings.buddy_size):
		var id := _size_values.size()
		_size_menu.add_radio_check_item(item.label, id)
		_size_menu.set_item_checked(_size_menu.get_item_index(id), item.checked)
		_size_values.append(item.value)


## Rebuilds the "Messages" submenu: the output radio items, then the two notices.
func _rebuild_messages() -> void:
	_messages_menu.clear()
	_messages_values.clear()
	var speech: bool = _messages != null and _messages.speech_available()
	for item in MessagePolicy.menu_items(Settings.messages, speech):
		var id := _messages_values.size()
		_messages_menu.add_radio_check_item(item.label, id)
		var index := _messages_menu.get_item_index(id)
		_messages_menu.set_item_checked(index, item.checked)
		_messages_menu.set_item_disabled(index, item.disabled)
		_messages_values.append(item.value)
	_messages_menu.add_separator()
	_messages_menu.add_check_item("Turn finished", MESSAGES_DONE_ID)
	_messages_menu.set_item_checked(_messages_menu.get_item_index(MESSAGES_DONE_ID), Settings.notify_done)
	_messages_menu.add_check_item("Errors", MESSAGES_ERRORS_ID)
	_messages_menu.set_item_checked(_messages_menu.get_item_index(MESSAGES_ERRORS_ID), Settings.notify_errors)


func _on_messages_pressed(id: int) -> void:
	if id == MESSAGES_DONE_ID:
		Settings.notify_done = not Settings.notify_done
	elif id == MESSAGES_ERRORS_ID:
		Settings.notify_errors = not Settings.notify_errors
	elif id >= 0 and id < _messages_values.size():
		Settings.messages = _messages_values[id]


func _on_size_pressed(id: int) -> void:
	if id >= 0 and id < _size_values.size():
		Settings.buddy_size = _size_values[id]


## Rebuilds the "Screen" submenu from the connected displays and the setting.
func _rebuild_screens() -> void:
	_screen_menu.clear()
	_screen_values.clear()
	var items := ScreenMenu.items(Overlay.displays(), Settings.screen, Settings.screen_name)
	for item in items:
		if item.separator:
			_screen_menu.add_separator()
			_screen_values.append("")
			continue
		var id := _screen_values.size()
		_screen_menu.add_radio_check_item(item.label, id)
		var index := _screen_menu.get_item_index(id)
		_screen_menu.set_item_checked(index, item.checked)
		_screen_menu.set_item_disabled(index, item.disabled)
		_screen_values.append(item.value)


func _on_screen_pressed(id: int) -> void:
	if id < 0 or id >= _screen_values.size() or _screen_values[id].is_empty():
		return
	var value := _screen_values[id]
	Settings.screen = value
	var display_name := ""
	for d in Overlay.displays():
		if str(d.id) == value:
			display_name = d.name
	Settings.screen_name = display_name


func _on_id_pressed(id: int) -> void:
	match id:
		Item.TOGGLE_VISIBLE:
			Settings.overlay_visible = not Settings.overlay_visible
		Item.DEBUG_REGIONS:
			Settings.debug_regions = not Settings.debug_regions
		Item.SHOW_NAMES:
			Settings.show_names = not Settings.show_names
		Item.DEMO:
			if _demo:
				_demo.toggle()
		Item.CLAUDE:
			if _setup and _setup.connected:
				_setup.disconnect_claude()
			elif _welcome:
				_welcome.connect_from_menu()
		Item.LOGIN:
			_toggle_login_item()
		Item.QUIT:
			get_tree().quit()
