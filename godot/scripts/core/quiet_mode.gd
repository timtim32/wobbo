extends RefCounted
## When the app may drop to a low frame rate (session-avatars design D8). Pure.

const QUIET_FPS := 10 # session-avatars spike S1: 5 fps made the sleep breathing choppy


## avatars: [{asleep: bool, going: bool, moving: bool}] for the avatars on
## screen. A sleeping avatar that moves (for example travelling to another
## display) keeps the frame rate up, or it would walk at the quiet rate.
## `balloon_open`: a buddy shows a balloon (balloons-and-speech D10).
static func is_quiet(content_visible: bool, avatars: Array, debug_mode: bool,
		pointer_on_strip: bool, balloon_open: bool) -> bool:
	if debug_mode or pointer_on_strip:
		return false
	if not content_visible:
		return true
	if balloon_open:
		return false
	for a in avatars:
		if a.going or a.get("moving", false) or not a.asleep:
			return false
	return true
