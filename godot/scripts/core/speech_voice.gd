extends RefCounted
## The voice the buddies speak with (balloons-and-speech design D7). Pure.


## `voices`: DisplayServer.tts_get_voices() entries ({id, name, language}).
## The first voice for `language` (as "en" or "en-US"), else the first voice,
## else "" (no speech).
static func pick(voices: Array, language: String) -> String:
	var want := language.split("_")[0].split("-")[0].to_lower()
	for v in voices:
		var lang := String(v.get("language", "")).split("_")[0].split("-")[0].to_lower()
		if not want.is_empty() and lang == want:
			return String(v.get("id", ""))
	return String(voices[0].get("id", "")) if not voices.is_empty() else ""
