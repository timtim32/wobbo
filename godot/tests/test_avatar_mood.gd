extends "res://tests/base_test.gd"
## What an avatar does per session state (session-avatars D3).

const Mood := preload("res://scripts/core/avatar_mood.gd")


func _home(state := &"idle") -> Mood:
	var m := Mood.new(state)
	m.arrive()
	return m


## The clip a working avatar shows: a way of working or one of its transitions.
func _is_work(clip: StringName) -> bool:
	return String(clip).trim_suffix("_in").trim_suffix("_out") in Mood.WORK_CLIPS


func test_work_states_stand_with_their_clip() -> void:
	for state in [&"thinking", &"waiting"]:
		var m := _home(state)
		assert_eq(m.update(state, 0, 1000), {"clip": state, "motion": &"stand"}, String(state))
	var w := _home(&"working")
	var out := w.update(&"working", 0, 1000)
	assert_true(_is_work(out.clip) and out.motion == &"stand", "working: %s" % out.clip)


func test_idle_strolls_with_pauses() -> void:
	var m := _home()
	assert_eq(m.update(&"idle", 0, 0), {"clip": &"walk", "motion": &"stroll"})
	var paused := false
	for t in range(0, 40000, 500):
		if m.update(&"idle", t, t).motion == &"stand":
			paused = true
	assert_true(paused, "pauses now and then")


func test_done_plays_happy_then_strolls() -> void:
	var m := _home(&"working")
	assert_eq(m.update(&"done", 0, 0), {"clip": &"happy", "motion": &"stand"})
	assert_eq(m.update(&"done", 0, 500).clip, &"happy", "until the clip finishes")
	m.one_shot_finished(&"happy")
	assert_eq(m.update(&"done", 0, 1000).motion, &"stroll")


func test_error_flinches_then_strolls() -> void:
	var m := _home(&"working")
	assert_eq(m.update(&"error", 0, 0).clip, &"error")
	m.one_shot_finished(&"error")
	assert_eq(m.update(&"error", 0, 100).motion, &"stroll")


func test_no_reaction_for_the_state_at_creation() -> void:
	var m := _home(&"done")
	assert_eq(m.update(&"done", 0, 0).motion, &"stroll")


func test_sleeps_after_two_minutes_when_resting() -> void:
	for state in [&"idle", &"done", &"error"]:
		var m := _home(state)
		assert_false(m.update(state, 0, 119000).clip == &"sleep", "%s: not yet" % state)
		assert_eq(m.update(state, 0, 120000), {"clip": &"sleep", "motion": &"stand"}, String(state))
		assert_true(m.asleep)


func test_never_sleeps_while_busy() -> void:
	for state in [&"thinking", &"working", &"waiting"]:
		var m := _home(state)
		var clip: StringName = m.update(state, 0, 300000).clip
		assert_true(clip == state or (state == &"working" and _is_work(clip)), "%s after 5 minutes: %s" % [state, clip])


func test_wakes_on_activity() -> void:
	var m := _home(&"done")
	m.update(&"done", 0, 200000)
	assert_true(m.asleep)
	assert_eq(m.update(&"thinking", 200500, 200500).clip, &"thinking")
	assert_false(m.asleep)


func test_states_while_walking_apply_on_arrival() -> void:
	var m := Mood.new(&"idle")
	assert_eq(m.update(&"thinking", 0, 0), {"clip": &"walk", "motion": &"walk_in"})
	assert_eq(m.update(&"done", 0, 100).motion, &"walk_in", "keeps walking in")
	m.arrive()
	assert_eq(m.update(&"done", 0, 200).clip, &"happy", "the reaction is played on arrival")
	m.travel()
	assert_eq(m.update(&"working", 0, 300), {"clip": &"walk", "motion": &"travel"})
	m.arrive()
	assert_true(_is_work(m.update(&"working", 0, 400).clip), "the stale reaction is dropped")


func test_end_waves_then_walks_off() -> void:
	var m := _home(&"done")
	m.leave(true)
	assert_eq(m.update(&"ended", 0, 0), {"clip": &"wave", "motion": &"stand"})
	assert_eq(m.update(&"ended", 0, 20).clip, &"wave", "still waving")
	m.one_shot_finished(&"wave")
	assert_eq(m.update(&"ended", 0, 30), {"clip": &"walk", "motion": &"walk_off"})


func test_evicted_walks_off_without_wave() -> void:
	var m := _home(&"idle")
	m.leave(false)
	assert_eq(m.update(&"idle", 0, 0).motion, &"walk_off")
	m.arrive()
	assert_eq(m.phase, &"leaving", "leaving is final")


# --- send-home: going home after 15 minutes asleep ----------------------------

const MIN := 60 * 1000


func test_wants_home_after_fifteen_minutes_asleep() -> void:
	var m := _home(&"done")
	m.update(&"done", 0, 2 * MIN) # falls asleep
	assert_true(m.asleep)
	m.update(&"done", 0, 16 * MIN)
	assert_false(m.wants_home(16 * MIN), "14 minutes asleep")
	m.update(&"done", 0, 17 * MIN)
	assert_true(m.wants_home(17 * MIN), "15 minutes asleep")


func test_never_home_while_busy() -> void:
	for state in [&"thinking", &"working", &"waiting"]:
		var m := _home(state)
		m.update(state, 0, 60 * MIN)
		assert_false(m.wants_home(60 * MIN), String(state))


# --- work-and-wait: ways of working with props ---------------------------------

## Plays a working avatar for `ms`, finishing one-shots as the Monster would.
## Returns the clips it showed, in order, without repeats.
func _run_working(m: Mood, from_ms: int, ms: int) -> Array[StringName]:
	var shown: Array[StringName] = []
	var t := from_ms
	while t < from_ms + ms:
		var clip: StringName = m.update(&"working", t, t).clip
		if shown.is_empty() or shown[-1] != clip:
			shown.append(clip)
		if String(clip).ends_with("_in") or String(clip).ends_with("_out"):
			m.one_shot_finished(clip) # a transition lasts well under the 100 ms step here
		t += 100
	return shown


func test_work_starts_with_taking_the_prop() -> void:
	for seed_value in 20:
		var m := Mood.new(&"thinking", seed_value)
		m.arrive()
		var first: StringName = m.update(&"working", 0, 0).clip
		if first == &"working":
			continue # plain working has no prop
		assert_true(String(first).ends_with("_in"), "starts by taking the prop: %s" % first)
		m.one_shot_finished(first)
		assert_eq(m.update(&"working", 0, 100).clip, StringName(String(first).trim_suffix("_in")), "then works")


func test_work_switches_every_8_to_15_seconds_via_out_and_in() -> void:
	var m := Mood.new(&"thinking", 7)
	m.arrive()
	var shown := _run_working(m, 0, 60000)
	var loops: Array[StringName] = shown.filter(func(c: StringName) -> bool:
		return not (String(c).ends_with("_in") or String(c).ends_with("_out")))
	assert_true(loops.size() >= 4, "several ways of working in a minute: %s" % [loops])
	for i in range(1, loops.size()):
		assert_true(loops[i] != loops[i - 1], "never twice in a row: %s" % [loops])
	for i in shown.size():
		var c := String(shown[i])
		if c.ends_with("_out") and i + 1 < shown.size() and String(shown[i + 1]) != "working":
			assert_true(String(shown[i + 1]).ends_with("_in"), "after putting away, the next is taken: %s" % [shown])


func test_work_switch_timing() -> void:
	var m := Mood.new(&"thinking", 3)
	m.arrive()
	var t := 0
	var first: StringName = m.update(&"working", 0, 0).clip
	if String(first).ends_with("_in"):
		m.one_shot_finished(first)
	var loop_clip: StringName = m.work_clip()
	while m.update(&"working", t, t).clip == loop_clip:
		t += 100
	assert_true(t >= 7900 and t <= 15100, "switches after 8-15 s, got %d ms" % t)


func test_stop_working_puts_the_prop_away_first() -> void:
	for seed_value in 20:
		var m := Mood.new(&"thinking", seed_value)
		m.arrive()
		var first: StringName = m.update(&"working", 0, 0).clip
		if first == &"working":
			continue
		m.one_shot_finished(first)
		m.update(&"working", 0, 100)
		var out: StringName = m.update(&"done", 0, 200).clip
		assert_eq(out, StringName(String(first).trim_suffix("_in") + "_out"), "puts the prop away")
		m.one_shot_finished(out)
		assert_eq(m.update(&"done", 0, 300).clip, &"happy", "then reacts to done")
		return
	fail("no seed picked a prop")


func test_walking_drops_the_prop() -> void:
	var m := Mood.new(&"working", 1)
	m.arrive()
	m.update(&"working", 0, 0)
	m.travel()
	assert_eq(m.update(&"working", 0, 100).clip, &"walk")
	assert_eq(m.work_clip(), &"", "the prop is gone while walking")
