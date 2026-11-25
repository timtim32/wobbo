class_name Walkway
extends RefCounted
## The walkway (multi-display design D2): the bottom strips of all displays as
## one line in points, ordered left to right by the displays' desk positions.
## Pure: built from plain data, unit tested headless.
##
## A walkway x in [segment.start, segment.start + segment.width) belongs to that
## segment; walkway y is in points from the top of a strip (same on all strips).
##
## Neighbouring segments are joined by a Link (side-climb D1): an `edge` (walk
## off the end of one, in at the start of the next) or, for stacked displays, a
## `climb` along a side edge of the lower display.

## Room a buddy needs next to a climb edge on the upper display (the largest size).
const CLIMB_ROOM_PT := 180.0
## Tolerance for "touching" display edges, in points.
const TOUCH_PT := 1.0


class Segment:
	extends RefCounted
	var id: int
	var name: String
	var main: bool
	var rect_px: Rect2 # the strip's rect in Godot's global pixel space
	var frame_px: Rect2 # the whole display in global px (empty when unknown)
	var start: float # walkway x of the left edge, in points
	var width: float # in points

	func end() -> float:
		return start + width

	func center_px() -> Vector2:
		return rect_px.get_center()


## One side edge of the lower display that a buddy can climb (side-climb D1).
class ClimbSide:
	extends RefCounted
	var dir: int # 1: the lower display's right edge, -1: its left edge
	var lower_x: float # walkway x of the edge on the lower segment
	var upper_x: float # walkway x of the same desk x on the upper segment

	## Walkway x of the centre of a body of half-width `half` hugging the edge.
	func body_x(on_upper: bool, half: float) -> float:
		return (upper_x if on_upper else lower_x) - dir * half


## The join between segments i and i + 1.
class Link:
	extends RefCounted
	var kind: StringName = &"edge" # &"edge" or &"climb"
	var lower := -1
	var upper := -1
	var sides: Array[ClimbSide] = []
	## Walkway y (on the lower strip) of the lower display's top edge (< 0).
	var top_y := 0.0
	## Add to a walkway y on the lower strip to get the same desk height on the upper strip.
	var upper_dy := 0.0


var segments: Array[Segment] = []
var links: Array[Link] = []
var px_per_pt := 1.0


## `strips`: [{id, name, main, rect_px: Rect2, frame_px: Rect2 (optional, the
## whole display in Godot's global px)}] in any order.
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
		seg.frame_px = s.get("frame_px", Rect2())
		seg.start = x
		seg.width = seg.rect_px.size.x / p_px_per_pt
		x += seg.width
		w.segments.append(seg)
	for i in w.segments.size() - 1:
		w.links.append(w._make_link(i, i + 1))
	return w


func _make_link(a: int, b: int) -> Link:
	var link := Link.new()
	var fa := segments[a].frame_px
	var fb := segments[b].frame_px
	if not fa.has_area() or not fb.has_area():
		return link
	var tol := TOUCH_PT * px_per_pt
	var lower := -1
	if absf(fb.end.y - fa.position.y) <= tol:
		lower = a # b stands on a
	elif absf(fa.end.y - fb.position.y) <= tol:
		lower = b
	if lower < 0:
		return link
	var upper := b if lower == a else a
	var fl := segments[lower].frame_px
	var fu := segments[upper].frame_px
	var room := CLIMB_ROOM_PT * px_per_pt
	for dir in [1, -1]:
		var edge: float = fl.end.x if dir == 1 else fl.position.x
		var covers: bool
		if dir == 1:
			covers = fu.end.x >= edge - tol and fu.position.x <= edge - room
		else:
			covers = fu.position.x <= edge + tol and fu.end.x >= edge + room
		if not covers:
			continue
		var side := ClimbSide.new()
		side.dir = dir
		side.lower_x = desk_to_walkway_x(lower, edge)
		side.upper_x = desk_to_walkway_x(upper, edge)
		link.sides.append(side)
	if link.sides.is_empty():
		return link
	link.kind = &"climb"
	link.lower = lower
	link.upper = upper
	link.top_y = (fl.position.y - segments[lower].rect_px.position.y) / px_per_pt
	link.upper_dy = (segments[lower].rect_px.position.y - segments[upper].rect_px.position.y) / px_per_pt
	return link


## Walkway x on segment i of a desk x in global px.
func desk_to_walkway_x(i: int, x_px: float) -> float:
	return segments[i].start + (x_px - segments[i].rect_px.position.x) / px_per_pt


## Walkway point `point` given on segment `from`, as the walkway point at the
## same place on the desk expressed on segment `to` (side-climb D4).
func across(from: int, to: int, point: Vector2) -> Vector2:
	var a := segments[from]
	var b := segments[to]
	var global := a.rect_px.position + Vector2(point.x - a.start, point.y) * px_per_pt
	var p := (global - b.rect_px.position) / px_per_pt
	return Vector2(p.x + b.start, p.y)


## Climb links that join segment i to a neighbour (0, 1 or 2).
func climb_links_of(i: int) -> Array[Link]:
	var out: Array[Link] = []
	for k in [i - 1, i]:
		if k >= 0 and k < links.size() and links[k].kind == &"climb":
			out.append(links[k])
	return out


## Where a body with feet at `point` on segment `from` belongs after moving
## over the seam of stacked displays (side-climb: carrying and throwing):
## above the lower display's top edge onto the upper segment, below the upper
## strip's bottom onto the lower one, when the other display is there at that
## x (with room for `half` on both sides). Returns {strip, point}; strip is
## `from` when it stays.
func over_seam(from: int, point: Vector2, half: float, strip_height: float) -> Dictionary:
	for link in climb_links_of(from):
		var other := -1
		if from == link.lower and point.y < link.top_y:
			other = link.upper
		elif from == link.upper and point.y > strip_height:
			other = link.lower
		if other < 0:
			continue
		var p := across(from, other, point)
		var seg := segments[other]
		if p.x - half >= seg.start and p.x + half <= seg.end():
			return {"strip": other, "point": p}
	return {"strip": from, "point": point}


## True when a display stands on segment i's display above walkway x (with room
## for `half`): a body there may fly up out of the top of strip i.
func open_above(i: int, x: float, half: float) -> bool:
	for link in climb_links_of(i):
		if link.lower != i:
			continue
		var p := across(i, link.upper, Vector2(x, link.top_y))
		var seg := segments[link.upper]
		if p.x - half >= seg.start and p.x + half <= seg.end():
			return true
	return false


## The link between neighbouring segments i and j, or null.
func link_between(i: int, j: int) -> Link:
	if absi(i - j) != 1 or mini(i, j) >= links.size():
		return null
	return links[mini(i, j)]


## What a body at walkway x on segment `from` does next to reach walkway x
## `target` on segment `to` (side-climb D2):
## {kind: &"walk", x} walk to x (across edge links, as before);
## {kind: &"climb", link, side} it stands at the side's foot (or top) and climbs.
## `side` keeps the side chosen earlier for the next climb link (or null).
func next_step(from: int, x: float, to: int, target: float, half: float, side: ClimbSide = null) -> Dictionary:
	if from == to or segments.is_empty():
		return {"kind": &"walk", "x": target}
	var step := 1 if to > from else -1
	var k := from
	while k != to:
		var link := links[mini(k, k + step)]
		if link.kind == &"climb":
			if k != from:
				# Walk onto segment k first (across edge links).
				var seg := segments[k]
				return {"kind": &"walk", "x": seg.start + half if step > 0 else seg.end() - half}
			var on_upper := from == link.upper
			var next := from + step
			var aim := target if next == to else segments[next].start + segments[next].width * 0.5
			var chosen: ClimbSide = side if side != null and side in link.sides else _shortest_side(link, on_upper, x, aim, half)
			var foot := chosen.body_x(on_upper, half)
			if absf(x - foot) > 0.5:
				return {"kind": &"walk", "x": foot, "side": chosen}
			return {"kind": &"climb", "link": link, "side": chosen}
		k += step
	return {"kind": &"walk", "x": target}


func _shortest_side(link: Link, on_upper: bool, x: float, aim: float, half: float) -> ClimbSide:
	var best: ClimbSide = link.sides[0]
	var best_cost := INF
	for s in link.sides:
		var cost := absf(x - s.body_x(on_upper, half)) + absf(aim - s.body_x(not on_upper, half))
		if cost < best_cost:
			best_cost = cost
			best = s
	return best


## Walkway x beyond which a leaving body at x is gone (side-climb D6): beyond the
## nearer end of the walkway, unless that way crosses a climb link; then beyond
## the nearer end of its own run of segments joined by edges.
func exit_x(x: float, half: float, margin: float) -> float:
	if segments.is_empty():
		return x
	var run := run_bounds(index_at(x))
	return run.x - half - margin if x - run.x < run.y - x else run.y + half + margin


## Walkway x of the start and end of the run of segments around segment i that
## are joined by edge links (the whole walkway without climb links).
func run_bounds(i: int) -> Vector2:
	var first := i
	while first > 0 and links[first - 1].kind != &"climb":
		first -= 1
	var last := i
	while last < links.size() and links[last].kind != &"climb":
		last += 1
	return Vector2(segments[first].start, segments[last].end())


## True when segments a and b are joined by edge links only.
func same_run(a: int, b: int) -> bool:
	for k in range(mini(a, b), maxi(a, b)):
		if links[k].kind == &"climb":
			return false
	return true


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
