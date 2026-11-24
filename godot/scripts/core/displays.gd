extends RefCounted
## Matches macOS displays (MacOverlay.get_displays()) to Godot screen indices
## (multi-display design D6). Pure: callers pass both lists.


## `native`: [{id, name, frame: Rect2 (points, top-left origin), scale, main}]
## `godot_rects`: Godot screen rects in global px (index = screen index)
## `px_per_pt`: Godot's global scale (the largest screen scale)
## Returns [{id, name, main, scale, screen, frame_pt}] where `screen` is the
## Godot index (-1 when no screen matched) and `frame_pt` the native frame.
static func match(native: Array, godot_rects: Array, px_per_pt: float) -> Array:
	if native.is_empty():
		return []
	var min_corner := Vector2(INF, INF)
	for d in native:
		var f: Rect2 = d.frame
		min_corner = min_corner.min(f.position)
	var result := []
	var taken := {}
	for d in native:
		var f: Rect2 = d.frame
		var expected := Rect2((f.position - min_corner) * px_per_pt, f.size * px_per_pt)
		var best := -1
		var best_dist := INF
		for i in godot_rects.size():
			if taken.has(i):
				continue
			var r: Rect2 = godot_rects[i]
			var dist := r.position.distance_to(expected.position) + r.size.distance_to(expected.size)
			if dist < best_dist:
				best_dist = dist
				best = i
		if best >= 0 and best_dist <= 4.0 * px_per_pt:
			taken[best] = true
		else:
			best = -1
		result.append({"id": int(d.id), "name": String(d.name), "main": bool(d.main),
			"scale": float(d.scale), "screen": best, "frame_pt": f})
	return result
