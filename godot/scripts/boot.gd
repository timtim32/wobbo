extends Node
## The main scene: loads the real scene (main.tscn) unless another Wobbo is
## already running (standalone-app design D6), so a second instance never
## creates the menu bar icon or the buddies.


func _ready() -> void:
	if Instance.duplicate:
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
