extends "res://tests/base_test.gd"
## The demo timeline (session-avatars D11).

const Demo := preload("res://scripts/avatars/demo_player.gd")


func test_steps_in_time_order() -> void:
	for steps: Array in [Demo.STEPS, Demo.TRAILER_STEPS]:
		var last := -1.0
		for step in steps:
			assert_true(step[0] >= last, "step at %.1f s is out of order" % step[0])
			last = step[0]


func test_every_pretend_session_starts_and_ends() -> void:
	for steps: Array in [Demo.STEPS, Demo.TRAILER_STEPS]:
		var started := {}
		var ended := {}
		for step in steps:
			if step[2] == "dock":
				assert_eq(step[1], "", "a cue belongs to no session")
				continue
			if step[2] == "start":
				started[step[1]] = true
			elif step[2] == "end":
				ended[step[1]] = true
			else:
				assert_true(started.has(step[1]), "%s acts before it started" % step[1])
		assert_eq(ended.keys().size(), started.keys().size(), "every session ends")
	var demo_sessions := {}
	for step in Demo.STEPS:
		demo_sessions[step[1]] = true
	assert_true(demo_sessions.size() >= 6, "enough sessions for a swap")


func test_known_actions_and_ids() -> void:
	for steps: Array in [Demo.STEPS, Demo.TRAILER_STEPS]:
		for step in steps:
			assert_true(step[2] in ["ask", "answered", "say", "dock"] or Demo.EVENT_KINDS.has(step[2]),
				"unknown action %s" % step[2])
	assert_eq(Demo.info("web").id, "demo:web")


## The trailer fits on screen at once (session-avatars D2: at most 5) and its
## "Done" notice shows, which needs a turn of 20 s (balloons-and-speech D2).
func test_trailer_shows_every_notice() -> void:
	var sessions := {}
	var prompted := {}
	var done_shown := false
	for step in Demo.TRAILER_STEPS:
		if step[2] == "dock":
			continue
		sessions[step[1]] = true
		if step[2] == "prompt":
			prompted[step[1]] = step[0]
		elif step[2] == "done" and prompted.has(step[1]) and step[0] - prompted[step[1]] >= 20.0:
			done_shown = true
	assert_true(sessions.size() <= 5, "every trailer buddy fits on screen")
	assert_true(done_shown, "one turn lasts long enough for Done")
