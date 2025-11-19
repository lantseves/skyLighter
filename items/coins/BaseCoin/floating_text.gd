extends Node2D

var world_position: Vector2
var points_label: Label
var animation_tween: Tween
var camera: Camera2D = null

func setup(target_world_position: Vector2, point_amount: int) -> void:
	world_position = target_world_position
	
	# Находим камеру для преобразования координат
	_find_camera()
	
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
	
	# Устанавливаем минимальный размер для Label, чтобы текст был виден
	points_label.custom_minimum_size = Vector2(100, 50)
	
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

func _find_camera() -> void:
	# Ищем камеру в дереве сцены
	var viewport: Viewport = get_viewport()
	if viewport:
		camera = viewport.get_camera_2d()
		if camera == null:
			# Если камера не найдена, пробуем найти через дерево сцены
			var root: Node = get_tree().get_root()
			if root:
				camera = root.get_node_or_null("Main/Player/Camera2D")

func _world_to_screen_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	
	if camera != null:
		var viewport_rect: Rect2 = viewport.get_visible_rect()
		var viewport_size: Vector2 = viewport_rect.size
		var camera_center: Vector2 = camera.get_screen_center_position()
		var camera_top_left: Vector2 = camera_center - (viewport_size * 0.5)
		return world_position - camera_top_left
	
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	return canvas_transform * world_position

func _update_world_y(new_y: float) -> void:
	world_position.y = new_y

func _process(_delta: float) -> void:
	# Обновляем позицию текста каждый кадр, следя за камерой
	if points_label == null:
		return
	
	if camera == null:
		_find_camera()
	
	var screen_position: Vector2 = _world_to_screen_position()
	
	# Устанавливаем позицию Label
	points_label.position = screen_position
	points_label.position.x -= 50.0  # Центрируем по горизонтали (половина минимальной ширины)
	points_label.position.y -= 25.0  # Центрируем по вертикали (половина минимальной высоты)
