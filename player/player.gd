extends CharacterBody2D                      # Скрипт висит на узле-персонаже с физикой (движение через velocity/move_and_slide)

signal speed_factor_changed(factor: float)   # Сигнал наружу: сообщает, во сколько раз текущая горизонтальная скорость отличается от базовой (для HUD/аудио/параллакса)

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

# Петля
const LOOP_TIME := 2.5                       # Время выполнения петли (полный круг), секунды
const LOOP_RADIUS := 250.0                   # Радиус окружности, по которой летим, когда крутим петлю

#Размер отступа от верхней и нижней границы
@export var window_margin = 200              # Экспортный параметр: отступ сверху/снизу, чтобы не выходить за видимую область

# Ограничения по высоте (экран/уровень)
var MAX_Y_POSITION := 100.0                  # Верхняя граница допустимой высоты (будет переопределена в _ready)
var MIN_Y_POSITION := 980.0                  # Нижняя граница допустимой высоты (будет переопределена в _ready)

# === Состояния ===
var is_zooming := false                      # Флаг: выполняется ли сейчас «зоом-клайм» (подъём с бустом)
var is_diving := false                       # Флаг: выполняется ли сейчас «дайв-буст» (пикирование с бустом)
var is_looping := false                      # Флаг: крутим ли сейчас петлю
var can_control := true     
var is_start_position := true                 # Можно ли сейчас принимать ввод (во время бустов/петли — false)

var target_velocity: Vector2 = Vector2(BASE_SPEED, 0.0)  # Целевая скорость, к которой мы сглаженно тянем фактическую velocity
var target_rotation_deg := 0.0                           # Целевой визуальный угол наклона (в градусах), к нему сглаженно тянемся

# Петля
var loop_progress := 0.0                     # От 0 до 1 — прогресс выполнения петли за LOOP_TIME
var loop_center := Vector2.ZERO              # Центр окружности для петли (над текущей позицией на радиус)
var loop_start_rotation := 0.0               # Запоминаем базовый поворот при старте петли, чтобы анимировать вращение

# Для событий скорости (чтобы не спамить сигнал)
var _last_speed_factor := 1.0                # Последний отправленный наружу «фактор скорости» (для отсечки мелких изменений)

func get_player_y() -> float:                # Публичный геттер: отдать текущую высоту игрока (может пригодиться другим узлам)
	return self.position.y                   # Возвращаем Y-позицию узла

func _ready() -> void:                       # Вызывается при входе узла в сцену
	rotation_degrees = 0.0                   # Сбрасываем визуальный наклон в ноль
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size  # Узнаём размер видимой области (экрана)
	MAX_Y_POSITION = window_margin           # Верхняя граница = отступ сверху
	MIN_Y_POSITION = viewport_size.y - 50 # Нижняя граница = высота экрана минус отступ снизу

func _physics_process(delta: float) -> void: # Физический кадр: безопасное место менять velocity/position
	if is_start_position:
		if Input.is_action_just_pressed("jump"):
			is_start_position = false
		return;
	InGameVars.current_speed = BASE_SPEED    # Кладём текущую «базовую» скорость в глобальную переменную (для других систем)
	if is_looping:                           # Если сейчас крутим петлю…
		_process_loop(delta)                 # …двигаем вручную по окружности
		# столкновения по траектории петли не учитываем
		move_and_collide(Vector2.ZERO)       # Нулевое перемещение, чтобы не обрабатывались стандартные слайды/коллизии
		return                               # Выходим: обычную физику в петле не считаем

	if can_control:                          # Если управление разрешено…
		_handle_input()                      # …обрабатываем ввод (скорость по X, прыжок, бусты, старт петли)

	# Гравитация, если нет вертикального буста
	if not is_zooming and not is_diving:     # Пока не активен ни подъём, ни пикирование…
		target_velocity.y += GRAVITY * delta # …тянем цель по Y вниз гравитацией

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

func _start_jump() -> void:                   # Разовый импульс вверх
	target_velocity.y = JUMP_FORCE           # Устанавливаем целевую вертикальную скорость резко вверх
	target_rotation_deg = -15.0              # Слегка наклоняем нос вниз для визуальной динамики

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

func _on_game_director_difficulty_changed(_multiplier: float, _storm_quota: int, _pickup_block_s: float) -> void:
	pass # Replace with function body. # блокировка по элементов TODO  # Заглушка под реакцию на изменение сложности игры (подстройка параметров)
