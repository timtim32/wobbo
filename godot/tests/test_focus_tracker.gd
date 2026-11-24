extends "res://tests/base_test.gd"

const FocusTracker := preload("res://scripts/core/focus_tracker.gd")

var focus: FocusTracker


func before_each() -> void:
	focus = FocusTracker.new()


func test_single_owner_request_and_release() -> void:
	assert_false(focus.has_requests())
	assert_true(focus.request(1), "first request takes focus")
	assert_true(focus.has_requests())
	assert_true(focus.release(1), "last release hands focus back")
	assert_false(focus.has_requests())


func test_same_owner_is_counted() -> void:
	assert_true(focus.request(1))
	assert_false(focus.request(1), "second request from same owner")
	assert_eq(focus.count(1), 2)
	assert_false(focus.release(1), "one request still open")
	assert_true(focus.release(1))
	assert_eq(focus.count(1), 0)


func test_multiple_owners() -> void:
	assert_true(focus.request(1))
	assert_false(focus.request(2), "focus already taken")
	assert_false(focus.release(1), "owner 2 still holds focus")
	assert_true(focus.has_requests())
	assert_true(focus.release(2))


func test_release_without_request_is_noop() -> void:
	assert_false(focus.release(42))
	focus.request(1)
	assert_false(focus.release(42), "unknown owner does not release others")
	assert_eq(focus.count(1), 1)


func test_release_all() -> void:
	focus.request(1)
	focus.request(1)
	focus.request(2)
	assert_false(focus.release_all(1), "owner 2 still holds focus")
	assert_eq(focus.count(1), 0)
	assert_true(focus.release_all(2))
	assert_false(focus.release_all(2), "already released")
