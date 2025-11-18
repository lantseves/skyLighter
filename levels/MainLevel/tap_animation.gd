extends CanvasLayer

# Ссылки на спрайты для анимации
@onready var tap_sprite: Sprite2D = $TapSprite
@onready var tap_tick_sprite: Sprite2D = $TapTickSprite

# Ссылка на игрока для проверки состояния
var player: CharacterBody2D = null

# Параметры анимации
const ANIMATION_SPEED: float = 0.5  # Скорость переключения между кадрами (секунды)
const TAP_SIZE_PERCENT: float = 0.1  # Размер тапа составляет 10% от высоты экрана

var animation_timer: float = 0.0
var is_showing_tap: bool = true  # Показываем tap.png или tapTick.png

func _ready() -> void:
	# Получаем ссылку на игрока
	player = get_node_or_null("../Player")
	
	# Устанавливаем начальное состояние
	if tap_sprite:
		tap_sprite.visible = true
	if tap_tick_sprite:
		tap_tick_sprite.visible = false
	
	# Размещаем анимацию в центре экрана и устанавливаем размер
	_setup_position_and_size()

func _setup_position_and_size() -> void:
	# Получаем размер экрана
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	
	# Вычисляем желаемую высоту тапа (20% от высоты экрана)
	var target_height: float = viewport_size.y * TAP_SIZE_PERCENT
	
	# Вычисляем масштаб для спрайтов
	var scale_factor: float = 1.0
	if tap_sprite and tap_sprite.texture:
		var texture_height: float = tap_sprite.texture.get_height()
		if texture_height > 0.0:
			scale_factor = target_height / texture_height
	
	# Применяем масштаб и позицию к спрайтам
	if tap_sprite:
		tap_sprite.scale = Vector2(scale_factor, scale_factor)
		tap_sprite.position = viewport_size / 2.0
	
	if tap_tick_sprite:
		tap_tick_sprite.scale = Vector2(scale_factor, scale_factor)
		tap_tick_sprite.position = viewport_size / 2.0

func _process(delta: float) -> void:
	# Проверяем состояние игрока
	if player != null and player.is_start_position:
		# Игрок стоит на месте - показываем анимацию
		visible = true
		
		# Анимируем переключение между кадрами
		animation_timer += delta
		if animation_timer >= ANIMATION_SPEED:
			animation_timer = 0.0
			is_showing_tap = not is_showing_tap
			
			# Переключаем видимость спрайтов
			if tap_sprite:
				tap_sprite.visible = is_showing_tap
			if tap_tick_sprite:
				tap_tick_sprite.visible = not is_showing_tap
	else:
		# Игра началась - скрываем анимацию
		visible = false

