extends "res://tests/base_test.gd"
## A left click goes to the session in every state but ended (always-go-to-session).

const ClickAction := preload("res://scripts/core/click_action.gd")


func test_every_live_state_goes_to_the_session() -> void:
	for state in [&"thinking", &"working", &"waiting", &"done", &"error", &"idle"]:
		assert_eq(ClickAction.for_left_click(state, 4242).action, "go", String(state))


func test_ended_does_nothing() -> void:
	var r := ClickAction.for_left_click(&"ended", 4242)
	assert_eq(r.action, "none")
	assert_true(r.reason.contains("ended"), r.reason)


func test_without_a_process_does_nothing() -> void:
	for state in [&"waiting", &"working"]:
		var r := ClickAction.for_left_click(state, 0)
		assert_eq(r.action, "none", String(state))
		assert_true(r.reason.contains("process"), r.reason)
