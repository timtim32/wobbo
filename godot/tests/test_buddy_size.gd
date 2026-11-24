extends "res://tests/base_test.gd"
## Buddy sizes (buddy-size D2).

const BuddySize := preload("res://scripts/core/buddy_size.gd")


func test_heights() -> void:
	assert_eq(BuddySize.height_of("small"), 80.0)
	assert_eq(BuddySize.height_of("normal"), 110.0)
	assert_eq(BuddySize.height_of("large"), 140.0)
	assert_eq(BuddySize.height_of("xl"), 170.0)
	assert_eq(BuddySize.height_of("huge"), 110.0, "unknown: Normal")


func test_menu_items() -> void:
	var items := BuddySize.items("large")
	assert_eq(items.map(func(i): return i.label), ["Small", "Normal", "Large", "Extra large"])
	assert_eq(items.filter(func(i): return i.checked).map(func(i): return i.value), ["large"])
	assert_eq(BuddySize.items("bogus").filter(func(i): return i.checked).map(func(i): return i.value), ["normal"])
