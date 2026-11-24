extends "res://tests/base_test.gd"
## What one buddy's balloon shows (balloons-and-speech design D3).

const BalloonQueue := preload("res://scripts/core/balloon_queue.gd")

var q: BalloonQueue


func before_each() -> void:
	q = BalloonQueue.new()


func test_empty() -> void:
	assert_eq(q.current(0), {})


func test_message_expires() -> void:
	q.set_message("Tests are green", &"message", 4.0, 1000)
	assert_eq(q.current(4999).get("text"), "Tests are green")
	assert_eq(q.current(5000), {}, "gone after 4 s")
	assert_eq(q.current(4000), {}, "and stays gone")


func test_newer_message_replaces_older() -> void:
	q.set_message("Building…", &"message", 4.0, 0)
	q.set_message("Build done", &"message", 4.0, 100)
	assert_eq(q.current(200).get("text"), "Build done")


func test_requests_first_oldest_first() -> void:
	q.set_message("hi", &"message", 10.0, 0)
	q.add_request("r1")
	q.add_request("r2")
	q.add_request("r1")
	assert_eq(q.current(10), {"type": &"request", "id": "r1", "index": 1, "count": 2})
	assert_true(q.remove_request("r1"))
	assert_eq(q.current(20).get("id"), "r2")
	assert_eq(q.current(20).get("count"), 1)
	q.remove_request("r2")
	assert_eq(q.current(30).get("text"), "hi", "the message is back once no request is left")


func test_message_while_request_does_not_hide_it() -> void:
	q.add_request("r1")
	q.set_message("by the way", &"message", 4.0, 0)
	assert_eq(q.current(10).get("id"), "r1")


func test_request_removed_from_the_middle() -> void:
	for id in ["a", "b", "c"]:
		q.add_request(id)
	assert_true(q.remove_request("b"))
	assert_false(q.remove_request("b"), "already gone")
	assert_eq(q.requests(), ["a", "c"] as Array[String])
	assert_eq(q.current(0).get("count"), 2)


func test_hold_pauses_the_countdown() -> void:
	q.set_message("read me", &"message", 4.0, 0)
	q.hold(1000)
	assert_eq(q.current(60000).get("text"), "read me", "stays while held")
	q.release(61000)
	assert_eq(q.current(63999).get("text"), "read me", "3 s left after release")
	assert_eq(q.current(64000), {})


func test_close_message() -> void:
	q.set_message("x", &"done", 4.0, 0)
	q.close_message()
	assert_eq(q.current(1), {})
	assert_false(q.is_held())


func test_clear() -> void:
	q.add_request("r1")
	q.set_message("x", &"message", 4.0, 0)
	q.clear()
	assert_eq(q.current(1), {})
	assert_false(q.has_requests())


# --- Questions asked in the agent's own window (design D11) -------------------

func test_asked_between_requests_and_messages() -> void:
	q.set_message("Done", &"done", 4.0, 0)
	q.set_asked("Commit?", ["Yes", "No"], "mcp__ccd_turn__wrap_up", "prompt")
	assert_eq(q.current(10), {"type": &"asked", "text": "Commit?", "choices": ["Yes", "No"]}, "a Done notice does not hide it")
	q.add_request("r1")
	assert_eq(q.current(10).get("type"), &"request", "a request comes first")
	q.remove_request("r1")
	assert_eq(q.current(10).get("type"), &"asked")


func test_asked_stays_until_closed() -> void:
	q.set_asked("Commit?", [], "mcp__ccd_turn__wrap_up", "prompt")
	assert_eq(q.current(999999).get("text"), "Commit?", "no time-out")
	q.tool_ended("mcp__ccd_turn__wrap_up")
	assert_true(q.has_asked(), "a next-step question waits for the prompt, not for its tool")
	q.close_asked()
	assert_eq(q.current(0), {})


func test_asked_closes_when_its_tool_is_answered() -> void:
	q.set_asked("Which DB?", ["Postgres"], "AskUserQuestion", "answer")
	q.tool_ended("Bash")
	assert_true(q.has_asked(), "another tool")
	q.tool_ended("AskUserQuestion")
	assert_false(q.has_asked())


func test_clear_drops_asked() -> void:
	q.set_asked("x", [], "t", "prompt")
	q.clear()
	assert_false(q.has_asked())
