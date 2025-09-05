extends Area2D

@export var amountSeconds: int = 1
@export var max_coin: int = 1
@export var min_coin: int = 1

func _on_body_entered(_body: Node2D) -> void:
	InGameVars.remaining_timer += amountSeconds
	InGameVars.score += randi_range(min_coin, max_coin)
	self.queue_free()
