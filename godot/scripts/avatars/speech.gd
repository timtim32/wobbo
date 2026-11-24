extends Node
## Speaks the buddies' messages with a macOS system voice (balloons-and-speech
## design D7), through DisplayServer's text-to-speech. Utterances queue behind
## what is playing.

const SpeechVoice := preload("res://scripts/core/speech_voice.gd")
const VOLUME := 50
const KEEP_SPOKEN := 20

## Off for checks from game_eval: texts are still recorded in `spoken`, not played.
var muted := false
## The latest texts asked to be spoken, oldest first (for checks).
var spoken: Array[String] = []

var _voice := ""
var _voice_checked := false
var _next_id := 1


## Whether macOS offers a voice. Decided once, on first use.
func available() -> bool:
	if not _voice_checked:
		_voice_checked = true
		if DisplayServer.get_name() != "headless":
			_voice = SpeechVoice.pick(DisplayServer.tts_get_voices(), OS.get_locale_language())
		if _voice.is_empty():
			print("Speech: no system voice; speech is unavailable")
	return not _voice.is_empty()


func speak(text: String) -> void:
	spoken.append(text)
	if spoken.size() > KEEP_SPOKEN:
		spoken.remove_at(0)
	if muted or not available():
		return
	DisplayServer.tts_speak(text, _voice, VOLUME, 1.0, 1.0, _next_id, false)
	_next_id += 1


## Stops what is playing and drops the queue.
func stop() -> void:
	if available():
		DisplayServer.tts_stop()
