extends Control

func _on_arcade_button_pressed() -> void:
	InGameVars.score = 0
	get_tree().change_scene_to_file("res://levels/MainLevel/main.tscn")
