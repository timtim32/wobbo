extends RefCounted
## Interactive-region registry and hit-test logic (overlay-window D3). Pure logic, no
## window dependency. The overlay passes rects and points in walkway points
## (multi-display D5); the registry itself does not depend on the unit.
##
## Hit-testing is half-open, like Rect2.has_point(): the left/top edges belong
## to the region, the right/bottom edges do not. When regions overlap, the one
## registered last wins.

## Pass-through target that means "the whole strip receives the mouse".
const CAPTURE := &"__capture__"

var _regions: Dictionary = {} # StringName -> Rect2
var _captured_id: StringName = &""


func set_region(id: StringName, rect: Rect2) -> void:
	_regions[id] = rect.abs()


func remove_region(id: StringName) -> void:
	_regions.erase(id)


func clear() -> void:
	_regions.clear()
	_captured_id = &""


func has_region(id: StringName) -> bool:
	return _regions.has(id)


func get_region(id: StringName) -> Rect2:
	return _regions.get(id, Rect2())


func get_regions() -> Dictionary:
	return _regions.duplicate()


func is_empty() -> bool:
	return _regions.is_empty()


## Returns the id of the region under `point`, or &"" if none.
func region_at(point: Vector2) -> StringName:
	var hit: StringName = &""
	for id: StringName in _regions:
		if (_regions[id] as Rect2).has_point(point):
			hit = id
	return hit


## A mouse button went down at `point`. Starts drag capture when it is inside a
## region and returns that region's id (or &"").
func press(point: Vector2) -> StringName:
	var id := region_at(point)
	if id != &"":
		_captured_id = id
	return id


## All mouse buttons were released. Ends drag capture and returns the region
## that had captured the mouse (or &"").
func release() -> StringName:
	var id := _captured_id
	_captured_id = &""
	return id


func is_capturing() -> bool:
	return _captured_id != &""


## What the pass-through polygon should cover for a cursor at `point`:
## CAPTURE while a drag that started in a region is in progress, else the id of
## the region under the cursor, else &"" (everything passes through).
func passthrough_target(point: Vector2) -> StringName:
	if is_capturing():
		return CAPTURE
	return region_at(point)
