extends RefCounted
## Pure helpers for the monster's eye (character-rig D5).


## Pupil offset towards `local_target` (a point in the eye's local space,
## relative to the eye centre), clamped so the pupil never leaves the white.
static func pupil_offset(local_target: Vector2, max_offset: float) -> Vector2:
	if max_offset <= 0.0:
		return Vector2.ZERO
	return local_target.limit_length(max_offset)
