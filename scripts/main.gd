extends Node2D

# Используем @onready для безопасной инициализации
@onready var parallax_bg: ParallaxBackground = $ParallaxBG
@onready var player: CharacterBody2D = $Player

# Настройки фона
var base_scroll_speed = -300.0  # Базовая скорость прокрутки фона
var current_scroll_speed = base_scroll_speed
var speed_multiplier = 1.0  # Множитель скорости для эффектов

func _ready():
	# Проверяем инициализацию нод
	if not parallax_bg:
		push_error("ParallaxBG node not found in Main scene!")
	else:
		# Устанавливаем начальное смещение
		parallax_bg.scroll_offset = Vector2.ZERO
	
	# Подключаем сигналы игрока
	if player:
		player.connect("speed_factor_changed", _on_player_speed_factor_changed)

func _physics_process(delta):
	# Прокрутка фона только если нода инициализирована
	if parallax_bg:
		# Обновляем смещение фона
		parallax_bg.scroll_offset.x += current_scroll_speed * speed_multiplier * delta

# Обработчик изменения скорости от игрока
func _on_player_speed_factor_changed(factor):
	speed_multiplier = factor
