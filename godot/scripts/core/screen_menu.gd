extends RefCounted
## Items of the "Screen" submenu (multi-display design D8). Pure.

const AUTO_LABEL := "Automatic (follow the mouse)"


## `displays`: [{id, name, main}] connected now; `setting`: "auto" or a display
## id; `remembered_name`: the chosen display's name (for when it is missing).
## Returns [{label, value, checked, disabled, separator}].
static func items(displays: Array, setting: String, remembered_name: String) -> Array:
	var list := [{"label": AUTO_LABEL, "value": "auto", "checked": setting == "auto", "disabled": false,
		"separator": false}]
	list.append({"label": "", "value": "", "checked": false, "disabled": true, "separator": true})
	var found := false
	for d in displays:
		var value := str(d.id)
		var label: String = d.name + (" (main)" if d.main else "")
		found = found or value == setting
		list.append({"label": label, "value": value, "checked": value == setting, "disabled": false,
			"separator": false})
	if setting != "auto" and not found:
		var name := remembered_name if not remembered_name.is_empty() else "Display %s" % setting
		list.append({"label": "%s (not connected)" % name, "value": setting, "checked": true,
			"disabled": true, "separator": false})
	return list
