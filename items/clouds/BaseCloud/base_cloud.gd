extends Area2D

@export var amountSeconds: int = 1

func _on_body_entered(_body: Node2D) -> void:
	InGameVars.remaining_timer += amountSeconds
	self.queue_free()
