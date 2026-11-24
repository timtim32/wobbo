class_name Walkway
extends RefCounted
## The walkway (multi-display design D2): the bottom strips of all displays as
## one line in points, ordered left to right by the displays' desk positions.
## Pure: built from plain data, unit tested headless.
##
## A walkway x in [segment.start, segment.start + segment.width) belongs to that
## segment; walkway y is in points from the top of a strip (same on all strips).


class Segment:
	extends RefCounted
	var id: int
	var name: String
	var main: bool
	var rect_px: Rect2 # the strip's rect in Godot's global pixel space
	var start: float # walkway x of the left edge, in points
	var width: float # in points

	func end() -> float:
		return start + width

	func center_px() -> Vector2:
		return rect_px.get_center()


var segments: Array[Segment] = []
var px_per_pt := 1.0


## `strips`: [{id, name, main, rect_px: Rect2}] in any order.
static func build(strips: Array, p_px_per_pt: float) -> Walkway:
	var w := Walkway.new()
	w.px_per_pt = p_px_per_pt
	var sorted := strips.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		var ra: Rect2 = a.rect_px
		var rb: Rect2 = b.rect_px
		return ra.position.x < rb.position.x or (ra.position.x == rb.position.x and ra.position.y < rb.position.y))
	var x := 0.0
	for s in sorted:
		var seg := Segment.new()
		seg.id = int(s.id)
		seg.name = String(s.get("name", ""))
		seg.main = bool(s.get("main", false))
		seg.rect_px = s.rect_px
		seg.start = x
		seg.width = seg.rect_px.size.x / p_px_per_pt
		x += seg.width
		w.segments.append(seg)
	return w


func total_width() -> float:
	return 0.0 if segments.is_empty() else segments[-1].end()


func is_empty() -> bool:
	return segments.is_empty()


## Index of the segment containing walkway x (clamped to the ends).
func index_at(x: float) -> int:
	for i in segments.size():
		if x < segments[i].end():
			return i
	return segments.size() - 1


func index_of(id: int) -> int:
	for i in segments.size():
		if segments[i].id == id:
			return i
	return -1


func main_index() -> int:
	for i in segments.size():
		if segments[i].main:
			return i
	return 0


## Local points of walkway x within segment `index` (may be outside 0..width).
func to_local(index: int, x: float) -> float:
	return x - segments[index].start


## Segments whose span overlaps `rect` (walkway points) horizontally: the
## windows that must show a view of a body with that rect (multi-display D3).
func indices_overlapping(rect: Rect2) -> Array[int]:
	var hits: Array[int] = []
	for i in segments.size():
		if rect.position.x < segments[i].end() and rect.end.x > segments[i].start:
			hits.append(i)
	return hits


## True when a body centred at x with half-width `half` is fully on segment i.
func fully_on(i: int, x: float, half: float) -> bool:
	return x - half >= segments[i].start - 0.01 and x + half <= segments[i].end() + 0.01


## Direction (-1, 0 or 1) a body at x has to travel to be fully on segment i.
func direction_to(i: int, x: float, half: float) -> int:
	if fully_on(i, x, half):
		return 0
	return 1 if x < segments[i].start + segments[i].width * 0.5 else -1


## Maps walkway x from `old` (the walkway before a display change) to this
## walkway: same place on the same display if it still exists, else the nearest
## edge of the closest remaining display.
func remap(x: float, old: Walkway) -> float:
	if segments.is_empty():
		return x
	if old == null or old.is_empty():
		return clampf(x, 0.0, total_width())
	var old_index: int = old.index_at(x)
	var old_seg := old.segments[old_index]
	var local: float = x - old_seg.start
	var same := index_of(old_seg.id)
	if same >= 0:
		return segments[same].start + clampf(local, 0.0, segments[same].width)
	var best := 0
	var best_dist := INF
	for i in segments.size():
		var d := segments[i].center_px().distance_to(old_seg.center_px())
		if d < best_dist:
			best_dist = d
			best = i
	var seg := segments[best]
	return seg.start if old_seg.center_px().x < seg.center_px().x else seg.end()
