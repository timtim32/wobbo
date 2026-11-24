extends RefCounted
## Connecting Wobbo to Claude Code (standalone-app design D9). Pure: which `claude`
## executable to use, what `claude plugin ... --json` printed, and which commands
## connect, update or disconnect. The `ClaudeSetup` node runs them.
##
## A step is {args: PackedStringArray, cwd: String}; cwd is "" for the user's home.

const PLUGIN := "wobbo"
const MARKETPLACE := "wobbo"
const PLUGIN_ID := "wobbo@wobbo"
## The plugin's name before the rename; installs of it are replaced on connect.
const OLD_PLUGIN := "buddy-bridge"
const INSTALL_PAGE := "https://claude.com/claude-code"


## Where Claude Code's CLI may be, in order: the usual install folders. The login
## shell's PATH and the Claude desktop app's copy are tried after these.
static func cli_candidates(home: String) -> PackedStringArray:
	return PackedStringArray([
		home.path_join(".local/bin/claude"),
		home.path_join(".claude/local/claude"),
		"/opt/homebrew/bin/claude",
		"/usr/local/bin/claude",
	])


## The Claude desktop app's own copy: the newest version folder under
## `~/Library/Application Support/Claude/claude-code/<version>/<build>/`.
## `versions` are the folder names; returns the version to use, or "".
static func newest_version(versions: PackedStringArray) -> String:
	var best := ""
	for v in versions:
		if _version_key(v).is_empty():
			continue
		if best.is_empty() or compare_versions(v, best) > 0:
			best = v
	return best


static func desktop_cli_path(build_dir: String) -> String:
	return build_dir.path_join("claude.app/Contents/MacOS/claude")


## -1, 0 or 1. Numeric parts compare as numbers ("0.10.0" > "0.9.1"); a missing
## part counts as 0. Non-numeric versions (git hashes) compare as equal.
static func compare_versions(a: String, b: String) -> int:
	var ka := _version_key(a)
	var kb := _version_key(b)
	for i in maxi(ka.size(), kb.size()):
		var x: int = ka[i] if i < ka.size() else 0
		var y: int = kb[i] if i < kb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


static func _version_key(v: String) -> Array[int]:
	var out: Array[int] = []
	for part in v.split("."):
		if not part.is_valid_int():
			return []
		out.append(part.to_int())
	return out


## `claude plugin list --json` -> [{id, name, marketplace, version, scope,
## enabled, project_path}]. Anything unreadable gives [].
static func parse_plugins(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: Variant = _json_array(text)
	if not data is Array:
		return out
	for p: Variant in data:
		if not p is Dictionary or not p.has("id"):
			continue
		var id := String(p.id)
		var at := id.find("@")
		out.append({
			"id": id,
			"name": id.left(at) if at >= 0 else id,
			"marketplace": id.substr(at + 1) if at >= 0 else "",
			"version": String(p.get("version", "")),
			"scope": String(p.get("scope", "user")),
			"enabled": bool(p.get("enabled", false)),
			"project_path": String(p.get("projectPath", "")),
		})
	return out


## `claude plugin marketplace list --json` -> [{name, path}].
static func parse_marketplaces(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: Variant = _json_array(text)
	if not data is Array:
		return out
	for m: Variant in data:
		if m is Dictionary and m.has("name"):
			out.append({"name": String(m.name), "path": String(m.get("path", m.get("installLocation", "")))})
	return out


## The JSON array in a command's output, skipping anything a login shell printed
## around it; null when there is none.
static func _json_array(text: String) -> Variant:
	var start := text.find("[")
	var end := text.rfind("]")
	if start < 0 or end < start:
		return null
	return JSON.parse_string(text.substr(start, end - start + 1))


## Wobbo's own plugin as installed at user scope, or {}.
static func own_plugin(plugins: Array[Dictionary]) -> Dictionary:
	for p in plugins:
		if p.id == PLUGIN_ID and p.scope == "user":
			return p
	return {}


## Connected: Wobbo's plugin is installed for the user and enabled.
static func connected_in(plugins: Array[Dictionary]) -> bool:
	var own := own_plugin(plugins)
	return not own.is_empty() and own.enabled


## Installs that would report sessions a second time (spec "No double
## reporting"): the old `buddy-bridge` from any marketplace, and `wobbo` from
## any marketplace but Wobbo's own, at any scope.
static func conflicting(plugins: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in plugins:
		if p.name == OLD_PLUGIN or (p.name == PLUGIN and p.marketplace != MARKETPLACE):
			out.append(p)
	return out


static func _step(args: Array, cwd := "") -> Dictionary:
	return {"args": PackedStringArray(args), "cwd": cwd}


static func _uninstall(p: Dictionary) -> Dictionary:
	var cwd: String = p.project_path if p.scope != "user" else ""
	return _step(["plugin", "uninstall", p.id, "--scope", p.scope, "--json"], cwd)


## Steps that make Wobbo connected, given what is installed now. The plugin
## payload lies in `payload_dir` and has version `payload_version`.
static func connect_steps(plugins: Array[Dictionary], marketplaces: Array[Dictionary],
		payload_dir: String, payload_version: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for p in conflicting(plugins):
		steps.append(_uninstall(p))
	steps.append_array(_marketplace_steps(marketplaces, payload_dir))
	var own := own_plugin(plugins)
	if own.is_empty():
		steps.append(_step(["plugin", "install", PLUGIN_ID, "--scope", "user", "--json"]))
	else:
		if compare_versions(own.version, payload_version) < 0:
			steps.append(_step(["plugin", "update", PLUGIN_ID, "--scope", "user", "--json"]))
		if not own.enabled:
			steps.append(_step(["plugin", "enable", PLUGIN_ID, "--scope", "user", "--json"]))
	return steps


## The marketplace must point at the payload folder: add it, refresh it, or
## replace it when it points elsewhere.
static func _marketplace_steps(marketplaces: Array[Dictionary], payload_dir: String) -> Array[Dictionary]:
	for m in marketplaces:
		if m.name != MARKETPLACE:
			continue
		if m.path.simplify_path() == payload_dir.simplify_path():
			return [_step(["plugin", "marketplace", "update", MARKETPLACE, "--json"])]
		return [_step(["plugin", "marketplace", "remove", MARKETPLACE, "--json"]),
			_step(["plugin", "marketplace", "add", payload_dir, "--json"])]
	return [_step(["plugin", "marketplace", "add", payload_dir, "--json"])]


## Whether an update is due on start (spec "Keeping the plugin current"):
## connected, and the installed plugin is older than the payload.
static func needs_update(plugins: Array[Dictionary], payload_version: String) -> bool:
	return connected_in(plugins) and compare_versions(own_plugin(plugins).version, payload_version) < 0


static func disconnect_steps(plugins: Array[Dictionary], marketplaces: Array[Dictionary]) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if not own_plugin(plugins).is_empty():
		steps.append(_step(["plugin", "uninstall", PLUGIN_ID, "--scope", "user", "--json"]))
	for m in marketplaces:
		if m.name == MARKETPLACE:
			steps.append(_step(["plugin", "marketplace", "remove", MARKETPLACE, "--json"]))
	return steps


## The message to show for a failed command: the "message" of its --json result
## line, else the first non-empty output line (✘ marks stripped), else "exit N".
static func error_line(output: String, exit_code: int) -> String:
	for line in output.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("{"):
			var data: Variant = JSON.parse_string(t)
			if data is Dictionary and data.has("message"):
				return String(data.message)
	for line in output.split("\n"):
		var t := line.strip_edges().trim_prefix("✘").strip_edges()
		if not t.is_empty():
			return t
	return "exit %d" % exit_code
