extends "res://tests/base_test.gd"

const Plan := preload("res://scripts/core/claude_setup_plan.gd")
const PAYLOAD := "/Users/x/Library/Application Support/Wobbo/claude-plugin"

const OLD_ONLY := """[
  {"id": "buddy-bridge@buddy-local", "version": "0.1.5", "scope": "user", "enabled": true},
  {"id": "code-review@claude-plugins-official", "version": "1.0.1", "scope": "project", "enabled": false,
   "projectPath": "/Users/x/p"}
]"""
const CONNECTED := """[{"id": "wobbo@wobbo", "version": "0.2.0", "scope": "user", "enabled": true}]"""
const OLDER := """[{"id": "wobbo@wobbo", "version": "0.1.9", "scope": "user", "enabled": true}]"""
const DISABLED := """[{"id": "wobbo@wobbo", "version": "0.2.0", "scope": "user", "enabled": false}]"""
const DEV_AND_LOCAL := """[
  {"id": "wobbo@wobbo-dev", "version": "0.2.0", "scope": "user", "enabled": true},
  {"id": "buddy-bridge@buddy-local", "version": "0.1.5", "scope": "local", "enabled": true, "projectPath": "/Users/x/p"}
]"""
const MARKETS := """[
  {"name": "buddy-local", "source": "directory", "path": "/Users/x/claude-buddy"},
  {"name": "claude-plugins-official", "source": "github", "repo": "anthropics/claude-plugins-official"}
]"""


func _args(steps: Array[Dictionary]) -> Array:
	var out := []
	for s in steps:
		out.append(" ".join(s.args))
	return out


func test_cli_candidates_and_desktop_copy() -> void:
	var c := Plan.cli_candidates("/Users/x")
	assert_eq(c[0], "/Users/x/.local/bin/claude")
	assert_eq(c.size(), 4)
	assert_eq(Plan.newest_version(PackedStringArray(["2.1.9", "2.1.330", ".DS_Store", "2.0.99"])), "2.1.330")
	assert_eq(Plan.newest_version(PackedStringArray([])), "")
	assert_eq(Plan.desktop_cli_path("/a/2.1.330/4262"), "/a/2.1.330/4262/claude.app/Contents/MacOS/claude")


func test_compare_versions() -> void:
	assert_eq(Plan.compare_versions("0.10.0", "0.9.1"), 1)
	assert_eq(Plan.compare_versions("0.2.0", "0.2"), 0)
	assert_eq(Plan.compare_versions("0.1.9", "0.2.0"), -1)


func test_parse_plugins() -> void:
	var p := Plan.parse_plugins(OLD_ONLY)
	assert_eq(p.size(), 2)
	assert_eq(p[0].name, "buddy-bridge")
	assert_eq(p[0].marketplace, "buddy-local")
	assert_eq(p[1].project_path, "/Users/x/p")
	assert_eq(Plan.parse_plugins("not json").size(), 0, "unreadable output")
	assert_eq(Plan.parse_plugins("").size(), 0, "no output")
	assert_eq(Plan.parse_plugins("Last login: today\n" + CONNECTED + "\n").size(), 1, "shell noise around the JSON")


func test_connected_state() -> void:
	assert_false(Plan.connected_in(Plan.parse_plugins(OLD_ONLY)), "only the old plugin")
	assert_true(Plan.connected_in(Plan.parse_plugins(CONNECTED)), "connected")
	assert_false(Plan.connected_in(Plan.parse_plugins(DISABLED)), "disabled is not connected")


func test_connect_replaces_the_old_plugin() -> void:
	var steps := Plan.connect_steps(Plan.parse_plugins(OLD_ONLY), Plan.parse_marketplaces(MARKETS), PAYLOAD, "0.2.0")
	assert_eq(_args(steps), [
		"plugin uninstall buddy-bridge@buddy-local --scope user --json",
		"plugin marketplace add %s --json" % PAYLOAD,
		"plugin install wobbo@wobbo --scope user --json",
	])


func test_connect_from_nothing() -> void:
	var steps := Plan.connect_steps([], [], PAYLOAD, "0.2.0")
	assert_eq(_args(steps), ["plugin marketplace add %s --json" % PAYLOAD, "plugin install wobbo@wobbo --scope user --json"])


func test_connect_removes_dev_and_project_installs() -> void:
	var steps := Plan.connect_steps(Plan.parse_plugins(DEV_AND_LOCAL), [], PAYLOAD, "0.2.0")
	assert_eq(_args(steps).slice(0, 2), [
		"plugin uninstall wobbo@wobbo-dev --scope user --json",
		"plugin uninstall buddy-bridge@buddy-local --scope local --json",
	])
	assert_eq(steps[1].cwd, "/Users/x/p", "a local install is removed from its project")


func test_connect_when_marketplace_points_elsewhere() -> void:
	var markets := Plan.parse_marketplaces("""[{"name": "wobbo", "path": "/Volumes/Wobbo/Wobbo.app/x"}]""")
	assert_eq(_args(Plan.connect_steps([], markets, PAYLOAD, "0.2.0")).slice(0, 2), [
		"plugin marketplace remove wobbo --json", "plugin marketplace add %s --json" % PAYLOAD])
	markets = Plan.parse_marketplaces("""[{"name": "wobbo", "path": "%s"}]""" % PAYLOAD)
	assert_eq(_args(Plan.connect_steps([], markets, PAYLOAD, "0.2.0"))[0], "plugin marketplace update wobbo --json")


func test_connect_enables_or_updates_an_existing_install() -> void:
	var markets := Plan.parse_marketplaces("""[{"name": "wobbo", "path": "%s"}]""" % PAYLOAD)
	assert_eq(_args(Plan.connect_steps(Plan.parse_plugins(DISABLED), markets, PAYLOAD, "0.2.0")),
		["plugin marketplace update wobbo --json", "plugin enable wobbo@wobbo --scope user --json"])
	assert_eq(_args(Plan.connect_steps(Plan.parse_plugins(OLDER), markets, PAYLOAD, "0.2.0")),
		["plugin marketplace update wobbo --json", "plugin update wobbo@wobbo --scope user --json"])


func test_needs_update() -> void:
	assert_true(Plan.needs_update(Plan.parse_plugins(OLDER), "0.2.0"), "older installed")
	assert_false(Plan.needs_update(Plan.parse_plugins(CONNECTED), "0.2.0"), "same version")
	assert_false(Plan.needs_update(Plan.parse_plugins(OLD_ONLY), "0.2.0"), "not connected")


func test_disconnect() -> void:
	var markets := Plan.parse_marketplaces("""[{"name": "wobbo", "path": "%s"}]""" % PAYLOAD)
	assert_eq(_args(Plan.disconnect_steps(Plan.parse_plugins(CONNECTED), markets)),
		["plugin uninstall wobbo@wobbo --scope user --json", "plugin marketplace remove wobbo --json"])
	assert_eq(Plan.disconnect_steps([], []).size(), 0, "nothing to remove")


func test_error_line() -> void:
	var out := "{\"command\":\"uninstall\",\"outcome\":\"failed\",\"message\":\"Plugin not found\"}\n✘ Failed to uninstall"
	assert_eq(Plan.error_line(out, 1), "Plugin not found")
	assert_eq(Plan.error_line("\n✘ Something broke\nmore", 1), "Something broke")
	assert_eq(Plan.error_line("", 3), "exit 3")
