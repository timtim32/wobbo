extends RefCounted
## Trailer mode (tools/record-trailer.sh): `Godot --path godot -- --trailer=<dir>`.
## A one-off run that only plays the trailer show for a screen recording. To keep
## the user's own things out of the video it does not listen for agents (no real
## sessions, no bridge.json), shows no welcome, keeps its settings in memory only
## and paints an opaque backdrop over the recorded strip. <dir> is where it talks
## to the recording script (see trailer.gd).

const ARG := "--trailer="


## The handshake folder, or "" when this is not a trailer run.
static func dir(args := OS.get_cmdline_user_args()) -> String:
	for arg: String in args:
		if arg.begins_with(ARG):
			return arg.trim_prefix(ARG)
	return ""


static func active() -> bool:
	return not dir().is_empty()
