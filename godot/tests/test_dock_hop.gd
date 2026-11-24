extends "res://tests/base_test.gd"
## The avatar's hop above the Dock (dock-dodge D4).

const DockHop := preload("res://scripts/core/dock_hop.gd")
const DT := 1.0 / 60.0


func _run(hop: DockHop, target: float, ceiling: float, seconds: float) -> Array[float]:
	var out: Array[float] = []
	for i in int(ceil(seconds / DT)):
		out.append(hop.step(target, ceiling, DT))
	return out


func test_max_lift_keeps_head_and_label_inside() -> void:
	# Strip 360 pt, feet at 352, an XL buddy (170 pt) and 26 pt for the label.
	var lift := DockHop.max_lift(352.0, -170.0, 26.0)
	assert_eq(lift, 156.0)
	assert_true(352.0 - lift - 170.0 - 26.0 >= 0.0, "head and label inside")
	assert_eq(DockHop.max_lift(100.0, -170.0, 26.0), 0.0, "never below the floor")


func test_hop_up_reaches_target_in_time() -> void:
	var hop := DockHop.new()
	var lifts := _run(hop, 70.0, 300.0, DockHop.HOP_SEC + DT)
	assert_true(is_equal_approx(lifts[-1], 70.0), "at the target, got %s" % lifts[-1])
	assert_true(lifts.max() <= 70.0 + DockHop.HOP_ARC_PT + 0.001, "overshoot within the arc")
	assert_true(lifts.max() > 70.0, "a visible hop, not a slide")
	assert_true(lifts[0] > 0.0, "starts rising at once")


func test_hop_down_when_the_dock_hides() -> void:
	var hop := DockHop.new()
	_run(hop, 70.0, 300.0, 1.0)
	var lifts := _run(hop, 0.0, 300.0, DockHop.HOP_SEC + DT)
	assert_eq(lifts[-1], 0.0)
	assert_true(lifts.max() <= 70.0 + DockHop.HOP_ARC_PT + 0.001)
	assert_true(lifts.min() >= 0.0, "never below the floor")


func test_ceiling_clamps_target_and_arc() -> void:
	var hop := DockHop.new()
	var lifts := _run(hop, 200.0, 156.0, 1.0)
	assert_true(lifts.max() <= 156.0, "never above the ceiling")
	assert_eq(lifts[-1], 156.0)


func test_new_target_mid_hop_continues_smoothly() -> void:
	var hop := DockHop.new()
	_run(hop, 70.0, 300.0, DockHop.HOP_SEC * 0.5)
	var before := hop.value
	var first := hop.step(0.0, 300.0, DT)
	assert_true(absf(first - before) < 15.0, "no jump in position: %s -> %s" % [before, first])
	var lifts := _run(hop, 0.0, 300.0, DockHop.HOP_SEC + DT)
	assert_eq(lifts[-1], 0.0)


func test_resting_on_the_floor() -> void:
	var hop := DockHop.new()
	assert_eq(hop.step(0.0, 300.0, DT), 0.0)
	assert_eq(hop.step(0.0, 300.0, DT), 0.0)
	assert_eq(hop.hops, 0, "no hop without a new target")


func test_counts_hops() -> void:
	var hop := DockHop.new()
	_run(hop, 70.0, 300.0, 0.5)
	_run(hop, 0.0, 300.0, 0.5)
	assert_eq(hop.hops, 2)
