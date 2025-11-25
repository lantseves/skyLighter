extends Area2D

const FLOATING_SECONDS_SCENE: PackedScene = preload("res://items/clouds/BaseCloud/floating_seconds_text.tscn")

@export var amountSeconds: int = 1

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func _on_body_entered(_body: Node2D) -> void:
	# Проверяем глобальный флаг режима посадки
	if InGameVars.is_landing:
		# Игрок в режиме посадки - не собираем облако
		return
	
	InGameVars.remaining_timer += amountSeconds
	_show_seconds_text()
	if audio_player:
		# Отсоединяем аудиоплеер перед удалением, чтобы звук успел проиграться
		remove_child(audio_player)
		get_tree().current_scene.add_child(audio_player)
		audio_player.play()
		# Удаляем аудиоплеер после окончания звука
		audio_player.finished.connect(audio_player.queue_free)
	self.queue_free()

func _show_seconds_text() -> void:
	# Показываем текст только если количество секунд не равно нулю
	if amountSeconds == 0:
		return
	
	if FLOATING_SECONDS_SCENE == null:
		return
	
	# Создаем Node2D для текста
	var floating_text: Node2D = FLOATING_SECONDS_SCENE.instantiate() as Node2D
	
	# Устанавливаем начальную позицию (немного выше облака)
	var start_position: Vector2 = global_position
	start_position.y -= 30.0
	
	# Определяем, bonus это или penalty
	var is_bonus: bool = amountSeconds > 0
	
	# Добавляем в сцену ПЕРЕД вызовом setup, чтобы get_tree() был доступен
	var scene_root: Node = get_tree().current_scene
	scene_root.add_child(floating_text)
	
	# Настраиваем текст после добавления в дерево
	floating_text.setup(start_position, amountSeconds, is_bonus)
