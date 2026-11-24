extends "res://tests/base_test.gd"
## A tilted body's box (buddy-drag D3).

const WalkwayBody := preload("res://scripts/walkway/walkway_body.gd")


func test_rect_of_an_upright_body() -> void:
	var b = WalkwayBody.new()
	b.position = Vector2(200, 300)
	assert_eq(b.rect_pt(), Rect2(145, 190, 110, 110))
	b.free()


func test_rect_of_a_body_on_its_side() -> void:
	var b = WalkwayBody.new()
	b.position = Vector2(200, 300)
	b.tilt = PI / 2.0 # rotated clockwise on screen: the head points right
	var r: Rect2 = b.rect_pt()
	assert_true(r.position.distance_to(Vector2(200, 245)) < 0.01, "position %s" % r.position)
	assert_true(r.size.distance_to(Vector2(110, 110)) < 0.01, "size %s" % r.size)
	b.free()


func test_rect_of_a_body_upside_down() -> void:
	var b = WalkwayBody.new()
	b.position = Vector2(200, 300)
	b.tilt = PI
	var r: Rect2 = b.rect_pt()
	assert_true(r.position.distance_to(Vector2(145, 300)) < 0.01, "head below the feet: %s" % r)
	b.free()
