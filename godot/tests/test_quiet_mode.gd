extends "res://tests/base_test.gd"
## When the frame rate may drop (session-avatars D8).

const Quiet := preload("res://scripts/core/quiet_mode.gd")

const ASLEEP := {"asleep": true, "going": false}
const AWAKE := {"asleep": false, "going": false}


func test_no_avatars_is_quiet() -> void:
	assert_true(Quiet.is_quiet(true, [], false, false, false))


func test_all_asleep_is_quiet() -> void:
	assert_true(Quiet.is_quiet(true, [ASLEEP, ASLEEP], false, false, false))
	assert_false(Quiet.is_quiet(true, [ASLEEP, AWAKE], false, false, false), "one awake")
	assert_false(Quiet.is_quiet(true, [{"asleep": false, "going": true}], false, false, false), "one walking off")
	assert_false(Quiet.is_quiet(true, [ASLEEP, {"asleep": true, "going": false, "moving": true}], false, false, false),
		"a sleeping one travelling to another display")


func test_hidden_is_quiet() -> void:
	assert_true(Quiet.is_quiet(false, [AWAKE], false, false, false))


func test_never_quiet_while_interacting() -> void:
	assert_false(Quiet.is_quiet(true, [], true, false, false), "debug mode")
	assert_false(Quiet.is_quiet(true, [ASLEEP], false, true, false), "pointer over a strip")


func test_never_quiet_while_a_balloon_is_open() -> void:
	assert_false(Quiet.is_quiet(true, [ASLEEP], false, false, true), "balloon open (balloons-and-speech)")
	assert_true(Quiet.is_quiet(false, [ASLEEP], false, false, true), "hidden buddies show no balloons")
