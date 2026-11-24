extends RefCounted
## The app-level menu items of standalone-app (design D7, D9): the Claude Code
## connection item, "Open at Login", and when Wobbo should offer to move itself.
## Pure, so the menu and the welcome stay simple.


## Whether this run is the exported app, not an editor run.
static func is_exported(has_template_feature: bool) -> bool:
	return has_template_feature


## {label, disabled} of the Claude Code item.
static func claude_item(connected: bool, busy: bool) -> Dictionary:
	if busy:
		return {"label": "Connecting to Claude Code…", "disabled": true}
	if connected:
		return {"label": "Disconnect from Claude Code", "disabled": false}
	return {"label": "Connect to Claude Code…", "disabled": false}


## {enabled, checked} of "Open at Login": only an exported app in an
## Applications folder can be a login item; the check mark is macOS's state.
static func login_item(exported: bool, location: String, status: String) -> Dictionary:
	return {"enabled": exported and location == "applications" and status != "unavailable",
		"checked": status == "enabled"}


## Whether to offer "Move to Applications" (spec "Moving to Applications").
static func offer_move(exported: bool, location: String) -> bool:
	return exported and location != "applications"
