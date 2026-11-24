extends "res://tests/base_test.gd"
## What the buddies show, speak and hand back (balloons-and-speech design D2, D8).

const Policy := preload("res://scripts/core/message_policy.gd")


func test_unknown_mode_reads_as_balloons() -> void:
	assert_eq(Policy.mode_of("loud"), "balloons")
	assert_eq(Policy.mode_of(null), "balloons")
	assert_eq(Policy.mode_of(3), "balloons")
	assert_eq(Policy.mode_of("both"), "both")


func test_output_flags_per_mode() -> void:
	assert_eq(Policy.output_flags("balloons"), {"balloon": true, "speech": false})
	assert_eq(Policy.output_flags("speech"), {"balloon": false, "speech": true})
	assert_eq(Policy.output_flags("both"), {"balloon": true, "speech": true})
	assert_eq(Policy.output_flags("off"), {"balloon": false, "speech": false})
	assert_eq(Policy.output_flags("?"), {"balloon": true, "speech": false}, "unknown is balloons")


func test_requests_are_handed_back_when_off_or_hidden() -> void:
	assert_true(Policy.accepts_requests("balloons", true))
	assert_true(Policy.accepts_requests("speech", true))
	assert_false(Policy.accepts_requests("off", true), "output off")
	assert_false(Policy.accepts_requests("both", false), "buddies hidden")


func test_reading_time_is_clamped() -> void:
	assert_eq(Policy.reading_time_s("Ok"), 4.0, "short text: 4 s")
	assert_eq(Policy.reading_time_s("x".repeat(500)), 12.0, "long text: 12 s")
	var mid := Policy.reading_time_s("x".repeat(100))
	assert_true(mid > 4.0 and mid < 12.0, "grows with length")


func test_message_plan_per_mode() -> void:
	var p := Policy.for_message("Tests are green", "api", "balloons")
	assert_eq([p.show, p.speak, p.text, p.kind], [true, false, "Tests are green", &"message"])
	p = Policy.for_message("Tests are green", "api", "speech")
	assert_eq([p.show, p.speak, p.spoken], [false, true, "api: Tests are green"])
	p = Policy.for_message("Tests are green", "api", "both")
	assert_eq([p.show, p.speak], [true, true])
	assert_eq(Policy.for_message("Tests are green", "api", "off"), {}, "nothing when off")


func test_turn_finished_after_twenty_seconds() -> void:
	assert_eq(Policy.for_turn_end("api", 19900, true, "balloons"), {}, "19.9 s is a quick reply")
	var p := Policy.for_turn_end("api", 20000, true, "both")
	assert_eq([p.text, p.spoken, p.duration_s, p.kind], ["Done", "api is done", 4.0, &"done"])
	assert_eq(Policy.for_turn_end("api", -1, true, "balloons"), {}, "unknown start")
	assert_eq(Policy.for_turn_end("api", 60000, false, "balloons"), {}, "Turn finished off")
	assert_eq(Policy.for_turn_end("api", 60000, true, "off"), {}, "output off")


func test_no_done_while_background_commands_run() -> void:
	assert_eq(Policy.for_turn_end("api", 180000, true, "balloons", 1), {}, "still waits for a background command")
	assert_eq(Policy.for_turn_end("api", 480000, true, "balloons", 0).text, "Done", "woken up and finished")


func test_error_notice() -> void:
	var p := Policy.for_turn_error("api", "API overloaded\nretry later", true, "balloons")
	assert_eq([p.text, p.duration_s, p.kind], ["Something went wrong: API overloaded", 8.0, &"error"])
	assert_eq(p.spoken, "api: something went wrong")
	assert_eq(Policy.for_turn_error("api", "", true, "balloons").text, "Something went wrong")
	assert_eq(Policy.for_turn_error("api", "boom", false, "balloons"), {}, "Errors off")


func test_first_line_is_cut() -> void:
	assert_eq(Policy.first_line("\n  first  \nsecond"), "first")
	var long := Policy.first_line("y".repeat(300))
	assert_eq(long.length(), 120)
	assert_true(long.ends_with("…"))


func test_requests_show_also_with_speech_only() -> void:
	var p := Policy.for_request("question", "Deploy now?", "api", "speech")
	assert_eq([p.show, p.speak, p.spoken], [true, true, "api asks: Deploy now?"])
	p = Policy.for_request("question", "Deploy now?", "api", "balloons")
	assert_eq([p.show, p.speak], [true, false])
	p = Policy.for_request("permission", "Bash: rm -rf build", "api", "both")
	assert_eq(p.spoken, "api asks permission to use Bash", "the command itself is not read aloud")
	assert_false(Policy.for_request("question", "Deploy now?", "api", "off").show)


func test_menu_items() -> void:
	for mode in ["balloons", "speech", "both", "off", "bogus"]:
		var checked := Policy.menu_items(mode, true).filter(func(i): return i.checked)
		assert_eq(checked.size(), 1, "exactly one checked for %s" % mode)
	var items := Policy.menu_items("both", true)
	assert_eq(items.map(func(i): return i.label), ["Balloons", "Speech", "Balloons and Speech", "Off"])
	assert_eq(items.filter(func(i): return i.disabled).size(), 0)
	var no_voice := Policy.menu_items("balloons", false)
	assert_eq(no_voice.filter(func(i): return i.disabled).map(func(i): return i.value), ["speech", "both"])


func test_asked_follows_the_output() -> void:
	var p := Policy.for_asked("Commit?", "api", "balloons")
	assert_eq([p.show, p.speak], [true, false])
	p = Policy.for_asked("Commit?", "api", "speech")
	assert_eq([p.show, p.speak, p.spoken], [false, true, "api asks: Commit?"], "read only: no balloon with speech alone")
	assert_eq(Policy.for_asked("Commit?", "api", "off"), {})
