extends CanvasLayer

# Слово для отображения
const WORD: String = "autopilot"
const LETTER_SPACING: float = 30.0  # Расстояние между буквами
const PULSE_SPEED: float = 2.0  # Скорость пульсации
const PULSE_AMPLITUDE: float = 0.1  # Амплитуда пульсации (10%)
const WORD_WIDTH_PERCENT: float = 0.7  # Слово должно занимать 70% ширины экрана

# Массив спрайтов для букв
var letter_sprites: Array = []
var base_scales: Array = []

# Таймер для анимации
var animation_time: float = 0.0

func _ready() -> void:
	# Скрываем по умолчанию
	visible = false
	_create_letters()

func _create_letters() -> void:
	# Получаем размер экрана для позиционирования
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center_y: float = viewport_size.y / 2.0
	
	# Желаемая общая ширина слова (70% от ширины экрана)
	var target_total_width: float = viewport_size.x * WORD_WIDTH_PERCENT
	
	# Сначала вычисляем ширину всех букв при масштабе 1.0
	var letter_textures: Array = []
	var letter_base_widths: Array = []
	var total_letters_width: float = 0.0
	
	for letter_index: int in range(WORD.length()):
		var letter: String = WORD[letter_index]
		var letter_upper: String = letter.to_upper()
		
		# Путь к текстуре буквы
		var texture_path: String = "res://assets/letters/letter" + letter_upper + ".png"
		var texture: Texture2D = load(texture_path)
		
		if texture == null:
			push_error("Не удалось загрузить текстуру для буквы: " + letter_upper)
			letter_textures.append(null)
			letter_base_widths.append(0.0)
			continue
		
		letter_textures.append(texture)
		var base_width: float = texture.get_width()
		letter_base_widths.append(base_width)
		total_letters_width += base_width
	
	# Вычисляем коэффициент масштабирования для достижения 70% ширины экрана
	var scale_factor: float = 1.0
	if total_letters_width > 0.0:
		# Учитываем отступы при вычислении масштаба
		var total_spacing: float = (WORD.length() - 1) * LETTER_SPACING
		var available_width_for_letters: float = target_total_width - total_spacing
		scale_factor = available_width_for_letters / total_letters_width
	
	# Вычисляем начальную позицию для центрирования
	var current_x: float = (viewport_size.x - target_total_width) / 2.0
	
	# Создаём и позиционируем спрайты
	for letter_index: int in range(WORD.length()):
		var texture: Texture2D = letter_textures[letter_index]
		if texture == null:
			continue
		
		var letter: String = WORD[letter_index]
		var letter_upper: String = letter.to_upper()
		
		# Вычисляем финальный масштаб
		var final_scale: float = scale_factor
		
		# Добавляем отступ перед буквой (кроме первой)
		if letter_index > 0:
			current_x += LETTER_SPACING
		
		# Позиционируем букву
		var letter_width: float = letter_base_widths[letter_index] * final_scale
		current_x += letter_width / 2.0
		
		# Создаём спрайт
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.name = "Letter" + letter_upper + str(letter_index)
		sprite.scale = Vector2(final_scale, final_scale)
		sprite.position = Vector2(current_x, center_y)
		
		# Сохраняем базовый масштаб
		base_scales.append(Vector2(final_scale, final_scale))
		letter_sprites.append(sprite)
		
		# Переходим к следующей позиции
		current_x += letter_width / 2.0
		
		# Добавляем спрайт в сцену
		add_child(sprite)

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
