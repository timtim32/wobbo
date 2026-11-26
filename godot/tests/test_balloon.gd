extends "res://tests/base_test.gd"
## A balloon keeps to its height limit (balloons-and-speech design D6).

const Balloon := preload("res://scripts/avatars/balloon.gd")
const SessionRegistry := preload("res://scripts/core/session_registry.gd")

var balloon: Balloon


func before_each() -> void:
	balloon = Balloon.new()
	balloon.setup("s1", "api", 205.0)
	(Engine.get_main_loop() as SceneTree).root.add_child(balloon)


func after_each() -> void:
	balloon.free()


## Lets the containers lay out, as frames would.
func _settle(max_height_pt: float) -> Vector2:
	var size := Vector2.ZERO
	for i in 4:
		size = balloon.fit(max_height_pt)
		for c in [balloon, balloon.get("_box")]:
			c.notification(Container.NOTIFICATION_SORT_CHILDREN)
	return balloon.fit(max_height_pt)


func test_long_text_is_cut_to_the_limit() -> void:
	balloon.show_content({"type": &"message", "text": "word ".repeat(120), "kind": &"message"})
	var size := _settle(120.0)
	assert_true(size.y <= 120.0, "within the limit, got %s" % size.y)
	var body: Label = balloon.get("_body")
	assert_true(body.max_lines_visible >= 1, "lines are cut")
	assert_eq(size.x, 300.0, "as wide as allowed")


func test_short_text_is_not_cut() -> void:
	balloon.show_content({"type": &"message", "text": "Done", "kind": &"done"})
	var size := _settle(200.0)
	assert_eq((balloon.get("_body") as Label).max_lines_visible, -1)
	assert_eq(size.x, 120.0, "narrowest balloon")
	assert_true(size.y < 80.0, "small, got %s" % size.y)


func test_question_with_field_and_buttons() -> void:
	balloon.show_content({"type": &"request", "id": "r1", "index": 1, "count": 2,
		"request": SessionRegistry.Request.new("r1", "s1", "question", "Deploy?", ["yes", "no"], true)})
	_settle(200.0)
	assert_eq((balloon.get("_buttons") as Container).get_child_count(), 2, "one button per choice")
	assert_true((balloon.get("_field") as Control).visible, "text field")
	assert_false((balloon.get("_bar") as Control).visible, "no time-out, no bar")
	assert_eq((balloon.get("_count") as Label).text, "1 of 2")


func test_permission_labels() -> void:
	balloon.show_content({"type": &"request", "id": "p1", "index": 1, "count": 1,
		"request": SessionRegistry.Request.new("p1", "s1", "permission", "Bash: ls", ["allow", "deny"], false, 1, 20)})
	var labels := (balloon.get("_buttons") as Container).get_children().map(func(b): return b.text)
	assert_eq(labels, ["Allow", "Deny"])
	assert_true((balloon.get("_bar") as Control).visible, "time-left bar")
	assert_eq((balloon.get("_count") as Label).text, "Permission")


func test_asked_question_shows_choices_and_hint() -> void:
	balloon.show_content({"type": &"asked", "text": "Shall I commit?", "choices": ["Commit and PR", "Try it first"]})
	_settle(200.0)
	var note: Label = balloon.get("_note")
	assert_true(note.visible)
	assert_eq(note.text, "Commit and PR · Try it first\nAnswer in the session")
	assert_eq((balloon.get("_buttons") as Container).get_child_count(), 0, "no answer buttons")
	assert_true(balloon.is_asked())
	balloon.show_content({"type": &"message", "text": "hi", "kind": &"message"})
	assert_false(note.visible, "only for asked questions")


func test_set_hue_recolours_the_name() -> void:
	balloon.set_hue(355.0)
	var name_label: Label = balloon.get("_name")
	assert_eq(name_label.get_theme_color("font_color"), Balloon.accent_of(355.0), "name in the new colour")
	assert_eq(balloon.get("_accent"), Balloon.accent_of(355.0), "accent follows")
