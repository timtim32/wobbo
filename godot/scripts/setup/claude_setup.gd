extends Node
## Connects Wobbo to Claude Code by installing the plugin it carries (standalone-app
## design D9, spec claude-code-setup). The commands come from `ClaudeSetupPlan`;
## this node finds the `claude` CLI, copies the plugin to a stable folder, and
## runs the commands on a worker thread. Tests inject `runner` and `sync`.

signal state_changed(connected: bool)
signal busy_changed(busy: bool)
## `action` is &"connect", &"disconnect" or &"update". `result` is {ok: bool,
## message: String, not_found: bool, desktop: String}: `desktop` is what
## happened to Claude Desktop's entry (`added`, `updated`, `unchanged`,
## `removed`, `absent`), or "" when that step did not run or failed.
signal finished(action: StringName, result: Dictionary)

const Plan := preload("res://scripts/core/claude_setup_plan.gd")
## How long a known connection state is trusted before the menu re-reads it.
const STATE_TTL_MSEC := 10 * 1000
## The plugin inside the exported app, relative to Contents/Resources.
const BUNDLED_PLUGIN := "wobbo-plugin"

## func(program: String, args: PackedStringArray) -> {exit: int, output: String}.
## Defaults to OS.execute; tests replace it.
var runner: Callable
## Run on the calling thread (tests).
var sync := false
## Where the plugin is copied to and added as marketplace from.
var payload_dir := ""
## The plugin to install (a folder with .claude-plugin/plugin.json); found on
## first use when empty.
var plugin_source := ""
## Path of the `claude` CLI; found on first use when empty.
var cli_path := ""

var connected := false
var busy := false
## The version of the installed plugin, or "".
var installed_version := ""

var _state_msec := -1
var _thread: Thread


func _ready() -> void:
	if not runner.is_valid():
		runner = _execute
	if payload_dir.is_empty():
		payload_dir = OS.get_user_data_dir().path_join("claude-plugin")


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


## The version of the plugin Wobbo carries, or "" when there is none.
func payload_version() -> String:
	var source := _plugin_source()
	if source.is_empty():
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(source.path_join(".claude-plugin/plugin.json")))
	return String(data.get("version", "")) if data is Dictionary else ""


## Re-reads the connection state unless it is fresh (or `force`); emits
## state_changed when done. Returns at once; the menu shows the cached state.
func refresh(force := false) -> void:
	if busy or (not force and _state_msec >= 0 and Time.get_ticks_msec() - _state_msec < STATE_TTL_MSEC):
		return
	_start(&"refresh", _do_refresh)


func connect_claude() -> void:
	_start(&"connect", _do_connect)


func disconnect_claude() -> void:
	_start(&"disconnect", _do_disconnect)


## On start: update the plugin when the installed one is older than Wobbo's
## (spec "Keeping the plugin current"). Emits finished(&"update") only when it
## updated or tried to.
func update_if_needed() -> void:
	_start(&"update", _do_update)


# --- worker side -------------------------------------------------------------

func _start(action: StringName, work: Callable) -> void:
	if busy:
		return
	busy = true
	busy_changed.emit(true)
	if sync:
		_done(action, work.call())
		return
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(func() -> void: _done.call_deferred(action, work.call()))


func _done(action: StringName, result: Dictionary) -> void:
	if _thread and _thread.is_started() and not sync:
		_thread.wait_to_finish()
	busy = false
	busy_changed.emit(false)
	if result.has("plugins"):
		var plugins: Array[Dictionary] = result.plugins
		var own := Plan.own_plugin(plugins)
		installed_version = String(own.get("version", ""))
		connected = Plan.connected_in(plugins)
		_state_msec = Time.get_ticks_msec()
		state_changed.emit(connected)
	if action != &"refresh" and not result.get("silent", false):
		print("ClaudeSetup: %s %s%s" % [action, "ok" if result.ok else "failed",
			"" if result.message.is_empty() else ": " + result.message])
		finished.emit(action, {"ok": result.ok, "message": result.message, "not_found": result.get("not_found", false),
			"desktop": result.get("desktop", "")})


## Whether `desktop` (a result's Claude Desktop outcome) means Claude Desktop
## must be restarted to pick up the change.
static func desktop_changed(desktop: String) -> bool:
	return desktop == "added" or desktop == "updated"


func _do_refresh() -> Dictionary:
	if _find_cli().is_empty():
		return {"ok": false, "message": "", "plugins": [] as Array[Dictionary]}
	var listed := _list()
	return {"ok": listed.ok, "message": listed.message, "plugins": listed.plugins}


func _do_connect() -> Dictionary:
	if _find_cli().is_empty():
		return {"ok": false, "not_found": true, "message": "Claude Code was not found on this Mac."}
	var version := payload_version()
	if version.is_empty():
		return {"ok": false, "message": "Wobbo's Claude Code plugin is missing from this copy of Wobbo."}
	var copied := _copy_payload()
	if not copied.is_empty():
		return {"ok": false, "message": copied}
	var listed := _list()
	if not listed.ok:
		return listed
	var markets := _run(["plugin", "marketplace", "list", "--json"])
	var steps := Plan.connect_steps(listed.plugins, Plan.parse_marketplaces(markets.output), payload_dir, version)
	var ran := _run_steps(steps)
	if not ran.ok:
		ran["plugins"] = _list().plugins
		return ran
	# Claude Desktop's step never fails the connect (claude-desktop-setup D4).
	return {"ok": true, "message": "", "plugins": _list().plugins, "desktop": _desktop("connect").outcome}


func _do_disconnect() -> Dictionary:
	if _find_cli().is_empty():
		return {"ok": false, "not_found": true, "message": "Claude Code was not found on this Mac."}
	var listed := _list()
	if not listed.ok:
		return listed
	var markets := _run(["plugin", "marketplace", "list", "--json"])
	var ran := _run_steps(Plan.disconnect_steps(listed.plugins, Plan.parse_marketplaces(markets.output)))
	ran["plugins"] = _list().plugins
	ran["desktop"] = _desktop("disconnect").outcome
	return ran


## On start: update the plugin when it is older than Wobbo's; otherwise, while
## connected, make sure Claude Desktop's entry is there and current
## (claude-desktop-setup D4). Silent unless something changed.
func _do_update() -> Dictionary:
	if _find_cli().is_empty():
		return {"ok": true, "message": "", "silent": true, "plugins": [] as Array[Dictionary]}
	var listed := _list()
	var version := payload_version()
	var quiet := {"ok": true, "message": "", "silent": true, "plugins": listed.get("plugins", [] as Array[Dictionary])}
	if not listed.ok or version.is_empty():
		return quiet
	if Plan.needs_update(listed.plugins, version):
		var result := _do_connect()
		result["message"] = version if result.ok else result.message
		return result
	if not Plan.connected_in(listed.plugins):
		return quiet
	if not FileAccess.file_exists(payload_bridge()) and not _copy_payload().is_empty():
		return quiet
	var desktop: String = _desktop("connect").outcome
	quiet["desktop"] = desktop
	quiet["silent"] = not desktop_changed(desktop)
	return quiet


## The bridge in the copied plugin. Claude Desktop's entry points at it, because
## it stays put when Wobbo moves (claude-desktop-setup D3).
func payload_bridge() -> String:
	return payload_dir.path_join("plugins").path_join(Plan.PLUGIN).path_join("bin/wobbo-bridge")


## Runs `wobbo-bridge claude-desktop <action>` -> {ok, outcome}. Connect runs the
## copied bridge, which writes its own path into Claude Desktop's configuration;
## disconnect falls back to the bridge inside Wobbo when there is no copy.
func _desktop(action: String) -> Dictionary:
	var bridge := payload_bridge()
	if not FileAccess.file_exists(bridge) and action == "disconnect" and not _plugin_source().is_empty():
		bridge = _plugin_source().path_join("bin/wobbo-bridge")
	if not FileAccess.file_exists(bridge):
		print("ClaudeSetup: Claude Desktop %s skipped: no bridge at %s" % [action, bridge])
		return {"ok": false, "outcome": ""}
	var r: Dictionary = runner.call(bridge, PackedStringArray(["claude-desktop", action]))
	var output := String(r.output).strip_edges()
	if r.exit != 0:
		print("ClaudeSetup: Claude Desktop %s failed (exit %d): %s" % [action, r.exit, output.left(600)])
		return {"ok": false, "outcome": ""}
	var outcome := output.get_slice("\n", output.get_slice_count("\n") - 1).strip_edges()
	if desktop_changed(outcome) or outcome == "removed":
		print("ClaudeSetup: Claude Desktop %s: %s" % [action, outcome])
	return {"ok": true, "outcome": outcome}


func _list() -> Dictionary:
	var r := _run(["plugin", "list", "--json"])
	if r.exit != 0:
		return {"ok": false, "message": Plan.error_line(r.output, r.exit), "plugins": [] as Array[Dictionary]}
	return {"ok": true, "message": "", "plugins": Plan.parse_plugins(r.output)}


func _run_steps(steps: Array[Dictionary]) -> Dictionary:
	for step in steps:
		var r := _run(step.args, step.cwd)
		if r.exit != 0:
			return {"ok": false, "message": Plan.error_line(r.output, r.exit)}
	return {"ok": true, "message": ""}


## The shell script that runs one CLI command: it drops Claude Code's session
## variables first (CLAUDECODE, CLAUDE_CODE_SESSION_ID, ... but not
## CLAUDE_CONFIG_DIR), which Wobbo inherits when it is started from inside a
## Claude Code session. With them the CLI acts as part of that session and its
## plugin changes do not reach the user's own configuration.
const RUN_SCRIPT := "for v in ${(k)parameters[(I)CLAUDE*]}; do [[ $v == CLAUDE_CONFIG_DIR ]] || unset $v; done; " \
	+ "cd \"$1\" && shift && exec \"$@\""


## Runs the CLI in `cwd` (home when empty) through the user's login shell, so
## Claude Code finds what it needs on the user's PATH (for example node).
func _run(args: PackedStringArray, cwd := "") -> Dictionary:
	var dir := cwd if not cwd.is_empty() else OS.get_environment("HOME")
	var full := PackedStringArray(["-lc", RUN_SCRIPT, "wobbo", dir, cli_path])
	full.append_array(args)
	var r: Dictionary = runner.call("/bin/zsh", full)
	if r.exit != 0:
		print("ClaudeSetup: `claude %s` failed (exit %d): %s" % [" ".join(args), r.exit, String(r.output).strip_edges().left(600)])
	elif not args.has("list"):
		print("ClaudeSetup: `claude %s` ok" % " ".join(args))
	return r


func _execute(program: String, args: PackedStringArray) -> Dictionary:
	return execute(program, args)


## OS.execute() with output runs through popen(), so /bin/sh reads the command
## line. Godot puts each argument in double quotes without escaping anything,
## so sh would expand `$`, backticks and backslashes and eat `"`: escape them.
static func execute(program: String, args: PackedStringArray) -> Dictionary:
	var safe := PackedStringArray()
	for a in args:
		safe.append(sh_escape(a))
	var out := []
	var code := OS.execute(sh_escape(program), safe, out, true)
	return {"exit": code, "output": "\n".join(out)}


## Makes `arg` reach the program literally inside sh's double quotes.
static func sh_escape(arg: String) -> String:
	return arg.replace("\\", "\\\\").replace("$", "\\$").replace("`", "\\`").replace("\"", "\\\"")


func _find_cli() -> String:
	if not cli_path.is_empty():
		return cli_path
	var home := OS.get_environment("HOME")
	for path in Plan.cli_candidates(home):
		if FileAccess.file_exists(path):
			cli_path = path
			return cli_path
	var r: Dictionary = runner.call("/bin/zsh", PackedStringArray(["-lc", "command -v claude"]))
	var found := String(r.output).strip_edges().get_slice("\n", 0)
	if r.exit == 0 and found.begins_with("/"):
		cli_path = found
		return cli_path
	var root := home.path_join("Library/Application Support/Claude/claude-code")
	var version := Plan.newest_version(DirAccess.get_directories_at(root))
	if not version.is_empty():
		for build in DirAccess.get_directories_at(root.path_join(version)):
			var path := Plan.desktop_cli_path(root.path_join(version).path_join(build))
			if FileAccess.file_exists(path):
				cli_path = path
				return cli_path
	return ""


## The plugin folder Wobbo carries: inside the exported app, or in an editor run
## the repository's built plugin (bridge/plugin, after `bun run build:plugin`).
func _plugin_source() -> String:
	if not plugin_source.is_empty():
		return plugin_source
	var bundled := OS.get_executable_path().get_base_dir().get_base_dir().path_join("Resources").path_join(BUNDLED_PLUGIN)
	if OS.has_feature("template") and DirAccess.dir_exists_absolute(bundled):
		return bundled
	var dev := ProjectSettings.globalize_path("res://").path_join("../bridge/plugin").simplify_path()
	if not OS.has_feature("template") and FileAccess.file_exists(dev.path_join("bin/wobbo-bridge")):
		return dev
	return ""


## Copies the plugin into `payload_dir` as a one-plugin marketplace that stays
## put even when Wobbo runs from a disk image (design D9). "" on success.
func _copy_payload() -> String:
	var source := _plugin_source()
	var target := payload_dir.path_join("plugins").path_join(Plan.PLUGIN)
	_remove_tree(payload_dir)
	var err := _copy_tree(source, target)
	if err != OK:
		return "Could not copy the plugin (%s)." % error_string(err)
	DirAccess.make_dir_recursive_absolute(payload_dir.path_join(".claude-plugin"))
	var market := {
		"name": Plan.MARKETPLACE,
		"owner": {"name": "Wobbo"},
		"description": "The Claude Code plugin that comes with the Wobbo app.",
		"plugins": [{"name": Plan.PLUGIN, "source": "./plugins/" + Plan.PLUGIN,
			"description": "Claude Code sessions as Wobbos on your desktop."}],
	}
	var f := FileAccess.open(payload_dir.path_join(".claude-plugin/marketplace.json"), FileAccess.WRITE)
	if f == null:
		return "Could not write the plugin's marketplace (%s)." % error_string(FileAccess.get_open_error())
	f.store_string(JSON.stringify(market, "  ") + "\n")
	f.close()
	return ""


## Folder entries including hidden ones (.claude-plugin, .mcp.json).
static func _entries(path: String, dirs: bool) -> PackedStringArray:
	var d := DirAccess.open(path)
	if d == null:
		return PackedStringArray()
	d.include_hidden = true
	return d.get_directories() if dirs else d.get_files()


static func _copy_tree(from: String, to: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(to)
	if err != OK:
		return err
	for d in _entries(from, true):
		err = _copy_tree(from.path_join(d), to.path_join(d))
		if err != OK:
			return err
	for file in _entries(from, false):
		err = DirAccess.copy_absolute(from.path_join(file), to.path_join(file))
		if err != OK:
			return err
		FileAccess.set_unix_permissions(to.path_join(file), FileAccess.get_unix_permissions(from.path_join(file)))
	return OK


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in _entries(path, true):
		_remove_tree(path.path_join(d))
	for f in _entries(path, false):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
