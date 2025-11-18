extends Area2D

@export var pointAmount:int = 1

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func _on_body_entered(_body: Node2D) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position:y", position.y -50, 0.2)
	InGameVars.score += pointAmount
	if audio_player:
		# Отсоединяем аудиоплеер перед удалением, чтобы звук успел проиграться
		remove_child(audio_player)
		get_tree().current_scene.add_child(audio_player)
		audio_player.play()
		# Удаляем аудиоплеер после окончания звука
		audio_player.finished.connect(audio_player.queue_free)
	self.queue_free()
