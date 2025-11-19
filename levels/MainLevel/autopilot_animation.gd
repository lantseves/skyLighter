extends CanvasLayer

# Слово для отображения
const WORD: String = "autopilot"
const LETTER_SPACING: float = 30.0  # Используется для волны пульсации
const PULSE_SPEED: float = 2.0  # Скорость пульсации
const PULSE_AMPLITUDE: float = 0.1  # Амплитуда пульсации (10%)
const WORD_WIDTH_PERCENT: float = 0.7  # Слово должно занимать 70% ширины экрана

# Массив спрайтов для букв
var letter_sprites: Array = []
var base_scales: Array = []

# Таймер для анимации
var animation_time: float = 0.0

@onready var letters_container: Node2D = $Letters

func _ready() -> void:
	# Скрываем по умолчанию
	visible = false
	_cache_letter_sprites()
	_layout_letters()

func _cache_letter_sprites() -> void:
	letter_sprites.clear()
	base_scales.clear()
	
	if letters_container == null:
		push_warning("Не найден узел Letters в сцене autopilot_animation.")
		return
	
	for child: Node in letters_container.get_children():
		var sprite := child as Sprite2D
		if sprite == null:
			continue
		letter_sprites.append(sprite)
		base_scales.append(sprite.scale)

func _layout_letters() -> void:
	if letters_container == null or letter_sprites.is_empty():
		return
	
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	
	for sprite: Sprite2D in letter_sprites:
		if sprite.texture == null:
			continue
		var texture_size: Vector2 = Vector2(sprite.texture.get_size())
		var half_size: Vector2 = texture_size * sprite.scale * 0.5
		var left: float = sprite.position.x - half_size.x
		var right: float = sprite.position.x + half_size.x
		var top: float = sprite.position.y - half_size.y
		var bottom: float = sprite.position.y + half_size.y
		
		min_x = min(min_x, left)
		max_x = max(max_x, right)
		min_y = min(min_y, top)
		max_y = max(max_y, bottom)
	
	var word_width: float = max_x - min_x
	var word_height: float = max_y - min_y
	if word_width <= 0.0 or word_height <= 0.0:
		return
	
	# Масштабируем слово, если оно занимает больше 70% ширины экрана
	var target_width: float = viewport_size.x * WORD_WIDTH_PERCENT
	var scale_factor: float = min(1.0, target_width / word_width)
	if not is_equal_approx(scale_factor, 1.0):
		for i in range(letter_sprites.size()):
			var sprite: Sprite2D = letter_sprites[i]
			sprite.scale = base_scales[i] * scale_factor
	
	# Пересчитываем габариты после масштабирования
	min_x = INF
	max_x = -INF
	min_y = INF
	max_y = -INF
	for sprite in letter_sprites:
		if sprite.texture == null:
			continue
		var texture_size: Vector2 = Vector2(sprite.texture.get_size())
		var half_size: Vector2 = texture_size * sprite.scale * 0.5
		var left: float = sprite.position.x - half_size.x
		var right: float = sprite.position.x + half_size.x
		var top: float = sprite.position.y - half_size.y
		var bottom: float = sprite.position.y + half_size.y
		min_x = min(min_x, left)
		max_x = max(max_x, right)
		min_y = min(min_y, top)
		max_y = max(max_y, bottom)
	
	word_width = max_x - min_x
	word_height = max_y - min_y
	
	var centered_position := Vector2(
		(viewport_size.x - word_width) * 0.5 - min_x,
		(viewport_size.y - word_height) * 0.5 - min_y
	)
	letters_container.position = centered_position

func _process(delta: float) -> void:
	if not visible:
		return
	
	# Обновляем время анимации
	animation_time += delta * PULSE_SPEED
	
	# Применяем пульсацию к каждой букве
	for sprite_index: int in range(letter_sprites.size()):
		var sprite: Sprite2D = letter_sprites[sprite_index]
		if sprite == null:
			continue
		
		# Вычисляем масштаб с пульсацией (синусоида)
		# Добавляем небольшую задержку для каждой буквы для эффекта волны
		var delay: float = sprite_index * 0.1
		var pulse: float = sin(animation_time + delay) * PULSE_AMPLITUDE
		var current_scale: float = 1.0 + pulse
		
		# Применяем масштаб
		sprite.scale = base_scales[sprite_index] * current_scale

func show_autopilot() -> void:
	"""Показывает анимацию слова autopilot"""
	visible = true
	animation_time = 0.0
	print("Autopilot animation shown")

func hide_autopilot() -> void:
	"""Скрывает анимацию слова autopilot"""
	visible = false
