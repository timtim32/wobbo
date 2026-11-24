extends "res://tests/base_test.gd"
## The voice the buddies speak with (balloons-and-speech design D7).

const SpeechVoice := preload("res://scripts/core/speech_voice.gd")

const VOICES := [
	{"id": "nl.xander", "name": "Xander", "language": "nl-NL"},
	{"id": "en.samantha", "name": "Samantha", "language": "en-US"},
	{"id": "en.daniel", "name": "Daniel", "language": "en-GB"},
]


func test_first_voice_for_the_language() -> void:
	assert_eq(SpeechVoice.pick(VOICES, "en"), "en.samantha")
	assert_eq(SpeechVoice.pick(VOICES, "nl_NL"), "nl.xander")


func test_falls_back_to_the_first_voice() -> void:
	assert_eq(SpeechVoice.pick(VOICES, "ja"), "nl.xander")
	assert_eq(SpeechVoice.pick(VOICES, ""), "nl.xander")


func test_no_voices() -> void:
	assert_eq(SpeechVoice.pick([], "en"), "")
