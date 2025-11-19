extends Area2D

const FLOATING_POINTS_SCENE: PackedScene = preload("res://items/coins/BaseCoin/floating_text.tscn")

@export var pointAmount:int = 1

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func _on_body_entered(_body: Node2D) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position:y", position.y -50, 0.2)
	InGameVars.score += pointAmount
	_show_points_text()
	if audio_player:
		# Отсоединяем аудиоплеер перед удалением, чтобы звук успел проиграться
		remove_child(audio_player)
		get_tree().current_scene.add_child(audio_player)
		audio_player.play()
		# Удаляем аудиоплеер после окончания звука
		audio_player.finished.connect(audio_player.queue_free)
	self.queue_free()

func _show_points_text() -> void:
	if FLOATING_POINTS_SCENE == null:
		return
	
	# Создаем Node2D для текста
	var floating_text: Node2D = FLOATING_POINTS_SCENE.instantiate() as Node2D
	
	# Устанавливаем начальную позицию (немного выше звезды)
	var start_position: Vector2 = global_position
	start_position.y -= 30.0
	
	# Добавляем в сцену ПЕРЕД вызовом setup, чтобы get_tree() был доступен
	var scene_root: Node = get_tree().current_scene
	scene_root.add_child(floating_text)
	
	# Настраиваем текст после добавления в дерево
	floating_text.setup(start_position, pointAmount)
