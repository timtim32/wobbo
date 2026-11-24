extends Node
## The welcome buddy "Wobbo" (standalone-app design D10, spec claude-code-setup):
## on a first start it walks in and offers to connect to Claude Code; when the
## app runs from outside Applications it first offers to move itself; after an
## update of the plugin it says so. It is a local session in the Bridge, so it
## looks and answers like any buddy, and walks off when the talk is over.

const AppMenu := preload("res://scripts/core/app_menu.gd")
const ClaudeSetup := preload("res://scripts/setup/claude_setup.gd")
const Plan := preload("res://scripts/core/claude_setup_plan.gd")
const MessagePolicy := preload("res://scripts/core/message_policy.gd")
const TrailerMode := preload("res://scripts/core/trailer_mode.gd")

const INFO := {"id": "wobbo:welcome", "agent": "wobbo", "project_dir": "/Wobbo"}
const CONNECT := "Connect to Claude Code"
const NOT_NOW := "Not now"
const MOVE := "Move to Applications"
const TRY_AGAIN := "Try again"
const OPEN_PAGE := "Open the install page"
## Seconds before the first words, so the buddy has walked in.
const ENTER_SEC := 1.5
## Seconds after the start before the welcome begins (the overlay settles).
const START_DELAY_SEC := 2.0

@export var setup_path := NodePath("../ClaudeSetup")

var _setup: Node
var _present := false
var _pending := ""
var _serial := 0
## Greet after the move offer is answered (a first start that began with it).
var _greet_after := false
## What the open question is about: &"connect", &"move" or &"retry".
var _topic := &""
## Whether results go to a balloon; false for a menu connect while balloons are
## not shown, which then reports with an alert (design D10).
var _via_balloon := true


func _ready() -> void:
	if Instance.duplicate or DisplayServer.get_name() == "headless" or TrailerMode.active():
		return
	_setup = get_node(setup_path)
	Bridge.request_answered.connect(_on_answered)
	_setup.finished.connect(_on_setup_finished)
	get_tree().create_timer(START_DELAY_SEC).timeout.connect(_begin)


## Whether the welcome buddy is out (for checks).
func is_present() -> bool:
	return _present


func _begin() -> void:
	var location: String = Overlay.native.bundle_location() if Overlay.native else "elsewhere"
	if AppMenu.offer_move(OS.has_feature("template"), location):
		_greet_after = Settings.first_start
		_ask("Hi, I'm Wobbo! Shall I move myself to your Applications folder first?", [MOVE, NOT_NOW], &"move")
	elif Settings.first_start:
		_greet()
	else:
		_offer_or_update()


## Not a first start: offer Connect while Wobbo is not connected and the user
## has not said "Not now" to it (an upgrade from Claude Buddy, or a Connect that
## failed); otherwise keep the plugin up to date.
func _offer_or_update() -> void:
	_setup.refresh(true)
	if _setup.busy:
		await _setup.state_changed
	if not _setup.connected and not Settings.connect_declined:
		_ask("Hi, I'm Wobbo! Shall I connect to Claude Code? Then every Claude Code session gets a Wobbo like me.",
			[CONNECT, NOT_NOW], &"connect")
	else:
		_setup.update_if_needed()


func _greet() -> void:
	_setup.refresh(true)
	if _setup.busy:
		await _setup.state_changed
	if _setup.connected:
		_say("Hi, I'm Wobbo! Your Claude Code sessions will show up here as Wobbos like me.")
		_leave_later(8.0)
	else:
		_ask("Hi, I'm Wobbo! Shall I connect to Claude Code? Then every Claude Code session gets a Wobbo like me.",
			[CONNECT, NOT_NOW], &"connect")


## From the menu: connect, reporting in a balloon when balloons are shown and
## with an alert otherwise.
func connect_from_menu() -> void:
	_via_balloon = Settings.overlay_visible and MessagePolicy.output_flags(Settings.messages).balloon
	_connect_now()


func _connect_now() -> void:
	if _via_balloon:
		_say("Connecting to Claude Code…")
	_setup.connect_claude()


func _on_setup_finished(action: StringName, result: Dictionary) -> void:
	match action:
		&"connect":
			if not _via_balloon:
				_via_balloon = true
				OS.alert(_connect_result_text(result), "Wobbo")
				return
			if result.ok:
				_say(connected_text(result.desktop))
				_leave_later(10.0)
			elif result.not_found:
				_ask("I couldn't find Claude Code on this Mac. Install it, then try again.", [OPEN_PAGE, TRY_AGAIN, NOT_NOW])
			else:
				_ask("Connecting to Claude Code failed: %s" % result.message, [TRY_AGAIN, NOT_NOW])
		&"update":
			if result.ok:
				_say(updated_text(result.message, result.desktop))
				_leave_later(10.0)
		&"disconnect":
			if not result.ok:
				OS.alert("Disconnecting from Claude Code failed: %s" % result.message, "Wobbo")


## The balloon after connecting; `desktop` is Claude Desktop's outcome
## (claude-desktop-setup D5).
static func connected_text(desktop: String) -> String:
	if ClaudeSetup.desktop_changed(desktop):
		return "Done! New Claude Code sessions will show up as Wobbos, and after a restart of Claude Desktop its chats can talk through me too. Restart the sessions that are already open."
	return "Done! New Claude Code sessions will show up as Wobbos. Restart the sessions that are already open."


## The balloon after the start-up update: `version` is the plugin's new version,
## or "" when only Claude Desktop's entry changed.
static func updated_text(version: String, desktop: String) -> String:
	var restart_desktop := ClaudeSetup.desktop_changed(desktop)
	if version.is_empty():
		return "I'm set up in Claude Desktop now. Restart Claude Desktop to use me in its chats."
	var text := "I updated my Claude Code plugin to %s. Restart open sessions to use it." % version
	return text + (" Restart Claude Desktop too." if restart_desktop else "")


static func _connect_result_text(result: Dictionary) -> String:
	if result.ok and ClaudeSetup.desktop_changed(result.desktop):
		return "Wobbo is connected to Claude Code and Claude Desktop. New Claude Code sessions will show up as Wobbos; restart the sessions that are already open, and restart Claude Desktop."
	if result.ok:
		return "Wobbo is connected to Claude Code. New sessions will show up as Wobbos; restart the sessions that are already open."
	if result.not_found:
		return "Wobbo couldn't find Claude Code on this Mac. Install it from %s and try again." % Plan.INSTALL_PAGE
	return "Connecting to Claude Code failed: %s" % result.message


func _on_answered(request: Dictionary, _status: String, choice: String, _text: String) -> void:
	if String(request.id) != _pending:
		return
	_pending = ""
	if choice == CONNECT or choice == TRY_AGAIN:
		Settings.connect_declined = false
	match choice:
		MOVE:
			_move()
		CONNECT, TRY_AGAIN:
			_via_balloon = true
			_connect_now()
		OPEN_PAGE:
			OS.shell_open(Plan.INSTALL_PAGE)
			_ask("When Claude Code is installed, I'll connect to it.", [TRY_AGAIN, NOT_NOW])
		_: # "Not now", or closed with ×
			if _topic == &"connect" and choice == NOT_NOW:
				Settings.connect_declined = true # × or a hand-back asks again next start
			if _greet_after:
				_greet_after = false
				_greet()
			else:
				_leave_later(0.5)


func _move() -> void:
	var dest: String = Overlay.native.move_to_applications() if Overlay.native else "error: no native support"
	if dest.begins_with("error:"):
		print("Welcome: move failed (%s)" % dest)
		_say("I couldn't move myself. Drag Wobbo to the Applications folder in Finder.")
		if _greet_after:
			_greet_after = false
			get_tree().create_timer(6.0).timeout.connect(_greet)
		else:
			_leave_later(8.0)
		return
	# Start the copy once this one has quit, so it does not see a running Wobbo.
	print("Welcome: moved to %s; starting it there" % dest)
	OS.create_process("/bin/sh", ["-c", "sleep 1; /usr/bin/open \"$0\"", dest])
	get_tree().quit()


func _show() -> void:
	if _present:
		return
	_present = true
	Bridge.local_event(INFO, "session_start")
	await get_tree().create_timer(ENTER_SEC).timeout


func _say(text: String) -> void:
	await _show()
	Bridge.local_say(INFO.id, text)


func _ask(text: String, choices: Array, topic := &"retry") -> void:
	_topic = topic
	await _show()
	_serial += 1
	_pending = "wobbo:ask:%d" % _serial
	Bridge.local_request(INFO.id, _pending, text, choices)


func _leave_later(delay_sec: float) -> void:
	var serial := _serial
	await get_tree().create_timer(delay_sec).timeout
	if serial != _serial or not _pending.is_empty() or not _present or _setup.busy:
		return # a new question or message came meanwhile
	_present = false
	Bridge.local_event(INFO, "session_end")
