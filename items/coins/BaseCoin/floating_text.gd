extends Node2D

var world_position: Vector2
var points_label: Label
var animation_tween: Tween

func setup(target_world_position: Vector2, point_amount: int) -> void:
	world_position = target_world_position
	
	# Создаем CanvasLayer для UI элементов
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.layer = 100  # Высокий слой, чтобы был поверх всего
	
	# Создаем Control для позиционирования
	var control: Control = Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Создаем Label для отображения текста с номиналом
	points_label = Label.new()
	points_label.text = "+" + str(point_amount)
	points_label.modulate = Color.WHITE
	
	# Настраиваем стиль текста
	var font_size: int = 32
	points_label.add_theme_font_size_override("font_size", font_size)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Добавляем Label в Control, Control в CanvasLayer
	control.add_child(points_label)
	canvas_layer.add_child(control)
	
	# Добавляем CanvasLayer в этот Node2D
	add_child(canvas_layer)
	
	# Создаем анимацию: поднимаем вверх и делаем прозрачным
	animation_tween = get_tree().create_tween()
	var start_y: float = world_position.y
	var end_y: float = start_y - 50.0  # Поднимаем на 50 пикселей вверх
	
	# Анимируем позицию и прозрачность
	animation_tween.parallel().tween_method(_update_world_y, start_y, end_y, 0.8)
	animation_tween.parallel().tween_property(points_label, "modulate:a", 0.0, 0.8)
	
	# Удаляем этот Node2D после завершения анимации
	animation_tween.tween_callback(queue_free)

func _update_world_y(new_y: float) -> void:
	world_position.y = new_y

func _process(_delta: float) -> void:
	# Обновляем позицию текста каждый кадр, следя за камерой
	if points_label != null:
		var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
		var screen_position: Vector2 = canvas_transform * world_position
		points_label.position = screen_position
		points_label.position.x -= 30.0  # Центрируем по горизонтали
		points_label.position.y -= 15.0  # Центрируем по вертикали
