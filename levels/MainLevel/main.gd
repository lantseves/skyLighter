extends Node2D

# Используем @onready для безопасной инициализации
@onready var parallax_bg: ParallaxBackground = $MenuParallax
@onready var player: CharacterBody2D = $Player
@onready var in_game_menu = $InGameMenu
@onready var finish_airport: Node2D = $FinishAirport

# Флаг для отслеживания показа финишного аэропорта
var finish_airport_shown: bool = false

# Настройки фона
var base_scroll_speed = -300.0  # Базовая скорость прокрутки фона
var current_scroll_speed = base_scroll_speed
var speed_multiplier = 1.0  # Множитель скорости для эффектов

func _ready():
	in_game_menu.start_timer()
	#in_game_menu.time_up.connect(end_game())
	# Проверяем инициализацию нод
	if not parallax_bg:
		push_error("ParallaxBG node not found in Main scene!")
	else:
		# Устанавливаем начальное смещение
		parallax_bg.scroll_offset = Vector2.ZERO
	
	# Подключаем сигналы игрока
	if player:
		player.connect("speed_factor_changed", _on_player_speed_factor_changed)
	
	# Подключаем сигнал таймера
	if in_game_menu:
		in_game_menu.connect("timer_reached_zero", _on_timer_reached_zero)
		print("Signal connected to timer_reached_zero")

func _physics_process(delta):
	# Прокрутка фона только если нода инициализирована
	if parallax_bg:
		# Обновляем смещение фона
		parallax_bg.scroll_offset.x += current_scroll_speed * speed_multiplier * delta

# Обработчик изменения скорости от игрока
func _on_player_speed_factor_changed(factor):
	speed_multiplier = factor

func end_game() -> void:
	get_tree().quit()

func _on_timer_reached_zero() -> void:
	print("_on_timer_reached_zero called!")
	if not finish_airport_shown and finish_airport:
		print("Showing finish airport...")
		_show_finish_airport()
		finish_airport_shown = true
	else:
		print("Finish airport already shown or not found!")
	
	# Запускаем режим приземления для игрока
	if player:
		# Передаём позицию финишного аэропорта для точного определения целевой полосы
		var target_position: Vector2 = Vector2.ZERO
		if finish_airport and finish_airport.visible:
			target_position = finish_airport.position
		elif finish_airport:
			# Если аэропорт еще не показан, используем его текущую позицию (он будет показан выше)
			target_position = finish_airport.position
		else:
			# Используем стартовый аэропорт как запасной вариант
			var start_airport: Node2D = $Stat_airport
			if start_airport:
				target_position = start_airport.position
		
		player.start_landing(target_position)
		print("Режим приземления активирован для игрока. Целевая позиция: ", target_position)

func _show_finish_airport() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	
	# Получаем текущую позицию игрока и размещаем аэропорт справа от него
	var player_current_x: float = player.position.x if player else 304.0
	# Размещаем аэропорт справа за экраном относительно текущей позиции игрока
	var airport_x: float = player_current_x + viewport_size.x + 500.0
	
	# Получаем Y позицию первого аэропорта
	var first_airport: Node2D = $Stat_airport
	var airport_y: float = first_airport.position.y if first_airport else 1698.0
	
	# Показываем и перемещаем аэропорт
	finish_airport.visible = true
	finish_airport.position = Vector2(airport_x, airport_y)
	print("Finish airport shown at position: ", finish_airport.position)
	print("Player position: ", player.position if player else "N/A")
