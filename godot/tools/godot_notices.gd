extends SceneTree
## Writes the copyright notices and licence texts of the Godot engine and its
## third-party components, as the running engine reports them, for the app
## bundle (open-source-readiness D5). tools/release.sh runs it on every build, so
## the list always matches the engine version. Usage (from the repo root):
##   Godot --headless --path godot --script res://tools/godot_notices.gd -- --out=<file>


func _init() -> void:
	var lines: PackedStringArray = []
	lines.append("Godot Engine %s and its third-party components" % Engine.get_version_info().string)
	lines.append("")
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("== %s" % component.name)
		for part: Dictionary in component.parts:
			for holder: String in part.copyright:
				lines.append("   Copyright (c) %s" % holder)
			lines.append("   License: %s" % part.license)
		lines.append("")
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for license_name: String in names:
		lines.append("=".repeat(72))
		lines.append(license_name)
		lines.append("=".repeat(72))
		lines.append("")
		lines.append(licenses[license_name])
		lines.append("")
	lines.append("=".repeat(72))
	lines.append("Godot Engine (Expat / MIT)")
	lines.append("=".repeat(72))
	lines.append("")
	lines.append(Engine.get_license_text())
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var file := FileAccess.open(out, FileAccess.WRITE) if out else null
	if file == null:
		printerr("godot_notices: give a writable file with -- --out=<file>")
		quit(1)
		return
	file.store_string("\n".join(lines))
	quit()
