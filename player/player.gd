extends CharacterBody2D                      # Скрипт висит на узле-персонаже с физикой (движение через velocity/move_and_slide)

signal speed_factor_changed(factor: float)   # Сигнал наружу: сообщает, во сколько раз текущая горизонтальная скорость отличается от базовой (для HUD/аудио/параллакса)
signal game_started                          # Сигнал: игра началась (пользователь кликнул)

# === Параметры физики/управления ===
const GRAVITY := 900.0                       # Гравитация, добавляется к вертикальной скорости каждый кадр (положительное значение тянет вниз)
const BASE_SPEED := 300.0                      # БАЗОВАЯ скорость по X (сейчас 0 — см. заметку в конце про деление на ноль)
const SHIFT_SPEED_ADD := 400.0               # Прибавка к скорости по X при зажатом действии "jet_dash" (ускорение)
const SPEED_LERP := 5.0                      # Коэффициент сглаживания скорости: чем больше, тем быстрее velocity тянется к target_velocity
const ROT_LERP := 5.0                        # Коэффициент сглаживания поворота: скорость подтягивания rotation_degrees к целевому углу
const MAX_TILT := 30.0                       # Максимальный визуальный наклон самолёта (в градусах), чтобы не «ломать» спрайт
const JUMP_FORCE := -700.0                   # Импульс прыжка/рывка вверх (отрицательное Y — вверх в Godot)

# Бусты (короткие режимы с таймером)
const ZOOM_CLIMB_ACCEL := 600.0              # Вертикальное ускорение для «зоом-клайма» (резкий подъём)
const DIVE_BOOST_ACCEL := 500.0              # Вертикальное ускорение для «дайв-буста» (резкое пикирование)
const BOOST_TIME := 1.5                      # Длительность эффектов буста (в секундах)

# Взлёт (авторазгон после первого клика)
const TAKEOFF_TIME := 2.0                    # Длительность авторазгона (сек.)
const START_JUMP_FORCE := -1500.0

# Петля
const LOOP_TIME := 2.5                       # Время выполнения петли (полный круг), секунды
const LOOP_RADIUS := 250.0                   # Радиус окружности, по которой летим, когда крутим петлю

#Размер отступа от верхней и нижней границы
@export var window_margin: float = 200       # Экспортный параметр: отступ сверху/снизу, чтобы не выходить за видимую область

# Ограничения по высоте (экран/уровень)
var MAX_Y_POSITION :float                # Верхняя граница допустимой высоты (будет переопределена в _ready)
var MIN_Y_POSITION :float                # Нижняя граница допустимой высоты (будет переопределена в _ready)

# === Состояния ===
var is_zooming: bool = false                 # Флаг: выполняется ли сейчас «зоом-клайм» (подъём с бустом)
var is_diving: bool = false                  # Флаг: выполняется ли сейчас «дайв-буст» (пикирование с бустом)
var is_looping: bool = false                 # Флаг: крутим ли сейчас петлю
var can_control: bool = true     
var is_start_position: bool = true            # Можно ли сейчас принимать ввод (во время бустов/петли — false)
var is_takeoff: bool = false                 # Флаг: активен ли сценарий авторазгона/взлёта
var _takeoff_elapsed: float = 0.0            # Сколько прошло времени с начала взлёта
var is_landing: bool = false                 # Флаг: активен ли режим приземления (таймер достиг нуля)
var is_on_runway: bool = false               # Флаг: касается ли самолёт полосы
var _was_on_runway: bool = false             # Флаг: касался ли самолёт полосы в предыдущем кадре
var _target_runway_y: float = 0.0            # Целевая Y позиция полосы для приземления
var _target_runway_x: float = 0.0            # Целевая X позиция полосы для приземления
var _safe_landing_altitude: float = 0.0      # Безопасная высота для полёта к полосе
var _last_jump_time: float = 0.0             # Время последнего прыжка (для ограничения частоты)
var _landing_stop_timer: float = 0.0         # Таймер остановки после приземления
var _has_landed: bool = false                # Флаг: приземлился ли самолёт и начал остановку
var _menu_transition_started: bool = false   # Флаг: начался ли переход в меню (чтобы не вызывать несколько раз)
const LANDING_JUMP_COOLDOWN: float = 1.0     # Минимальное время между прыжками при приземлении (увеличено)
const LANDING_STOP_TIME: float = 1.00         # Время остановки после приземления перед переходом в меню

var target_velocity: Vector2 = Vector2(BASE_SPEED, 0.0)  # Целевая скорость, к которой мы сглаженно тянем фактическую velocity
var target_rotation_deg := 0.0                           # Целевой визуальный угол наклона (в градусах), к нему сглаженно тянемся

# Петля
var loop_progress: float = 0.0               # От 0 до 1 — прогресс выполнения петли за LOOP_TIME
var loop_center := Vector2.ZERO              # Центр окружности для петли (над текущей позицией на радиус)
var loop_start_rotation: float = 0.0         # Запоминаем базовый поворот при старте петли, чтобы анимировать вращение

# Для событий скорости (чтобы не спамить сигнал)
var _last_speed_factor: float = 1.0          # Последний отправленный наружу «фактор скорости» (для отсечки мелких изменений)

# Для управления столкновениями
var _original_collision_mask: int = 14      # Исходная маска столкновений (облака + монеты + аэропорт)

const MIN_SAFE_HEIGHT_MARGIN: float = 100.0  # Запас от нижней границы для предотвращения улёта за экран
@export var landing_hold_distance_x: float = 800.0  # Дистанция по X до полосы, на которой держим высоту
@export var landing_hold_altitude_above_runway: float = 120.0  # Минимальная высота над полосой до входа в зону посадки

# Ссылки на узлы звука мотора
@onready var propeller_start_sound: AudioStreamPlayer = $PropellerStartSound
@onready var propeller_loop_sound: AudioStreamPlayer = $PropellerLoopSound

func get_player_y() -> float:                # Публичный геттер: отдать текущую высоту игрока (может пригодиться другим узлам)
	return self.position.y                   # Возвращаем Y-позицию узла

func _ready() -> void:                       # Вызывается при входе узла в сцену
	rotation_degrees = 0.0                   # Сбрасываем визуальный наклон в ноль
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size  # Узнаём размер видимой области (экрана)
	MAX_Y_POSITION = window_margin           # Верхняя граница = отступ сверху
	MIN_Y_POSITION = viewport_size.y - 50 # Нижняя граница = высота экрана минус отступ снизу
	_original_collision_mask = collision_mask  # Сохраняем исходную маску столкновений
	
	# Настраиваем зацикливание звука мотора
	if propeller_loop_sound and propeller_loop_sound.stream:
		# Включаем зацикливание в самом аудиостриме (для OGG Vorbis)
		var stream: AudioStream = propeller_loop_sound.stream
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		# Подключаем сигнал завершения зацикленного звука для перезапуска (на случай если loop не сработает)
		if not propeller_loop_sound.finished.is_connected(_on_propeller_loop_finished):
			propeller_loop_sound.finished.connect(_on_propeller_loop_finished)
	
	# Подключаем сигнал завершения стартового звука к запуску зацикленного
	if propeller_start_sound:
		if not propeller_start_sound.finished.is_connected(_on_propeller_start_finished):
			propeller_start_sound.finished.connect(_on_propeller_start_finished)

func _physics_process(delta: float) -> void: # Физический кадр: безопасное место менять velocity/position
	if is_start_position:
		if Input.is_action_just_pressed("jump"):
			_start_takeoff()
		return

	# Этап авторазгона: игнорируем ввод и управляем скоростями сами
	if is_takeoff:
		_process_takeoff(delta)
		return

	InGameVars.current_speed = target_velocity.x    # Текущая горизонтальная скорость для глобальных расчётов
	if is_looping:                           # Если сейчас крутим петлю…
		_process_loop(delta)                 # …двигаем вручную по окружности
		# столкновения по траектории петли не учитываем
		move_and_collide(Vector2.ZERO)       # Нулевое перемещение, чтобы не обрабатывались стандартные слайды/коллизии
		return                               # Выходим: обычную физику в петле не считаем

	# Режим приземления: таймер достиг нуля
	if is_landing:
		_process_landing(delta)
		return

	if can_control:                          # Если управление разрешено…
		_handle_input()                      # …обрабатываем ввод (скорость по X, прыжок, бусты, старт петли)

	# Гравитация, если нет вертикального буста
	if not is_zooming and not is_diving:     # Пока не активен ни подъём, ни пикирование…
		# Проверяем, не выполняется ли сейчас активный прыжок вверх (например, стартовый рывок)
		# Проверяем ДО применения гравитации, чтобы не перекрывать активные прыжки
		var is_jumping_up: bool = target_velocity.y < -300.0  # Если целевая вертикальная скорость вверх больше 300, значит активный прыжок
		
		target_velocity.y += GRAVITY * delta # …тянем цель по Y вниз гравитацией
		
		# Если нет активного ввода - поддерживаем высоту маленькими прыжками (как при посадке)
		var has_active_input: bool = Input.is_action_pressed("jump") or Input.is_action_pressed("zoom_climb") or Input.is_action_pressed("dive_boost")
		
		if not has_active_input and not is_jumping_up:
			# Вычисляем безопасную высоту полета (аналогично посадке)
			var safe_flight_altitude: float = MIN_Y_POSITION - landing_hold_altitude_above_runway
			var altitude_diff: float = position.y - safe_flight_altitude
			
			if altitude_diff > 10.0:
				# Самолёт ниже безопасной высоты - поднимаем его маленькими прыжками
				var lift_strength: float = clampf(altitude_diff / 100.0, 0.2, 0.6)
				target_velocity.y = JUMP_FORCE * lift_strength
			elif altitude_diff < -10.0:
				# Самолёт выше безопасной высоты - опускаем под гравитацией (уже применена выше)
				pass
			else:
				# На безопасной высоте - поддерживаем горизонтальный полёт маленькими прыжками
				# Если вертикальная скорость слишком большая вниз - делаем маленький прыжок
				if velocity.y > 100.0:
					target_velocity.y = JUMP_FORCE * 0.3  # Маленький прыжок для поддержания

	# Плавно тянем фактическую скорость к целевой
	velocity = velocity.lerp(target_velocity, SPEED_LERP * delta)  # Сглаженное приближение velocity к target_velocity

	# Вертикальные рамки уровня
	position.y = clamp(position.y, MAX_Y_POSITION, MIN_Y_POSITION) # Жёстко ограничиваем Y в пределах окна

	# Плавный поворот к целевому углу
	var diff := target_rotation_deg - rotation_degrees             # Разница между целевым и текущим углом
	if abs(diff) > 0.5:                                            # Если отклонение заметное…
		rotation_degrees = lerp(rotation_degrees, target_rotation_deg, ROT_LERP * delta)  # …сглаженно тянем
	else:
		rotation_degrees = target_rotation_deg                      # Если почти дошли — просто выставляем ровно

	# Движение
	move_and_slide()                                               # Применяем velocity с учётом физики (скольжение по полу и т.п.)

	# Обновим фактор скорости для HUD/аудио
	_update_speed_factor()                                         # Посчитаем factor (скорость/база) и при необходимости сэмитим сигнал

# === Ввод и режимы ===

func _handle_input() -> void:                # Сбор инпута (нужны Actions в Input Map: jet_dash, jump, zoom_climb, dive_boost, loop)
	if is_takeoff:
		return                               # Во время взлёта пользователю управление недоступно
	# Базовая горизонтальная скорость + Shift-ускорение (удержание jet_dash)
	var desired_x := BASE_SPEED              # Начинаем с базовой скорости
	if Input.is_action_pressed("jet_dash"):  # Если зажата клавиша/кнопка «ускорения»…
		desired_x += SHIFT_SPEED_ADD         # …добавляем прибавку
	target_velocity.x = max(desired_x, 0.0)  # Не даём ехать назад: минимум — 0 по X

	# Наклон носа от вертикальной скорости (визуальный)
	# Ограничиваем до MAX_TILT, чтобы не «ломать» спрайт
	target_rotation_deg = clamp(velocity.y * 0.05, -MAX_TILT, MAX_TILT)  # Чем сильнее скорость вверх — тем нос вниз (и наоборот)

	if Input.is_action_just_pressed("jump"): # «Прыжок/рывок вверх» на нажатие
		_start_jump()                        # Запускаем импульс по Y

	if Input.is_action_just_pressed("zoom_climb") and not is_zooming:  # Старт «зоом-клайма», если ещё не активен
		_start_zoom()                        # Включаем подъём с бустом

	if Input.is_action_just_pressed("dive_boost") and not is_diving:   # Старт «дайв-буста», если ещё не активен
		_start_dive()                        # Включаем пикирование с бустом

	if Input.is_action_just_pressed("loop") and not is_looping:        # Начать петлю (по кнопке), если ещё не крутим
		_start_loop()                        # Переходим в режим петли

# === Взлёт (авторазгон) ===
func _start_takeoff() -> void:
	is_start_position = false
	is_takeoff = true
	can_control = false
	_takeoff_elapsed = 0.0
	# Начинаем с полной остановки; вертикального импульса нет во время авторазгона
	velocity = Vector2.ZERO
	target_velocity = Vector2(0.0, 0.0)
	target_rotation_deg = 0.0
	_update_speed_factor(true)
	# Запускаем звук мотора
	_start_propeller_sound()
	# Эмитим сигнал о начале игры
	emit_signal("game_started")

func _process_takeoff(delta: float) -> void:
	_takeoff_elapsed += delta
	var t := clampf(_takeoff_elapsed / TAKEOFF_TIME, 0.0, 1.0)

	# Плавный разгон по X: 0 -> BASE_SPEED за 1 секунду (без подъёма по Y)
	var desired_x := lerpf(0.0, BASE_SPEED, t)
	target_velocity.x = desired_x
	target_velocity.y = 0.0
	target_rotation_deg = 0.0

	# Применяем сглажение и движение
	velocity = velocity.lerp(target_velocity, SPEED_LERP * delta)
	position.y = clamp(position.y, MAX_Y_POSITION, MIN_Y_POSITION)
	move_and_slide()

	InGameVars.current_speed = target_velocity.x
	_update_speed_factor()

	if t >= 1.0:
		_end_takeoff()

func _end_takeoff() -> void:
	is_takeoff = false
	can_control = true
	target_rotation_deg = 0.0
	# Зафиксируем базовую цель по X, затем выполняем единичный прыжок и отдаём управление
	target_velocity.x = BASE_SPEED
	target_velocity.y = 0.0
	_update_speed_factor(true)
	_start_jump(START_JUMP_FORCE)       # Слегка наклоняем нос вниз для визуальной динамики
	
func _start_jump(velocity: float = JUMP_FORCE) -> void:
	target_velocity.y = velocity         # Устанавливаем целевую вертикальную скорость резко вверх
	target_rotation_deg = -15.0

func _start_zoom() -> void:                   # Запуск режима «зоом-клайм» (подъём)
	is_zooming = true                        # Помечаем состояние
	can_control = false                      # На время буста блокируем ручное управление
	target_rotation_deg = -45.0              # Визуально резко «опускаем нос» (эффект ускорения)
	target_velocity.y = -ZOOM_CLIMB_ACCEL    # Ставим целевую скорость вверх (отрицательный Y)
	emit_signal("speed_factor_changed", 1.5) # Сообщаем наружу: скорость ощущается как 1.5x (для эффектов)
	await get_tree().create_timer(BOOST_TIME).timeout  # Ждём BOOST_TIME секунд неблокирующе (корутина)
	_end_zoom()                              # По таймеру завершаем буст

func _end_zoom() -> void:                     # Завершение «зоом-клайма»
	is_zooming = false                       # Сбрасываем флаг
	can_control = true                       # Возвращаем управление
	target_rotation_deg = 0.0                # Выравниваем нос
	target_velocity.y = 0.0                  # Сбрасываем целевую вертикаль (дальше гравитация сделает своё)
	_update_speed_factor(true)               # Форсируем обновление фактора скорости

func _start_dive() -> void:                   # Запуск режима «дайв-буст» (пикирование)
	is_diving = true                         # Ставим флаг пикирования
	can_control = false                      # Блокируем ручной ввод
	target_rotation_deg = 45.0               # Визуально задираем нос вверх (эффект падения)
	target_velocity.y = DIVE_BOOST_ACCEL     # Сильно тянем вниз по Y
	emit_signal("speed_factor_changed", 1.5) # Сигнал о повышенном факторе скорости
	await get_tree().create_timer(BOOST_TIME).timeout  # Ждём длительность буста
	_end_dive()                              # Завершаем пикирование

func _end_dive() -> void:                     # Завершение «дайв-буста»
	is_diving = false                        # Сбрасываем флаг
	can_control = true                       # Возвращаем управление
	target_rotation_deg = 0.0                # Выравниваем нос
	target_velocity.y = 0.0                  # Сбрасываем целевой Y
	_update_speed_factor(true)               # Форсируем пересчёт фактора скорости

# === Петля (loop) — без отката позиции по завершении ===
func _start_loop() -> void:                   # Подготовка к выполнению петли
	is_looping = true                        # Флаг «в режиме петли»
	can_control = false                      # Отключаем обычное управление на время петли
	loop_progress = 0.0                      # Начинаем прогресс с нуля
	loop_start_rotation = rotation           # Запоминаем текущий поворот (в радианах)
	loop_center = Vector2(position.x, position.y - LOOP_RADIUS)  # Центр окружности — над самолётом на высоту радиуса

	# Во время петли скорость физикой не управляет положением — крутим вручную
	target_velocity = Vector2(BASE_SPEED, 0.0) # Фиксируем целевую скорость по X (влияет на фактор скорости/эффекты)
	emit_signal("speed_factor_changed", 1.3)   # Немного повышаем «ощущение скорости» для эффектов

	if has_node("LoopStartParticles"):       # Если есть дочерняя нода с партиклами старта…
		$LoopStartParticles.emitting = true  # …включаем эффект
	if has_node("LoopSound"):                # Если есть звук старта петли…
		$LoopSound.play()                    # …проигрываем

func _process_loop(delta: float) -> void:     # Обновление положения/вращения во время петли
	if LOOP_TIME <= 0.0:                     # Если время петли некорректно (0/отриц.)…
		_end_loop()                          # …сразу завершаем
		return

	loop_progress += delta / LOOP_TIME       # Увеличиваем прогресс (0..1) относительно длительности
	if loop_progress >= 1.0:                 # Если круг пройден…
		_end_loop()                          # …заканчиваем петлю
		return

	# движение по окружности ПРОТИВ часовой стрелки
	var angle := loop_progress * TAU         # Угол в радианах по прогрессу (TAU = 2π)
	var x := loop_center.x + LOOP_RADIUS * sin(angle)  # X по синусу (для CCW траектории)
	var y := loop_center.y + LOOP_RADIUS * cos(angle)  # Y по косинусу
	position = Vector2(x, y)                 # Прямо выставляем позицию по окружности

	# вращение спрайта по траектории
	rotation = loop_start_rotation - angle   # Плавно вращаем корпус по направлению движения

	if abs(loop_progress - 0.5) < 0.05 and has_node("TopLoopParticles"):  # На «вершине» петли (около 50% пути)…
		$TopLoopParticles.emitting = true    # …включаем отдельный эффект

func _end_loop() -> void:                      # Завершение петли
	is_looping = false                        # Выключаем режим петли
	can_control = true                        # Возвращаем управление
	# НЕ откатываем позицию/поворот — продолжаем полёт вперёд
	target_rotation_deg = 0.0                 # Выравниваем цель по наклону
	emit_signal("speed_factor_changed", 1.0)  # Возвращаем фактор скорости к норме
	if has_node("LoopEndParticles"):          # Если есть партиклы конца петли…
		$LoopEndParticles.emitting = true     # …запускаем их

# === Сервисные ===
func _update_speed_factor(force := false) -> void:      # Отправка сигнала об «ощущаемой скорости»
	# Фактор скорости по отношению к базе (для HUD/аудио/параллакса)
	var factor := clampf(target_velocity.x / BASE_SPEED, 0.5, 3.0)  # ВНИМАНИЕ: деление на BASE_SPEED (см. заметку ниже)
	if force or abs(factor - _last_speed_factor) > 0.05:           # Если форсируем или изменение заметно…
		_last_speed_factor = factor                                 # …обновляем кэш…
		emit_signal("speed_factor_changed", factor)                  # …и шлём сигнал

# === Звук мотора ===
func _start_propeller_sound() -> void:
	"""Запускает звук мотора: сначала стартовый звук, затем зацикленный"""
	if propeller_start_sound:
		propeller_start_sound.play()
	elif propeller_loop_sound:
		# Если стартового звука нет, сразу запускаем зацикленный
		propeller_loop_sound.play()

func _on_propeller_start_finished() -> void:
	"""Вызывается когда заканчивается стартовый звук мотора - запускает зацикленный"""
	if propeller_loop_sound:
		propeller_loop_sound.play()

func _on_propeller_loop_finished() -> void:
	"""Вызывается когда заканчивается зацикленный звук мотора - перезапускает его"""
	if propeller_loop_sound and not propeller_loop_sound.stream.loop:
		# Перезапускаем только если loop не настроен в самом стриме
		propeller_loop_sound.play()

func _on_game_director_difficulty_changed(_multiplier: float, _storm_quota: int, _pickup_block_s: float) -> void:
	pass # Replace with function body. # блокировка по элементов TODO  # Заглушка под реакцию на изменение сложности игры (подстройка параметров)

# === Режим приземления ===
func start_landing(target_runway_position: Vector2 = Vector2.ZERO) -> void:
	"""Запускает режим приземления: отключает управление и включает гравитацию"""
	is_landing = true
	InGameVars.is_landing = true  # Устанавливаем глобальный флаг
	can_control = false
	is_zooming = false
	is_diving = false
	is_looping = false
	is_on_runway = false
	_was_on_runway = false
	_last_jump_time = 0.0
	_landing_stop_timer = 0.0
	_has_landed = false
	_menu_transition_started = false
	
	# Определяем целевую позицию полосы (начало полосы для посадки)
	# Коллизия полосы имеет ширину 784 пикселя, центр на X=152 относительно аэропорта
	# Начало полосы = центр - половина ширины = 152 - 392 = -240
	const RUNWAY_COLLISION_WIDTH: float = 784.0
	const RUNWAY_COLLISION_CENTER_X: float = 152.0
	const RUNWAY_START_OFFSET_X: float = RUNWAY_COLLISION_CENTER_X - (RUNWAY_COLLISION_WIDTH / 2.0)  # -240
	
	if target_runway_position != Vector2.ZERO:
		# Если передана позиция аэропорта, используем её
		_target_runway_x = target_runway_position.x + RUNWAY_START_OFFSET_X  # Начало полосы
		_target_runway_y = target_runway_position.y + 187.0  # Полоса находится на Y = airport_y + 187
		print("Начало приземления: целевая позиция полосы задана: X=", _target_runway_x, " Y=", _target_runway_y)
	else:
		# Иначе находим аэропорт самостоятельно
		_find_target_runway()
		print("Начало приземления: целевая позиция полосы найдена: X=", _target_runway_x, " Y=", _target_runway_y)
	
	# Устанавливаем безопасную высоту для полёта к полосе
	_safe_landing_altitude = _target_runway_y - landing_hold_altitude_above_runway
	
	# Отключаем столкновения с монетами и облаками, оставляем только аэропорт (слой 4 = 8)
	collision_mask = 8  # Только аэропорт, без монет и облаков
	
	# Не меняем позицию напрямую - самолёт будет плавно подниматься/опускаться под гравитацией
	# Просто включаем гравитацию - самолёт сам опустится или поднимется до безопасной высоты
	print("Начало приземления: управление отключено, безопасная высота: ", _safe_landing_altitude)

func _find_target_runway() -> void:
	"""Находит ближайший аэропорт (финишный или стартовый) для определения целевой высоты"""
	# Используем те же константы для начала полосы
	const RUNWAY_COLLISION_WIDTH: float = 784.0
	const RUNWAY_COLLISION_CENTER_X: float = 152.0
	const RUNWAY_START_OFFSET_X: float = RUNWAY_COLLISION_CENTER_X - (RUNWAY_COLLISION_WIDTH / 2.0)  # -240
	
	var scene_tree: SceneTree = get_tree()
	if not scene_tree:
		# Используем значение по умолчанию если не можем найти сцену
		_target_runway_x = 336.0 + RUNWAY_START_OFFSET_X
		_target_runway_y = 1698.0 + 187.0
		return
	
	var root: Node = scene_tree.get_root()
	if not root:
		_target_runway_x = 336.0 + RUNWAY_START_OFFSET_X
		_target_runway_y = 1698.0 + 187.0
		return
	
	# Ищем финишный аэропорт
	var finish_airport: Node2D = root.get_node_or_null("Main/FinishAirport")
	if finish_airport and finish_airport.visible:
		# Начало полосы находится на позиции аэропорта + смещение начала полосы
		_target_runway_x = finish_airport.position.x + RUNWAY_START_OFFSET_X
		_target_runway_y = finish_airport.position.y + 187.0
		print("Найден финишный аэропорт на X: ", _target_runway_x, " Y: ", _target_runway_y)
		return
	
	# Если финишный аэропорт не найден, используем стартовый
	var start_airport: Node2D = root.get_node_or_null("Main/Stat_airport")
	if start_airport:
		_target_runway_x = start_airport.position.x + RUNWAY_START_OFFSET_X
		_target_runway_y = start_airport.position.y + 187.0
		print("Найден стартовый аэропорт на X: ", _target_runway_x, " Y: ", _target_runway_y)
		return
	
	# Если ничего не найдено, используем значение по умолчанию
	_target_runway_x = 336.0 + RUNWAY_START_OFFSET_X
	_target_runway_y = 1698.0 + 187.0
	print("Аэропорт не найден, используется значение по умолчанию: X=", _target_runway_x, " Y=", _target_runway_y)

func _process_landing(delta: float) -> void:
	"""Обрабатывает физику приземления: падение под гравитацией и движение по полосе"""
	# Если уже приземлились и идёт остановка - обрабатываем остановку
	if _has_landed:
		_landing_stop_timer += delta
		
		# Плавно останавливаем самолёт
		target_velocity.x = lerpf(target_velocity.x, 0.0, delta * 2.0)
		target_velocity.y = 0.0
		velocity = velocity.lerp(target_velocity, SPEED_LERP * delta)
		
		# Выравниваем самолёт горизонтально
		target_rotation_deg = 0.0
		rotation_degrees = lerp(rotation_degrees, 0.0, ROT_LERP * delta)
		
		# Применяем движение
		move_and_slide()
		
		# Если прошло время остановки - переходим в главное меню
		if _landing_stop_timer >= LANDING_STOP_TIME and not _menu_transition_started:
			_menu_transition_started = true
			print("Таймер остановки завершён, переход в меню...")
			_go_to_main_menu()
		
		# Обновляем текущую скорость для глобальных расчётов
		InGameVars.current_speed = target_velocity.x
		_update_speed_factor()
		return
	
	# Сохраняем предыдущее состояние касания полосы (ДО проверки нового состояния)
	_was_on_runway = is_on_runway
	
	# Обновляем время последнего прыжка
	_last_jump_time += delta
	
	# Применяем движение и проверяем касание с полосой
	move_and_slide()
	
	# Проверяем касание полосы двумя способами:
	# 1. Через is_on_floor() - стандартная проверка коллизий (главный способ)
	# 2. Через проверку позиции - если самолёт находится над полосой и достаточно близко по вертикали
	var is_touching_floor: bool = is_on_floor()
	var horizontal_distance_to_runway: float = abs(_target_runway_x - position.x)
	var vertical_distance_to_runway: float = abs(position.y - _target_runway_y)
	const RUNWAY_TOUCH_HORIZONTAL: float = 400.0  # Расстояние по горизонтали для считания касания
	const RUNWAY_TOUCH_VERTICAL: float = 80.0     # Расстояние по вертикали для считания касания (увеличено)
	
	# Если is_on_floor() возвращает true - значит точно касаемся полосы (главная проверка)
	if is_touching_floor:
		is_on_runway = true
		# Отладочное сообщение когда касаемся полосы
		if not _was_on_runway:
			print("DEBUG: is_on_floor стало true! _was_on_runway=", _was_on_runway, " is_on_runway=", is_on_runway)
	else:
		# Альтернативная проверка по позиции (если коллизии не сработали)
		var is_near_runway_by_position: bool = (
			horizontal_distance_to_runway <= RUNWAY_TOUCH_HORIZONTAL and
			vertical_distance_to_runway <= RUNWAY_TOUCH_VERTICAL and
			position.y >= _target_runway_y - RUNWAY_TOUCH_VERTICAL  # Самолёт не выше полосы больше чем на RUNWAY_TOUCH_VERTICAL
		)
		is_on_runway = is_near_runway_by_position
		
		# Отладочные сообщения (только если близко к полосе и не касаемся)
		if horizontal_distance_to_runway <= RUNWAY_TOUCH_HORIZONTAL * 1.5:
			print("Проверка касания: гориз. расстояние=", horizontal_distance_to_runway, " верт. расстояние=", vertical_distance_to_runway, 
				" Y=", position.y, " Полоса Y=", _target_runway_y, " is_on_floor=", is_touching_floor, " по позиции=", is_near_runway_by_position)
	
	if is_on_runway:
		# Если касаемся полосы - едем по ней горизонтально
		if not _was_on_runway:  # Проверка на первый контакт
			print("Самолёт коснулся полосы!")
			_has_landed = true
			_landing_stop_timer = 0.0
			print("Начало остановки на полосе...")
		
		# Выравниваем самолёт горизонтально
		target_rotation_deg = 0.0
		rotation_degrees = lerp(rotation_degrees, 0.0, ROT_LERP * delta)
		
		# Устанавливаем горизонтальную скорость для движения по полосе
		target_velocity.x = BASE_SPEED * 0.5  # Скорость по полосе чуть медленнее
		target_velocity.y = 0.0  # Убираем вертикальную скорость
	else:
		# Если не касаемся полосы - автоматически управляем траекторией
		_auto_landing_control(delta)
	
	# Плавно применяем скорость
	velocity = velocity.lerp(target_velocity, SPEED_LERP * delta)
	
	# Плавный поворот к целевому углу (если не на полосе)
	if not is_on_runway:
		var diff := target_rotation_deg - rotation_degrees
		if abs(diff) > 0.5:
			rotation_degrees = lerp(rotation_degrees, target_rotation_deg, ROT_LERP * delta)
		else:
			rotation_degrees = target_rotation_deg
	
	# Жёсткое ограничение позиции чтобы самолёт не улетел за границы экрана
	position.y = clamp(position.y, MAX_Y_POSITION, MIN_Y_POSITION)
	
	# Если самолёт достиг нижней границы - принудительно устанавливаем вертикальную скорость вверх
	if position.y >= MIN_Y_POSITION:
		velocity.y = min(velocity.y, JUMP_FORCE * 0.5)
		target_velocity.y = JUMP_FORCE * 0.7
	
	# Обновляем текущую скорость для глобальных расчётов
	InGameVars.current_speed = target_velocity.x
	_update_speed_factor()

func _go_to_main_menu() -> void:
	"""Добавление сцены GameOver поверх текущей сцены после приземления"""
	print("Добавление сцены финиша...")
	var game_over_scene: PackedScene = load("res://menus/GameOver/game_over.tscn")
	if game_over_scene == null:
		push_error("Не удалось загрузить сцену финиша: res://menus/GameOver/game_over.tscn")
		return
	
	var game_over_instance: Node = game_over_scene.instantiate()
	if game_over_instance == null:
		push_error("Не удалось создать экземпляр сцены финиша")
		return
	
	var scene_tree: SceneTree = get_tree()
	if scene_tree:
		var root: Node = scene_tree.get_root()
		if root:
			root.add_child(game_over_instance)
			print("Сцена финиша успешно добавлена")
		else:
			push_error("Не удалось получить корневой узел дерева сцены")
	else:
		push_error("Не удалось получить дерево сцены")

func _auto_landing_control(delta: float) -> void:
	"""Автоматически управляет траекторией приземления для достижения полосы"""
	# Сохраняем текущую горизонтальную скорость
	if target_velocity.x <= 0.0:
		target_velocity.x = BASE_SPEED * 0.3  # Минимальная скорость вперед при падении
	
	# Обновляем позицию целевой полосы (аэропорт может двигаться)
	_update_target_runway_position()
	
	# Обновляем безопасную высоту (на случай если полоса переместилась)
	_safe_landing_altitude = _target_runway_y - landing_hold_altitude_above_runway
	
	# Вычисляем расстояние до полосы
	var horizontal_distance: float = _target_runway_x - position.x
	var height_diff: float = position.y - _target_runway_y
	var vertical_velocity_current: float = velocity.y
	
	# Расстояние начала снижения (когда самолёт уже очень близко к полосе)
	const DESCENT_START_DISTANCE: float = 300.0  # Начинаем снижаться только когда осталось 300 пикселей до полосы
	
	# Пока далеко от полосы - плавно поднимаемся/опускаемся до безопасной высоты
	if horizontal_distance > DESCENT_START_DISTANCE:
		# Вычисляем разницу высоты до безопасной высоты
		var altitude_diff: float = position.y - _safe_landing_altitude
		
		if altitude_diff > 10.0:
			# Самолёт ниже безопасной высоты - поднимаем его плавно
			# Используем небольшой подъём, чтобы плавно достичь безопасной высоты
			var lift_strength: float = clampf(altitude_diff / 100.0, 0.2, 0.6)
			target_velocity.y = JUMP_FORCE * lift_strength
		elif altitude_diff < -10.0:
			# Самолёт выше безопасной высоты - опускаем его под гравитацией
			# Применяем гравитацию для плавного снижения
			target_velocity.y += GRAVITY * delta
		else:
			# На безопасной высоте - поддерживаем горизонтальный полёт
			# Гасим вертикальную скорость для горизонтального полёта
			if abs(vertical_velocity_current) > 50.0:
				target_velocity.y = lerpf(vertical_velocity_current, 0.0, delta * 2.0)
			else:
				target_velocity.y = 0.0
		
		# Наклон минимальный при горизонтальном полёте
		target_rotation_deg = clamp(velocity.y * 0.05, -MAX_TILT, MAX_TILT)
		# Дальше корректировки не нужны до входа в зону посадки
		return
	
	# Пороги для автоматических прыжков
	const JUMP_HEIGHT_THRESHOLD: float = 120.0  # Если самолёт слишком высоко над полосой, прыгаем вниз
	const CLOSE_HEIGHT_THRESHOLD: float = 80.0  # Если близко к полосе, не прыгаем агрессивно
	const CRITICAL_HEIGHT_THRESHOLD: float = 250.0  # Критическая высота - нужен экстренный прыжок
	const APPROACH_DISTANCE: float = 500.0  # Расстояние до полосы, когда начинаем активную корректировку
	const MAX_SAFE_HEIGHT_MARGIN: float = 100.0  # Запас от верхней границы для предотвращения улёта за экран
	const MIN_SAFE_HEIGHT_MARGIN: float = 100.0  # Запас от нижней границы для предотвращения улёта за экран
	const RUNWAY_WIDTH: float = 400.0  # Ширина области над полосой, где не прыгаем (в обе стороны от центра полосы)
	const RUNWAY_APPROACH_HEIGHT: float = 300.0  # Высота над полосой, когда отключаем экстренные прыжки
	
	# Если самолёт находится над полосой - не прыгаем, позволяем гравитации приземлить его естественно
	if abs(horizontal_distance) <= RUNWAY_WIDTH:
		# Находимся над полосой - только гравитация, без прыжков
		target_velocity.y += GRAVITY * delta
		target_rotation_deg = clamp(velocity.y * 0.05, -MAX_TILT, MAX_TILT)
		return
	
	# Проверяем, не улетает ли самолёт слишком низко (ниже нижней границы экрана)
	# Но только если не над полосой и не близко к полосе по высоте
	if position.y >= MIN_Y_POSITION - MIN_SAFE_HEIGHT_MARGIN:
		# Проверяем, не находимся ли мы близко к полосе по горизонтали
		# Если близко к полосе по горизонтали - отключаем экстренные прыжки, позволяем приземлиться
		if abs(horizontal_distance) <= RUNWAY_WIDTH * 1.5:
			# Близко к полосе - только гравитация, не прыгаем
			target_velocity.y += GRAVITY * delta
			return
		
		# Если далеко от полосы - делаем экстренный прыжок только если действительно критично низко
		if position.y >= MIN_Y_POSITION - 50.0:
			# Самолёт слишком близко к нижней границе или ниже - экстренный прыжок вверх
			# JUMP_FORCE уже отрицательное значение (вверх), поэтому просто умножаем
			target_velocity.y = JUMP_FORCE * 0.9  # Сильный прыжок вверх
			_last_jump_time = 0.0
			print("Экстренный прыжок: самолёт слишком низко! Y=", position.y, " MIN_Y=", MIN_Y_POSITION, " Расстояние до полосы: ", horizontal_distance)
		return
	
	# Если уже пролетели полосу - просто продолжаем движение и поддерживаем высоту
	if horizontal_distance < -200.0:
		# Уже пролетели полосу - поддерживаем высоту
		if height_diff > CRITICAL_HEIGHT_THRESHOLD or vertical_velocity_current > 200.0:
			if _last_jump_time >= LANDING_JUMP_COOLDOWN:
				target_velocity.y = JUMP_FORCE * 0.7
				_last_jump_time = 0.0
		else:
			target_velocity.y += GRAVITY * delta
		target_rotation_deg = clamp(velocity.y * 0.05, -MAX_TILT, MAX_TILT)
		return
	
	# Если ещё далеко от полосы по горизонтали - поддерживаем горизонтальный полёт
	# (этот блок не должен выполняться, так как мы уже вернулись выше, но оставляем для безопасности)
	if horizontal_distance > APPROACH_DISTANCE:
		# Поддерживаем горизонтальный полёт, не применяем гравитацию
		if abs(vertical_velocity_current) > 50.0:
			target_velocity.y = lerpf(vertical_velocity_current, 0.0, delta * 2.0)
		else:
			target_velocity.y = 0.0
		target_rotation_deg = clamp(velocity.y * 0.05, -MAX_TILT, MAX_TILT)
		return
	
	# Когда подлетаем к полосе - просто падаем под гравитацией
	# Если самолёт находится над полосой - только гравитация
	if abs(horizontal_distance) <= RUNWAY_WIDTH:
		# Находимся над полосой - только гравитация, без прыжков
		target_velocity.y += GRAVITY * delta
		target_rotation_deg = clamp(velocity.y * 0.05, -MAX_TILT, MAX_TILT)
		return
	
	# Если подлетаем к полосе - просто применяем гравитацию
	# Просто падаем под гравитацией без сложных корректировок
	target_velocity.y += GRAVITY * delta
	
	# Наклоняем нос вниз во время падения (пропорционально скорости падения)
	target_rotation_deg = clamp(velocity.y * 0.05, -MAX_TILT, MAX_TILT)

func _update_target_runway_position() -> void:
	"""Обновляет позицию целевой полосы, если аэропорт был перемещён"""
	# Используем те же константы для начала полосы
	const RUNWAY_COLLISION_WIDTH: float = 784.0
	const RUNWAY_COLLISION_CENTER_X: float = 152.0
	const RUNWAY_START_OFFSET_X: float = RUNWAY_COLLISION_CENTER_X - (RUNWAY_COLLISION_WIDTH / 2.0)  # -240
	
	var scene_tree: SceneTree = get_tree()
	if not scene_tree:
		return
	
	var root: Node = scene_tree.get_root()
	if not root:
		return
	
	# Ищем финишный аэропорт
	var finish_airport: Node2D = root.get_node_or_null("Main/FinishAirport")
	if finish_airport and finish_airport.visible:
		_target_runway_x = finish_airport.position.x + RUNWAY_START_OFFSET_X
		_target_runway_y = finish_airport.position.y + 187.0
		return
	
	# Если финишный аэропорт не найден, используем стартовый
	var start_airport: Node2D = root.get_node_or_null("Main/Stat_airport")
	if start_airport:
		_target_runway_x = start_airport.position.x + RUNWAY_START_OFFSET_X
		_target_runway_y = start_airport.position.y + 187.0
