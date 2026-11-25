extends "res://tests/base_test.gd"

const AppMenu := preload("res://scripts/core/app_menu.gd")


func test_claude_item() -> void:
	assert_eq(AppMenu.claude_item(false, false), {"label": "Connect to Claude Code…", "disabled": false})
	assert_eq(AppMenu.claude_item(true, false), {"label": "Disconnect from Claude Code", "disabled": false})
	assert_eq(AppMenu.claude_item(true, true).disabled, true, "busy")


func test_login_item_only_for_the_installed_app() -> void:
	assert_eq(AppMenu.login_item(false, "applications", "not_registered").enabled, false, "editor run")
	assert_eq(AppMenu.login_item(true, "disk_image", "not_registered").enabled, false, "from the disk image")
	assert_eq(AppMenu.login_item(true, "applications", "unavailable").enabled, false, "before macOS 13")
	assert_eq(AppMenu.login_item(true, "applications", "not_registered"), {"enabled": true, "checked": false})


func test_login_check_mark_follows_macos() -> void:
	assert_true(AppMenu.login_item(true, "applications", "enabled").checked, "enabled")
	assert_false(AppMenu.login_item(true, "applications", "requires_approval").checked, "waiting for approval")
	assert_false(AppMenu.login_item(true, "applications", "not_found").checked, "removed in System Settings")


func test_needs_login_status_only_where_the_item_can_be_enabled() -> void:
	assert_true(AppMenu.needs_login_status(true, "applications"), "installed app")
	assert_false(AppMenu.needs_login_status(false, "applications"), "editor run")
	assert_false(AppMenu.needs_login_status(true, "disk_image"), "from the disk image")
	assert_false(AppMenu.needs_login_status(true, "elsewhere"), "elsewhere")


func test_offer_move() -> void:
	assert_false(AppMenu.offer_move(true, "applications"))
	assert_true(AppMenu.offer_move(true, "disk_image"))
	assert_true(AppMenu.offer_move(true, "translocated"))
	assert_true(AppMenu.offer_move(true, "elsewhere"))
	assert_false(AppMenu.offer_move(false, "elsewhere"), "never in editor runs")
