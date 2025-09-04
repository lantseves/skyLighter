extends Area2D

@export var pointAmount:int = 1

func _on_body_entered(_body: Node2D) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position:y", position.y -50, 0.2)
	InGameVars.score += pointAmount
	self.queue_free()
