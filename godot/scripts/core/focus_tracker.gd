extends RefCounted
## Per-owner reference counting for explicit keyboard-focus requests (overlay-window D5).
## Owners are identified by an int key (normally Object.get_instance_id()).

var _counts: Dictionary = {} # int -> int


## Adds one request for `owner_key`. Returns true when this is the first
## outstanding request overall, i.e. the overlay must now take focus.
func request(owner_key: int) -> bool:
	var was_idle := _counts.is_empty()
	_counts[owner_key] = int(_counts.get(owner_key, 0)) + 1
	return was_idle


## Removes one request for `owner_key`. Returns true when that was the last
## outstanding request overall, i.e. focus must be handed back. Releasing an
## owner without requests is a no-op and returns false.
func release(owner_key: int) -> bool:
	if not _counts.has(owner_key):
		return false
	var left := int(_counts[owner_key]) - 1
	if left > 0:
		_counts[owner_key] = left
		return false
	_counts.erase(owner_key)
	return _counts.is_empty()


## Drops every request of `owner_key` (for example when the owner is freed).
## Returns true when focus must be handed back.
func release_all(owner_key: int) -> bool:
	if not _counts.has(owner_key):
		return false
	_counts.erase(owner_key)
	return _counts.is_empty()


func has_requests() -> bool:
	return not _counts.is_empty()


func count(owner_key: int) -> int:
	return int(_counts.get(owner_key, 0))
