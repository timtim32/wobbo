extends "res://tests/base_test.gd"
## ClaudeSetup with a fake `claude` CLI: a small model of Claude Code's plugin
## state that records each command (standalone-app design D9).

const ClaudeSetup := preload("res://scripts/setup/claude_setup.gd")
const ROOT := "user://test_claude_setup"

var _root := ""
var _setup: Node
## id -> {version, scope, enabled}
var plugins := {}
## name -> path
var markets := {}
var commands: Array[String] = []
var fail_on := ""
var results: Array = []
## Calls of the bridge's `claude-desktop` command: "<binary> <args>".
var desktop_calls: Array[String] = []
var desktop_out := "unchanged"
var desktop_exit := 0


func before_each() -> void:
	_root = ProjectSettings.globalize_path(ROOT)
	ClaudeSetup._remove_tree(_root)
	var src := _root.path_join("source")
	DirAccess.make_dir_recursive_absolute(src.path_join(".claude-plugin"))
	DirAccess.make_dir_recursive_absolute(src.path_join("bin"))
	_write(src.path_join(".claude-plugin/plugin.json"), "{\"name\": \"wobbo\", \"version\": \"0.2.0\"}")
	_write(src.path_join(".mcp.json"), "{}")
	_write(src.path_join("bin/wobbo-bridge"), "#!/bin/sh\n")
	FileAccess.set_unix_permissions(src.path_join("bin/wobbo-bridge"), 493) # 0755
	plugins = {}
	markets = {}
	commands = []
	fail_on = ""
	results = []
	desktop_calls = []
	desktop_out = "unchanged"
	desktop_exit = 0
	_setup = ClaudeSetup.new()
	_setup.runner = _fake
	_setup.sync = true
	_setup.cli_path = "/fake/claude"
	_setup.plugin_source = src
	_setup.payload_dir = _root.path_join("payload")
	_setup.finished.connect(func(action: StringName, r: Dictionary) -> void: results.append([action, r]))


func after_each() -> void:
	_setup.free()
	ClaudeSetup._remove_tree(_root)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _fake(program: String, args: PackedStringArray) -> Dictionary:
	if program.ends_with("/wobbo-bridge"):
		desktop_calls.append("%s %s" % [program, " ".join(args)])
		return {"exit": desktop_exit, "output": desktop_out}
	assert_eq(program, "/bin/zsh", "runs through the login shell")
	assert_true(args[1].contains("unset"), "drops Claude Code's session variables first")
	var cmd := " ".join(args.slice(5))
	commands.append(cmd)
	if not fail_on.is_empty() and cmd.begins_with(fail_on):
		return {"exit": 1, "output": "{\"outcome\":\"failed\",\"message\":\"boom\"}"}
	var a := args.slice(5)
	match " ".join(a.slice(0, 2)):
		"plugin list":
			var list := []
			for id: String in plugins:
				list.append({"id": id, "version": plugins[id].version, "scope": plugins[id].scope, "enabled": plugins[id].enabled})
			return {"exit": 0, "output": JSON.stringify(list)}
		"plugin marketplace":
			match a[2]:
				"list":
					var list := []
					for n: String in markets:
						list.append({"name": n, "path": markets[n]})
					return {"exit": 0, "output": JSON.stringify(list)}
				"add":
					markets["wobbo"] = a[3]
				"remove":
					markets.erase(a[3])
			return {"exit": 0, "output": "{}"}
		"plugin install":
			plugins[a[2]] = {"version": "0.2.0", "scope": "user", "enabled": true}
		"plugin update":
			plugins[a[2]].version = "0.2.0"
		"plugin enable":
			plugins[a[2]].enabled = true
		"plugin uninstall":
			plugins.erase(a[2])
	return {"exit": 0, "output": "{}"}


func _changes() -> Array[String]:
	var out: Array[String] = []
	for c in commands:
		if not c.begins_with("plugin list") and not c.begins_with("plugin marketplace list"):
			out.append(c.get_slice(" --", 0))
	return out


func test_connect_replaces_buddy_bridge() -> void:
	plugins["buddy-bridge@buddy-local"] = {"version": "0.1.5", "scope": "user", "enabled": true}
	_setup.connect_claude()
	var payload := _root.path_join("payload")
	assert_eq(_changes(), ["plugin uninstall buddy-bridge@buddy-local", "plugin marketplace add " + payload,
		"plugin install wobbo@wobbo"])
	assert_true(_setup.connected, "connected")
	assert_eq(results[0][0], &"connect")
	assert_true(results[0][1].ok, "reported ok")
	assert_true(FileAccess.file_exists(payload.path_join(".claude-plugin/marketplace.json")), "marketplace written")
	assert_true(FileAccess.file_exists(payload.path_join("plugins/wobbo/.mcp.json")), "hidden files copied")
	assert_eq(FileAccess.get_unix_permissions(payload.path_join("plugins/wobbo/bin/wobbo-bridge")) & 73, 73, # 0111
		"the bridge stays executable")


func test_connect_from_scratch() -> void:
	_setup.connect_claude()
	assert_eq(_changes(), ["plugin marketplace add " + _root.path_join("payload"), "plugin install wobbo@wobbo"])
	assert_false(_setup.busy, "not busy afterwards")


func test_failure_stops_the_sequence() -> void:
	fail_on = "plugin marketplace add"
	_setup.connect_claude()
	assert_false(results[0][1].ok, "reported failed")
	assert_eq(results[0][1].message, "boom", "Claude Code's message")
	assert_false(_changes().has("plugin install wobbo@wobbo"), "nothing installed after a failure")
	assert_false(_setup.connected)


func test_disconnect() -> void:
	plugins["wobbo@wobbo"] = {"version": "0.2.0", "scope": "user", "enabled": true}
	markets["wobbo"] = "/x"
	_setup.disconnect_claude()
	assert_eq(_changes(), ["plugin uninstall wobbo@wobbo", "plugin marketplace remove wobbo"])
	assert_false(_setup.connected)


func test_update_when_older() -> void:
	plugins["wobbo@wobbo"] = {"version": "0.1.9", "scope": "user", "enabled": true}
	markets["wobbo"] = _root.path_join("payload")
	_setup.update_if_needed()
	assert_eq(_changes(), ["plugin marketplace update wobbo", "plugin update wobbo@wobbo"])
	assert_eq(results.size(), 1, "one announcement")
	assert_eq(results[0][0], &"update")
	assert_eq(results[0][1].message, "0.2.0", "the new version")


func test_no_update_when_current() -> void:
	plugins["wobbo@wobbo"] = {"version": "0.2.0", "scope": "user", "enabled": true}
	_setup.update_if_needed()
	assert_eq(_changes(), [], "no commands that change anything")
	assert_eq(results.size(), 0, "nothing announced")


func _copied_bridge() -> String:
	return _root.path_join("payload/plugins/wobbo/bin/wobbo-bridge")


func test_connect_sets_up_claude_desktop_with_the_copied_bridge() -> void:
	desktop_out = "added"
	_setup.connect_claude()
	assert_eq(desktop_calls, [_copied_bridge() + " claude-desktop connect"])
	assert_eq(results[0][1].desktop, "added")
	assert_true(results[0][1].ok)


func test_claude_desktop_failure_does_not_fail_the_connect() -> void:
	desktop_exit = 1
	desktop_out = "Claude Desktop's configuration is not valid JSON"
	_setup.connect_claude()
	assert_true(results[0][1].ok, "still connected")
	assert_true(_setup.connected)
	assert_eq(results[0][1].desktop, "")


func test_failed_connect_leaves_claude_desktop_alone() -> void:
	fail_on = "plugin install"
	_setup.connect_claude()
	assert_eq(desktop_calls, [], "no Claude Desktop step")


func test_disconnect_removes_the_claude_desktop_entry() -> void:
	plugins["wobbo@wobbo"] = {"version": "0.2.0", "scope": "user", "enabled": true}
	desktop_out = "removed"
	_setup.disconnect_claude()
	# No copy yet: falls back to the bridge Wobbo carries.
	assert_eq(desktop_calls, [_root.path_join("source/bin/wobbo-bridge") + " claude-desktop disconnect"])
	assert_eq(results[0][1].desktop, "removed")


func test_start_adds_the_claude_desktop_entry_while_connected() -> void:
	plugins["wobbo@wobbo"] = {"version": "0.2.0", "scope": "user", "enabled": true}
	desktop_out = "added"
	_setup.update_if_needed()
	assert_true(FileAccess.file_exists(_copied_bridge()), "the bridge is copied first")
	assert_eq(desktop_calls, [_copied_bridge() + " claude-desktop connect"])
	assert_eq(_changes(), [], "the plugin is left as it is")
	assert_eq(results.size(), 1, "announced")
	assert_eq(results[0][1].message, "", "no plugin update")
	assert_eq(results[0][1].desktop, "added")


func test_start_while_not_connected_leaves_claude_desktop_alone() -> void:
	_setup.update_if_needed()
	assert_eq(desktop_calls, [])
	assert_eq(results.size(), 0)


func test_update_also_reports_claude_desktop() -> void:
	plugins["wobbo@wobbo"] = {"version": "0.1.9", "scope": "user", "enabled": true}
	markets["wobbo"] = _root.path_join("payload")
	desktop_out = "updated"
	_setup.update_if_needed()
	assert_eq(results[0][1].message, "0.2.0")
	assert_eq(results[0][1].desktop, "updated")


func test_welcome_texts_for_claude_desktop() -> void:
	var Welcome := preload("res://scripts/setup/welcome.gd")
	assert_true(Welcome.connected_text("added").contains("Claude Desktop"))
	assert_false(Welcome.connected_text("absent").contains("Claude Desktop"))
	assert_false(Welcome.connected_text("unchanged").contains("Claude Desktop"))
	assert_true(Welcome.updated_text("", "added").contains("Restart Claude Desktop"))
	assert_true(Welcome.updated_text("0.3.0", "updated").ends_with("Restart Claude Desktop too."))
	assert_false(Welcome.updated_text("0.3.0", "unchanged").contains("Claude Desktop"))


func test_execute_runs_a_program_in_a_folder_with_spaces() -> void:
	var dir := _root.path_join("Application Support")
	DirAccess.make_dir_recursive_absolute(dir)
	_write(dir.path_join("say"), "#!/bin/sh\necho \"ran $1\"\n")
	FileAccess.set_unix_permissions(dir.path_join("say"), 493)
	var r := ClaudeSetup.execute(dir.path_join("say"), PackedStringArray(["connect"]))
	assert_eq(r.exit, 0)
	assert_eq(r.output.strip_edges(), "ran connect")


func test_not_found() -> void:
	_setup.cli_path = ""
	_setup.runner = func(_p: String, _a: PackedStringArray) -> Dictionary: return {"exit": 1, "output": ""}
	# The real home may have Claude Code; point the search elsewhere.
	var home := OS.get_environment("HOME")
	OS.set_environment("HOME", _root)
	_setup.connect_claude()
	OS.set_environment("HOME", home)
	assert_true(results[0][1].not_found, "not found")
	assert_false(DirAccess.dir_exists_absolute(_root.path_join("payload")), "nothing copied")


func test_refresh_reads_the_state() -> void:
	plugins["wobbo@wobbo"] = {"version": "0.2.0", "scope": "user", "enabled": true}
	var seen := []
	_setup.state_changed.connect(func(c: bool) -> void: seen.append(c))
	_setup.refresh(true)
	assert_eq(seen, [true])
	assert_eq(_setup.installed_version, "0.2.0")
	_setup.refresh()
	assert_eq(commands.size(), 1, "a fresh state is not read again")


func test_the_run_script_drops_session_variables() -> void:
	# Through the real execute(), as the app runs it: the command must run with
	# its arguments intact, without Claude Code's session variables but with
	# CLAUDE_CONFIG_DIR.
	var r := ClaudeSetup.execute("/usr/bin/env", PackedStringArray(["CLAUDECODE=1", "CLAUDE_CODE_SESSION_ID=x",
		"CLAUDE_CONFIG_DIR=/tmp/cfg", "/bin/zsh", "-c", ClaudeSetup.RUN_SCRIPT, "wobbo", "/", "/usr/bin/env"]))
	assert_eq(r.exit, 0, "the script ran")
	assert_true(r.output.contains("PATH="), "the command ran")
	assert_false(r.output.contains("CLAUDECODE="), "CLAUDECODE removed")
	assert_false(r.output.contains("CLAUDE_CODE_SESSION_ID="), "CLAUDE_CODE_SESSION_ID removed")
	assert_true(r.output.contains("CLAUDE_CONFIG_DIR=/tmp/cfg"), "CLAUDE_CONFIG_DIR kept")


func test_arguments_reach_the_program_literally() -> void:
	var odd := "a $HOME `id` \\n \"q\" b"
	var r := ClaudeSetup.execute("/usr/bin/printf", PackedStringArray(["%s", odd]))
	assert_eq(r.output, odd, "no expansion by sh")
