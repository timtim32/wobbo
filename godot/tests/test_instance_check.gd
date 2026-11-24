extends "res://tests/base_test.gd"

const InstanceCheck := preload("res://scripts/core/instance_check.gd")


func test_parse_info() -> void:
	assert_eq(InstanceCheck.parse_info(""), {}, "missing file")
	assert_eq(InstanceCheck.parse_info("nonsense"), {}, "not JSON")
	assert_eq(InstanceCheck.parse_info("{\"port\": 1234}"), {}, "no pid")
	assert_eq(InstanceCheck.parse_info("{\"port\": 1234, \"pid\": 42, \"token\": \"t\"}"), {"pid": 42, "port": 1234})


func test_no_file() -> void:
	assert_false(InstanceCheck.decide({}, 10, false, false).duplicate)


func test_own_pid() -> void:
	assert_false(InstanceCheck.decide({"pid": 10, "port": 5}, 10, true, true).duplicate)


func test_dead_pid() -> void:
	assert_false(InstanceCheck.decide({"pid": 42, "port": 5}, 10, false, false).duplicate)


func test_live_pid_closed_port() -> void:
	assert_false(InstanceCheck.decide({"pid": 42, "port": 5}, 10, true, false).duplicate, "a reused pid")


func test_live_pid_open_port() -> void:
	var v := InstanceCheck.decide({"pid": 42, "port": 5}, 10, true, true)
	assert_true(v.duplicate)
	assert_true(String(v.reason).contains("already running"), "reason says why")
