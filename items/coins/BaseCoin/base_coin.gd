extends Area2D

const FLOATING_POINTS_SCENE: PackedScene = preload("res://items/coins/BaseCoin/floating_text.tscn")

@export var pointAmount:int = 1

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var is_collected: bool = false  # Флаг для предотвращения повторного сбора
var collection_tween: Tween = null  # Ссылка на Tween анимации сбора

# Метод для проверки, собирается ли монета (для использования в coin_factory)
func is_being_collected() -> bool:
	return is_collected

func _on_body_entered(_body: Node2D) -> void:
	# Проверяем, не собрана ли уже монета
	if is_collected:
		return
	
	# Проверяем глобальный флаг режима посадки
	if InGameVars.is_landing:
		# Игрок в режиме посадки - не собираем монету
		return
	
	# Помечаем монету как собранную
	is_collected = true
	
	# Отключаем коллизию, чтобы монета не собиралась повторно
	monitoring = false
	monitorable = false
	
	# Проверяем, что объект все еще в дереве сцены
	if not is_inside_tree():
		return
	
	InGameVars.score += pointAmount
	_show_points_text()
	if audio_player:
		# Отсоединяем аудиоплеер перед удалением, чтобы звук успел проиграться
		remove_child(audio_player)
		get_tree().current_scene.add_child(audio_player)
		audio_player.play()
		# Удаляем аудиоплеер после окончания звука
		audio_player.finished.connect(audio_player.queue_free)
	
	# Создаем Tween на объекте (автоматически привязывается к узлу)
	# create_tween() на узле автоматически привязывает Tween к этому узлу
	collection_tween = create_tween()
	collection_tween.set_parallel(false)
	collection_tween.tween_property(self, "position:y", position.y - 50, 0.2)
	# Подключаем сигнал finished для удаления объекта после завершения анимации
	collection_tween.finished.connect(_on_collection_animation_finished)

func _on_collection_animation_finished() -> void:
	# Удаляем объект после завершения анимации
	queue_free()

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
