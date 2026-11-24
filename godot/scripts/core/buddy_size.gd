extends RefCounted
## The buddy sizes in the "Size" menu (buddy-size design D2). Pure.

const DEFAULT := "normal"
## key -> [label, height in points], in menu order.
const STEPS := {
	"small": ["Small", 80.0],
	"normal": ["Normal", 110.0],
	"large": ["Large", 140.0],
	"xl": ["Extra large", 170.0],
}


static func height_of(key: String) -> float:
	return float(STEPS.get(key, STEPS[DEFAULT])[1])


## [{label, value, checked}], exactly one checked (an unknown key checks Normal).
static func items(key: String) -> Array[Dictionary]:
	var chosen := key if STEPS.has(key) else DEFAULT
	var out: Array[Dictionary] = []
	for k: String in STEPS:
		out.append({"label": STEPS[k][0], "value": k, "checked": k == chosen})
	return out
