extends "res://tests/base_test.gd"
## Who gets an avatar, where and in which colour (session-avatars D1, D2, D6).

const Cast := preload("res://scripts/core/avatar_cast.gd")


func _s(id: String, msec: int, state := &"idle", name := "") -> Dictionary:
	return {"id": id, "name": name if name else id, "state": state, "updated_msec": msec}


func _a(id: String, slot: int, hue := 0.0, leaving := false) -> Dictionary:
	return {"id": id, "slot": slot, "hue": hue, "leaving": leaving}


func _kinds(actions: Array) -> Array:
	return actions.map(func(x): return "%s:%s" % [x.kind, x.id])


func test_slot_order_from_the_edges() -> void:
	assert_eq(Cast.slot_order(1), [0] as Array[int])
	assert_eq(Cast.slot_order(2), [0, 1] as Array[int])
	assert_eq(Cast.slot_order(3), [0, 2, 1] as Array[int])
	assert_eq(Cast.slot_order(4), [0, 3, 1, 2] as Array[int])
	assert_eq(Cast.slot_order(5), [0, 4, 1, 3, 2] as Array[int])


func test_slot_geometry() -> void:
	assert_eq(Cast.slot_count(1512.0, 110.0), 5)
	assert_eq(Cast.slot_count(300.0, 110.0), 2, "narrow display")
	assert_eq(Cast.slot_count(50.0, 110.0), 1, "always at least one")
	assert_eq(Cast.slot_center(1000.0, 1500.0, 5, 2), 1750.0)
	assert_eq(Cast.stroll_range(1500.0, 5, 50.0), 150.0 - 50.0 - 8.0)


func test_one_session_enters_the_left_edge() -> void:
	var actions := Cast.plan([_s("a", 1000)], [], 5)
	assert_eq(actions.size(), 1)
	assert_eq(actions[0].kind, "enter")
	assert_eq(actions[0].slot, 0)
	assert_true(actions[0].hue in Cast.HUES)


func test_three_sessions_fill_from_the_edges() -> void:
	var actions := Cast.plan([_s("a", 3000), _s("b", 2000), _s("c", 1000)], [], 5)
	assert_eq(actions.map(func(x): return x.slot), [0, 4, 1])
	assert_eq(_kinds(actions), ["enter:a", "enter:b", "enter:c"], "most recent first")


## Spec "Sharing the strip": one, two ... five sessions arriving one after another.
func test_sessions_arriving_one_by_one_fill_edges_inward() -> void:
	var sessions := []
	var avatars := []
	var expected := [0, 4, 1, 3, 2]
	for i in 5:
		var id := "s%d" % i
		sessions.append(_s(id, 1000 * (i + 1)))
		var actions := Cast.plan(sessions, avatars, 5)
		assert_eq(_kinds(actions), ["enter:" + id], "buddy %d only enters" % (i + 1))
		assert_eq(actions[0].slot, expected[i], "buddy %d takes slot %d" % [i + 1, expected[i]])
		avatars.append(_a(id, actions[0].slot, actions[0].hue))
	var centres := avatars.map(func(a): return Cast.slot_center(0.0, 1512.0, 5, a.slot))
	assert_true(centres[0] < centres[2] and centres[2] < centres[4] and centres[4] < centres[3] and centres[3] < centres[1],
		"left edge, right edge, then inward")


func test_gap_stays_until_filled() -> void:
	var sessions := [_s("a", 1000), _s("b", 2000), _s("c", 3000)]
	var avatars := [_a("b", 4), _a("c", 1)] # a, at slot 0, walked off
	sessions.remove_at(0)
	assert_eq(Cast.plan(sessions, avatars, 5).size(), 0, "the others keep their spots")
	sessions.append(_s("d", 4000))
	var actions := Cast.plan(sessions, avatars, 5)
	assert_eq(_kinds(actions), ["enter:d"])
	assert_eq(actions[0].slot, 0, "the newcomer takes the leftmost spot")


func test_nothing_changes_when_settled() -> void:
	var actions := Cast.plan([_s("a", 3000), _s("b", 2000)], [_a("a", 2), _a("b", 1, 200.0)], 5)
	assert_eq(actions.size(), 0)


func test_sixth_session_evicts_the_quietest() -> void:
	var sessions := [_s("a", 1000), _s("b", 2000), _s("c", 3000), _s("d", 4000), _s("e", 5000), _s("f", 9000)]
	var avatars := [_a("a", 4), _a("b", 0), _a("c", 3), _a("d", 1), _a("e", 2)]
	assert_eq(_kinds(Cast.plan(sessions, avatars, 5)), ["leave:a"])
	avatars[0].leaving = true
	assert_eq(Cast.plan(sessions, avatars, 5).size(), 0, "the newcomer waits for the slot")
	avatars.remove_at(0) # walked off
	var actions := Cast.plan(sessions, avatars, 5)
	assert_eq(_kinds(actions), ["enter:f"])
	assert_eq(actions[0].slot, 4, "takes the freed slot")


func test_hysteresis() -> void:
	var sessions := [_s("a", 1000), _s("b", 2000), _s("c", 3000), _s("d", 4000), _s("e", 5000), _s("f", 2500)]
	var avatars := [_a("a", 4), _a("b", 0), _a("c", 3), _a("d", 1), _a("e", 2)]
	assert_eq(Cast.plan(sessions, avatars, 5).size(), 0, "1.5 s newer is not enough")
	sessions[5].updated_msec = 3000
	assert_eq(_kinds(Cast.plan(sessions, avatars, 5)), ["leave:a"], "2 s newer is")


func test_waiting_session_is_never_evicted() -> void:
	var sessions := [_s("a", 1000, &"waiting"), _s("b", 2000), _s("c", 3000), _s("d", 4000), _s("e", 5000), _s("f", 9000)]
	var avatars := [_a("a", 4), _a("b", 0), _a("c", 3), _a("d", 1), _a("e", 2)]
	assert_eq(_kinds(Cast.plan(sessions, avatars, 5)), ["leave:b"], "the quietest non-waiting one goes")


func test_waiting_session_gets_an_avatar_first() -> void:
	var sessions := [_s("a", 5000), _s("b", 6000), _s("c", 7000), _s("d", 8000), _s("e", 9000), _s("w", 1000, &"waiting")]
	var avatars := [_a("a", 4), _a("b", 0), _a("c", 3), _a("d", 1), _a("e", 2)]
	assert_eq(_kinds(Cast.plan(sessions, avatars, 5)), ["leave:a"], "an old waiting session still displaces")


func test_ended_session_waves_removed_does_not() -> void:
	var actions := Cast.plan([_s("a", 1000, &"ended")], [_a("a", 2), _a("b", 1)], 5)
	assert_eq(actions.size(), 2)
	assert_eq(actions[0], {"kind": "leave", "id": "a", "wave": true})
	assert_eq(actions[1], {"kind": "leave", "id": "b", "wave": false})


func test_leaving_avatar_is_left_alone() -> void:
	assert_eq(Cast.plan([], [_a("a", 2, 0.0, true)], 5).size(), 0)


func test_session_without_avatar_ending() -> void:
	var sessions := [_s("x", 500, &"ended"), _s("a", 1000)]
	assert_eq(Cast.plan(sessions, [_a("a", 2)], 5).size(), 0, "no avatar enters or leaves for it")


func test_narrow_display() -> void:
	var sessions := [_s("a", 3000), _s("b", 2000), _s("c", 1000)]
	var avatars := [_a("a", 2), _a("b", 1), _a("c", 3)]
	var actions := Cast.plan(sessions, avatars, 2)
	assert_eq(_kinds(actions), ["leave:a", "leave:c"], "slots 2 and 3 no longer exist")
	avatars = [_a("b", 1)]
	actions = Cast.plan(sessions, avatars, 2)
	assert_eq(_kinds(actions), ["enter:a"])
	assert_eq(actions[0].slot, 0)


func test_hues_unique_and_stable() -> void:
	var sessions := []
	for i in 5:
		sessions.append(_s("s%d" % i, 1000 + i, &"idle", "same-project"))
	var hues := Cast.plan(sessions, [], 5).map(func(x): return x.hue)
	var unique := {}
	for h in hues:
		unique[h] = true
	assert_eq(unique.size(), 5, "five different hues, even for one project name")
	assert_eq(Cast.pick_hue("claude-buddy", []), Cast.pick_hue("claude-buddy", []), "same name, same hue")
	var first := Cast.pick_hue("claude-buddy", [])
	assert_true(Cast.pick_hue("claude-buddy", [first]) != first, "taken hue is skipped")


# --- send-home: away sessions ---------------------------------------------

func _away(id: String, msec: int) -> Dictionary:
	var s := _s(id, msec)
	s["away"] = true
	return s


func test_away_session_frees_its_place() -> void:
	var sessions := [_away("a", 9000), _s("b", 2000), _s("c", 3000), _s("d", 4000), _s("e", 5000), _s("f", 1000)]
	var avatars := [_a("a", 2), _a("b", 0), _a("c", 3), _a("d", 1), _a("e", 4)]
	assert_eq(_kinds(Cast.plan(sessions, avatars, 5)), ["leave:a"], "the away session's avatar leaves")
	avatars.remove_at(0)
	var actions := Cast.plan(sessions, avatars, 5)
	assert_eq(_kinds(actions), ["enter:f"], "the sixth session takes the place")


func test_away_session_gets_no_avatar() -> void:
	assert_eq(Cast.plan([_away("a", 1000)], [], 5).size(), 0)


class FakeSession:
	var state: StringName = &"done"
	var last_ts := 100
	var pending: Array[String] = []


func test_comes_back_on_real_use() -> void:
	var s := FakeSession.new()
	var mark := Cast.away_mark(s)
	assert_false(Cast.comes_back(mark, s), "unchanged")
	s.state = &"thinking"
	s.last_ts = 200
	assert_true(Cast.comes_back(mark, s), "a new prompt")
	var w := FakeSession.new()
	w.state = &"working"
	var mark_w := Cast.away_mark(w)
	assert_false(Cast.comes_back(mark_w, w), "sent home while working: stays away")
	w.last_ts = 150
	assert_true(Cast.comes_back(mark_w, w), "a new tool start")


func test_comes_back_on_a_new_request() -> void:
	var s := FakeSession.new()
	s.pending = ["old"]
	var mark := Cast.away_mark(s)
	s.state = &"waiting"
	assert_false(Cast.comes_back(mark, s), "the request it already had")
	s.pending.append("new")
	assert_true(Cast.comes_back(mark, s), "a new question")


func test_stays_away_on_notifications_and_done() -> void:
	var s := FakeSession.new()
	s.state = &"idle"
	var mark := Cast.away_mark(s)
	assert_false(Cast.comes_back(mark, s), "a notification changes neither state nor last_ts")
	s.state = &"done"
	s.last_ts = 300
	assert_false(Cast.comes_back(mark, s), "a finished turn does not count as use")


func test_drop_slot_is_the_nearest() -> void:
	# Segment 1000..2000 with 5 slots of 200: centres at 1100, 1300, ...
	assert_eq(Cast.drop_slot(1290.0, 1000.0, 1000.0, 5), 1)
	assert_eq(Cast.drop_slot(1410.0, 1000.0, 1000.0, 5), 2)
	assert_eq(Cast.drop_slot(1000.0, 1000.0, 1000.0, 5), 0, "left end")
	assert_eq(Cast.drop_slot(2000.0, 1000.0, 1000.0, 5), 4, "right end")
	assert_eq(Cast.drop_slot(-50.0, 1000.0, 1000.0, 5), 0, "left of the segment")
	assert_eq(Cast.drop_slot(2600.0, 1000.0, 1000.0, 5), 4, "right of the segment")
	assert_eq(Cast.drop_slot(1500.0, 1000.0, 1000.0, 1), 0, "one slot")


func test_wobbo_is_always_green() -> void:
	# A session whose name picks green enters first; Wobbo still gets green.
	var green_name := ""
	for i in 100:
		if Cast.pick_hue("p%d" % i, []) == Cast.OWN_HUE:
			green_name = "p%d" % i
			break
	var actions := Cast.plan([_s("s1", 2000, &"idle", green_name), _s("wobbo:welcome", 1000, &"idle", "Wobbo")], [], 5)
	var hues := {}
	for a: Dictionary in actions:
		hues[a.id] = a.hue
	assert_eq(hues["s1"], Cast.OWN_HUE, "the session picked green")
	assert_eq(hues["wobbo:welcome"], Cast.OWN_HUE, "Wobbo is green too")


# --- Chosen colours (pick-wobbo-colour) --------------------------------------

func test_chosen_colour_wins_even_when_taken() -> void:
	var sessions := [_s("a", 2000, &"idle", "website"), _s("b", 1000, &"idle", "wobbo")]
	var avatars := [_a("a", 0, 25.0)]
	var actions := Cast.plan(sessions, avatars, 5, {"wobbo": 25.0})
	assert_eq(_kinds(actions), ["enter:b"])
	assert_eq(actions[0].hue, 25.0, "the chosen orange, though website wears it")


func test_automatic_avoids_a_chosen_colour() -> void:
	var name := ""
	for i in 200: # a folder name whose automatic colour is orange
		if Cast.pick_hue("p%d" % i, []) == 25.0:
			name = "p%d" % i
			break
	var sessions := [_s("a", 2000, &"idle", "wobbo"), _s("b", 1000, &"idle", name)]
	var actions := Cast.plan(sessions, [], 5, {"wobbo": 25.0})
	assert_eq(actions[0].hue, 25.0, "wobbo orange")
	assert_true(actions[1].hue != 25.0, "the other folder avoids orange")


func test_all_sessions_of_a_folder_wear_the_chosen_colour() -> void:
	var sessions := [_s("a", 2000, &"idle", "wobbo"), _s("b", 1000, &"idle", "wobbo")]
	var hues := Cast.plan(sessions, [], 5, {"wobbo": 330.0}).map(func(x): return x.hue)
	assert_eq(hues, [330.0, 330.0])


func test_own_buddy_stays_green_with_a_choice() -> void:
	var sessions := [_s("wobbo:welcome", 1000, &"idle", "Wobbo")]
	var actions := Cast.plan(sessions, [], 5, {"Wobbo": 355.0})
	assert_eq(actions[0].hue, Cast.OWN_HUE)


func test_recolour_all_of_the_folder() -> void:
	var sessions := [_s("a", 0, &"idle", "wobbo"), _s("b", 0, &"idle", "wobbo"), _s("c", 0, &"idle", "web")]
	var avatars := [_a("a", 0, 205.0), _a("b", 1, 265.0), _a("c", 2, 180.0)]
	var out := Cast.recolour(avatars, sessions, "wobbo", 25.0, {"wobbo": 25.0})
	assert_eq(out, [{"id": "a", "hue": 25.0}, {"id": "b", "hue": 25.0}] as Array[Dictionary])


func test_recolour_swaps_with_an_automatic_one() -> void:
	var sessions := [_s("a", 0, &"idle", "iris-mobile"), _s("c", 0, &"idle", "website")]
	var avatars := [_a("a", 0, 205.0), _a("c", 1, 355.0)]
	var out := Cast.recolour(avatars, sessions, "iris-mobile", 355.0, {"iris-mobile": 355.0})
	assert_eq(out, [{"id": "a", "hue": 355.0}, {"id": "c", "hue": 205.0}] as Array[Dictionary])


func test_recolour_does_not_swap_a_chosen_one() -> void:
	var sessions := [_s("a", 0, &"idle", "iris-mobile"), _s("c", 0, &"idle", "website")]
	var avatars := [_a("a", 0, 205.0), _a("c", 1, 355.0)]
	var chosen := {"iris-mobile": 355.0, "website": 355.0}
	var out := Cast.recolour(avatars, sessions, "iris-mobile", 355.0, chosen)
	assert_eq(out, [{"id": "a", "hue": 355.0}] as Array[Dictionary], "website keeps its own choice")


func test_recolour_back_to_automatic() -> void:
	var sessions := [_s("a", 0, &"idle", "iris-mobile"), _s("c", 0, &"idle", "website")]
	var avatars := [_a("a", 0, 355.0), _a("c", 1, 180.0)]
	var out := Cast.recolour(avatars, sessions, "iris-mobile", -1.0, {})
	var expected := Cast.pick_hue("iris-mobile", [180.0])
	if expected == 355.0:
		assert_eq(out.size(), 0, "automatic is red anyway")
	else:
		assert_eq(out, [{"id": "a", "hue": expected}] as Array[Dictionary])


func test_recolour_skips_leaving_and_own() -> void:
	var sessions := [_s("a", 0, &"idle", "wobbo"), _s("wobbo:welcome", 0, &"idle", "wobbo")]
	var avatars := [_a("a", 0, 205.0, true), _a("wobbo:welcome", 1, Cast.OWN_HUE)]
	assert_eq(Cast.recolour(avatars, sessions, "wobbo", 25.0, {"wobbo": 25.0}).size(), 0)
