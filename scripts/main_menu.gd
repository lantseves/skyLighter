extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_arcade_button_pressed() -> void:
	InGameVars.score = 0
	get_tree().change_scene_to_file("res://scenes/main.tscn")
