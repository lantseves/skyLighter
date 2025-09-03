extends Area2D

func _on_body_entered(_body: Node2D) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position:y", position.y -50, 0.2)
	InGameVars.score += 1
	self.queue_free()
