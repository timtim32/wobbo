extends "res://tests/base_test.gd"

const SessionRegistry := preload("res://scripts/core/session_registry.gd")

var reg: SessionRegistry
const CC := {"id": "s1", "agent": "claude-code", "project_dir": "/Users/me/Projects/api"}


func before_each() -> void:
	reg = SessionRegistry.new()


func test_session_appears_with_name() -> void:
	assert_true(reg.apply_event(CC, "session_start", {}, 1, 100, 4100))
	var s = reg.get_session("s1")
	assert_eq(s.name, "api", "display name from the project directory")
	assert_eq(s.agent, "claude-code")
	assert_eq(s.state, &"idle")
	assert_eq(s.ppid, 4100)


func test_state_follows_activity() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100)
	assert_eq(reg.get_session("s1").state, &"thinking")
	reg.apply_event(CC, "tool_start", {"tool": "Bash"}, 2, 110)
	assert_eq(reg.get_session("s1").state, &"working")
	assert_eq(reg.get_session("s1").tool, "Bash")
	reg.apply_event(CC, "tool_end", {"tool": "Bash"}, 3, 120)
	assert_eq(reg.get_session("s1").state, &"thinking")
	reg.apply_event(CC, "turn_end", {}, 4, 130)
	assert_eq(reg.get_session("s1").state, &"done")
	reg.apply_event(CC, "turn_error", {"error": "overloaded"}, 5, 140)
	assert_eq(reg.get_session("s1").state, &"error")
	assert_eq(reg.get_session("s1").last_problem, "overloaded")


func test_tool_error_keeps_thinking_and_records_problem() -> void:
	reg.apply_event(CC, "tool_start", {"tool": "Bash"}, 1, 100)
	reg.apply_event(CC, "tool_error", {"tool": "Bash", "error": "exit 1"}, 2, 110)
	assert_eq(reg.get_session("s1").state, &"thinking")
	assert_eq(reg.get_session("s1").last_problem, "exit 1")


func test_notification_does_not_change_state() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100)
	assert_false(reg.apply_event(CC, "notification", {"message": "hi"}, 2, 110))
	assert_eq(reg.get_session("s1").state, &"thinking")


func test_out_of_order_events_are_ignored() -> void:
	reg.apply_event(CC, "turn_end", {}, 50, 100)
	assert_false(reg.apply_event(CC, "tool_start", {"tool": "Read"}, 40, 110), "older event ignored")
	assert_eq(reg.get_session("s1").state, &"done")
	assert_true(reg.apply_event(CC, "session_end", {}, 10, 120), "session_end always applies")
	assert_eq(reg.get_session("s1").state, &"ended")


func test_request_waits_and_restores_state() -> void:
	reg.apply_event(CC, "tool_start", {"tool": "Bash"}, 1, 100)
	assert_true(reg.add_request(SessionRegistry.Request.new("r1", "s1", "question", "", [], false, 7), 110))
	assert_eq(reg.get_session("s1").state, &"waiting")
	reg.apply_event(CC, "tool_end", {}, 2, 120)
	assert_eq(reg.get_session("s1").state, &"waiting", "stays waiting while a request is open")
	var removed := reg.remove_request("r1")
	assert_eq(removed.id, "r1")
	assert_eq(reg.get_session("s1").state, &"thinking", "returns to the latest state")
	assert_eq(reg.remove_request("r1"), null, "removing twice is a no-op")


func test_requests_of_a_closed_connection_are_removed() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100)
	reg.add_request(SessionRegistry.Request.new("r1", "s1", "question", "", [], false, 7), 110)
	reg.add_request(SessionRegistry.Request.new("r2", "s1", "question", "", [], false, 8), 110)
	var removed := reg.remove_requests_of(7)
	assert_eq(removed.size(), 1)
	assert_eq(reg.requests.keys(), ["r2"])
	assert_eq(reg.get_session("s1").state, &"waiting", "r2 still open")


func test_ended_session_is_removed_after_linger() -> void:
	reg.apply_event(CC, "session_end", {"reason": "prompt_input_exit"}, 1, 1000)
	assert_eq(reg.tick(1000 + 4000), [] as Array[String], "still lingering")
	assert_eq(reg.tick(1000 + 5000), ["s1"] as Array[String])
	assert_false(reg.has_session("s1"))


func test_requests_of_a_removed_session_are_reported() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100)
	reg.add_request(SessionRegistry.Request.new("r1", "s1", "question", "", [], false, 7), 110)
	reg.apply_event(CC, "session_end", {"reason": "other"}, 2, 1000)
	var dropped: Array[SessionRegistry.Request] = []
	assert_eq(reg.tick(1000 + 5000, dropped), ["s1"] as Array[String])
	assert_eq(dropped.size(), 1, "one request dropped")
	assert_eq(dropped[0].id, "r1")
	assert_true(reg.requests.is_empty())


func test_silent_session_is_removed_after_30_minutes() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 0)
	assert_eq(reg.tick(29 * 60 * 1000), [] as Array[String])
	assert_eq(reg.tick(30 * 60 * 1000), ["s1"] as Array[String])


func test_connected_session_is_not_removed_when_silent() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 0)
	reg.get_session("s1").connections = 1
	assert_eq(reg.tick(60 * 60 * 1000), [] as Array[String])


func test_mcp_links_to_hook_session_by_ppid() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100, 4100)
	reg.apply_event({"id": "s2", "agent": "claude-code", "project_dir": "/Users/me/Projects/api"}, "prompt", {}, 1, 200, 5100)
	var s = reg.resolve_mcp_session({"agent": "claude-code", "pid": 9, "ppid": 4100, "project_dir": "/Users/me/Projects/api"}, 300)
	assert_eq(s.id, "s1", "same parent process wins over a more recent session in the same project")


func test_mcp_falls_back_to_project_dir() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100, 4100)
	var s = reg.resolve_mcp_session({"agent": "claude-code", "pid": 9, "ppid": 1, "project_dir": "/Users/me/Projects/api"}, 300)
	assert_eq(s.id, "s1")


func test_mcp_only_client_gets_its_own_session() -> void:
	var s = reg.resolve_mcp_session({"agent": "claude-desktop", "pid": 77, "ppid": 1, "project_dir": "", "client_name": "claude-ai"}, 300)
	assert_eq(s.id, "mcp:77")
	assert_eq(s.name, "Claude Desktop")
	var again = reg.resolve_mcp_session({"agent": "claude-desktop", "pid": 77, "ppid": 1, "project_dir": ""}, 400)
	assert_eq(again.id, "mcp:77", "same connection, same session")


func test_mcp_does_not_link_to_other_agent_or_ended_session() -> void:
	reg.apply_event(CC, "session_end", {}, 1, 100, 4100)
	var s = reg.resolve_mcp_session({"agent": "claude-code", "pid": 9, "ppid": 4100, "project_dir": "/x"}, 300)
	assert_eq(s.id, "mcp:9", "ended session is not reused")
	var t = reg.resolve_mcp_session({"agent": "codex", "pid": 10, "ppid": 4100, "project_dir": "/Users/me/Projects/api"}, 300)
	assert_eq(t.id, "mcp:10", "other agent is not linked")


func test_most_recent_skips_ended() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100)
	reg.apply_event({"id": "s2", "agent": "claude-code", "project_dir": "/p/web"}, "session_end", {}, 1, 200)
	assert_eq(reg.most_recent().id, "s1")


func test_desktop_code_tab_server_links_by_project_name() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100, 47927)
	var other := {"id": "s9", "agent": "claude-code", "project_dir": "/Users/me/Projects/web"}
	reg.apply_event(other, "prompt", {}, 1, 200, 50000)
	var s = reg.resolve_mcp_session({"agent": "claude-desktop", "pid": 47924, "ppid": 47923,
		"project_dir": "", "client_name": "local-agent-mode-api"}, 300)
	assert_eq(s.id, "s1", "Code-tab instance of the Desktop server joins the Code session of that project")


func test_desktop_code_tab_server_without_match_gets_own_session() -> void:
	var s = reg.resolve_mcp_session({"agent": "claude-desktop", "pid": 47924, "ppid": 47923,
		"project_dir": "", "client_name": "local-agent-mode-unknown"}, 300)
	assert_eq(s.id, "mcp:47924")
	assert_eq(s.name, "Claude Desktop", "a readable name, not the client name")


func test_desktop_code_tab_server_with_another_project_name_joins_the_active_app_session() -> void:
	# Claude Desktop names the project "wobbo" while its folder is claude-buddy.
	var app_url := "claude://claude.ai/code/x"
	reg.apply_event({"id": "s1", "agent": "claude-code", "project_dir": "/p/claude-buddy", "focus_url": app_url},
		"prompt", {}, 1, 100, 7424)
	reg.apply_event({"id": "s2", "agent": "claude-code", "project_dir": "/p/claude-buddy", "focus_url": app_url},
		"prompt", {}, 1, 200, 7843)
	reg.apply_event({"id": "t1", "agent": "claude-code", "project_dir": "/p/terminal"}, "prompt", {}, 1, 300, 9000)
	var client := {"agent": "claude-desktop", "pid": 7410, "ppid": 7409, "project_dir": "",
		"client_name": "local-agent-mode-wobbo"}
	assert_eq(reg.resolve_mcp_session(client, 400).id, "s2", "the app session active last, not the terminal one")
	reg.apply_event({"id": "s1", "agent": "claude-code", "project_dir": "/p/claude-buddy", "focus_url": app_url},
		"tool_start", {"tool": "mcp__wobbo__say"}, 2, 500, 7424)
	assert_eq(reg.resolve_mcp_session(client, 510).id, "s1", "follows the session whose hook fired for the call")


# --- work-and-wait: the agent waits for the user ----------------------------

func test_input_wait_until_the_tool_finished() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 100)
	reg.apply_event(CC, "input_wait", {"reason": "tool", "tool": "AskUserQuestion"}, 2, 110)
	assert_eq(reg.get_session("s1").state, &"waiting")
	assert_eq(reg.get_session("s1").tool, "AskUserQuestion")
	reg.apply_event(CC, "tool_end", {"tool": "AskUserQuestion"}, 3, 120)
	assert_eq(reg.get_session("s1").state, &"thinking", "answered: Claude goes on")


func test_input_wait_out_of_order_is_ignored() -> void:
	reg.apply_event(CC, "tool_end", {}, 5, 100)
	assert_false(reg.apply_event(CC, "input_wait", {"reason": "permission_prompt"}, 4, 110))
	assert_eq(reg.get_session("s1").state, &"thinking")


func test_input_wait_with_a_pending_request() -> void:
	reg.apply_event(CC, "tool_start", {"tool": "Bash"}, 1, 100)
	reg.add_request(SessionRegistry.Request.new("r1", "s1", "permission", "", [], false, 1), 110)
	reg.apply_event(CC, "input_wait", {"reason": "permission_prompt"}, 2, 120)
	assert_eq(reg.get_session("s1").state, &"waiting")
	reg.remove_request("r1")
	assert_eq(reg.get_session("s1").state, &"waiting", "the app's window passed, Claude Code still asks in the terminal")
	reg.apply_event(CC, "tool_end", {}, 3, 130)
	assert_eq(reg.get_session("s1").state, &"thinking")


# --- go-to-session: focus links ---------------------------------------------

func test_focus_link_is_kept_and_replaced() -> void:
	var info := CC.duplicate()
	info["focus_url"] = "claude://code/continue?session=local_a"
	reg.apply_event(info, "prompt", {}, 1, 100)
	assert_eq(reg.get_session("s1").focus_url, "claude://code/continue?session=local_a")
	info["focus_url"] = "claude://code/continue?session=local_b"
	reg.apply_event(info, "tool_start", {"tool": "Bash"}, 2, 110)
	assert_eq(reg.get_session("s1").focus_url, "claude://code/continue?session=local_b", "a later link replaces it")
	reg.apply_event(CC, "tool_end", {}, 3, 120)
	assert_eq(reg.get_session("s1").focus_url, "claude://code/continue?session=local_b", "kept without a new link")


func test_unknown_link_schemes_are_ignored() -> void:
	for url in ["file:///etc/passwd", "https://example.com", "javascript:alert(1)", "nonsense"]:
		var info := CC.duplicate()
		info["id"] = "s-" + str(url.hash())
		info["focus_url"] = url
		reg.apply_event(info, "prompt", {}, 1, 100)
		assert_eq(reg.get_session(info.id).focus_url, "", url)


# --- balloons-and-speech D4 ---------------------------------------------------

func test_request_keeps_timeout_and_arrival() -> void:
	reg.apply_event(CC, "session_start", {}, 1, 100)
	reg.add_request(SessionRegistry.Request.new("r1", "s1", "permission", "", [], false, 7, 20), 500)
	assert_eq(reg.requests["r1"].timeout_s, 20)
	assert_eq(reg.requests["r1"].added_msec, 500)
	reg.add_request(SessionRegistry.Request.new("r2", "s1", "question", "", [], false, 7), 600)
	assert_eq(reg.requests["r2"].timeout_s, 0, "unknown time-out")
	assert_eq(reg.requests["r2"].added_msec, 600)


func test_prompt_marks_the_turn_start() -> void:
	reg.apply_event(CC, "prompt", {}, 1, 1000)
	reg.apply_event(CC, "turn_end", {}, 2, 31000)
	assert_eq(reg.get_session("s1").turn_started_msec, 1000, "readable at turn_end")
	reg.apply_event(CC, "prompt", {}, 3, 40000)
	assert_eq(reg.get_session("s1").turn_started_msec, 40000, "a new prompt resets it")
