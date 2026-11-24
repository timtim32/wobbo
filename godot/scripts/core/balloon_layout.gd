extends RefCounted
## Where a balloon goes (balloons-and-speech design D6). Pure, in walkway points:
## y grows downwards from the strip's top edge (0).

## Distance from the balloon to the display's side edges.
const SIDE_MARGIN_PT := 8.0
## Distance from the head to the tail's tip.
const GAP_PT := 6.0
const TAIL_PT := 10.0
const TAIL_HALF_WIDTH_PT := 7.0
const CORNER_PT := 10.0
## Room kept free above the balloon.
const TOP_MARGIN_PT := 4.0
const MIN_WIDTH_PT := 120.0
const MAX_WIDTH_PT := 300.0


## The tallest balloon that fits above a head whose top is at `head_top_y`.
static func max_height(head_top_y: float) -> float:
	return maxf(0.0, head_top_y - GAP_PT - TAIL_PT - TOP_MARGIN_PT)


## Width for content that needs `content_width` points, kept between 120 and 300.
static func width_for(content_width: float) -> float:
	return clampf(content_width, MIN_WIDTH_PT, MAX_WIDTH_PT)


## {rect: Rect2, tail_x: float} for a balloon of `size` above a head at
## (`head_x`, `head_top_y`) on the display segment [seg_start, seg_end].
## The balloon is centred over the head and kept on the display; `tail_x`
## (relative to the balloon's left edge) points at the head as closely as the
## rounded corners allow.
static func place(head_x: float, head_top_y: float, size: Vector2, seg_start: float, seg_end: float) -> Dictionary:
	var lo := seg_start + SIDE_MARGIN_PT
	var hi := seg_end - SIDE_MARGIN_PT - size.x
	var x := head_x - size.x * 0.5
	x = lo if hi < lo else clampf(x, lo, hi)
	var y := head_top_y - GAP_PT - TAIL_PT - size.y
	var inset := CORNER_PT + TAIL_HALF_WIDTH_PT
	var tail_x := clampf(head_x - x, inset, maxf(inset, size.x - inset))
	return {"rect": Rect2(x, y, size.x, size.y), "tail_x": tail_x}
