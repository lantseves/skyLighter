extends CharacterBody2D

signal speed_factor_changed(factor: float)

# === Параметры физики/управления ===
const GRAVITY := 900.0
const BASE_SPEED := 300.0              # базовая скорость по X
const SHIFT_SPEED_ADD := 400.0         # прибавка по X при зажатом Shift (jet_dash)
const SPEED_LERP := 5.0                # сглаживание скоростей
const ROT_LERP := 5.0                  # сглаживание поворота
const MAX_TILT := 30.0                 # максимум визуального наклона, градусы
const JUMP_FORCE := -400.0

# Бусты (короткие режимы с таймером)
const ZOOM_CLIMB_ACCEL := 600.0        # подъём (вверх)
const DIVE_BOOST_ACCEL := 500.0        # пикирование (вниз)
const BOOST_TIME := 1.5

# Петля
const LOOP_TIME := 2.5
const LOOP_RADIUS := 250.0

# Ограничения по высоте (экран/уровень)
const MAX_Y_POSITION := 100.0
const MIN_Y_POSITION := 980.0

# === Состояния ===
var is_zooming := false
var is_diving := false
var is_looping := false
var can_control := true

var target_velocity: Vector2 = Vector2(BASE_SPEED, 0.0)
var target_rotation_deg := 0.0

# Петля
var loop_progress := 0.0
var loop_center := Vector2.ZERO
var loop_start_rotation := 0.0

# Для событий скорости (чтобы не спамить сигнал)
var _last_speed_factor := 1.0

func _ready() -> void:
	rotation_degrees = 0.0

func _physics_process(delta: float) -> void:
	if is_looping:
		_process_loop(delta)
		# столкновения по траектории петли не учитываем
		move_and_collide(Vector2.ZERO)
		return

	if can_control:
		_handle_input()

	# Гравитация, если нет вертикального буста
	if not is_zooming and not is_diving:
		target_velocity.y += GRAVITY * delta

	# Плавно тянем фактическую скорость к целевой
	velocity = velocity.lerp(target_velocity, SPEED_LERP * delta)

	# Вертикальные рамки уровня
	position.y = clamp(position.y, MAX_Y_POSITION, MIN_Y_POSITION)

	# Плавный поворот к целевому углу
	var diff := target_rotation_deg - rotation_degrees
	if abs(diff) > 0.5:
		rotation_degrees = lerp(rotation_degrees, target_rotation_deg, ROT_LERP * delta)
	else:
		rotation_degrees = target_rotation_deg

	# Движение
	move_and_slide()

	# Обновим фактор скорости для HUD/аудио
	_update_speed_factor()

# === Ввод и режимы ===

func _handle_input() -> void:
	# Базовая горизонтальная скорость + Shift-ускорение (удержание jet_dash)
	var desired_x := BASE_SPEED
	if Input.is_action_pressed("jet_dash"):
		desired_x += SHIFT_SPEED_ADD
	target_velocity.x = max(desired_x, 0.0)  # не даём ехать назад кодом

	# Наклон носа от вертикальной скорости (визуальный)
	# Ограничиваем до MAX_TILT, чтобы не «ломать» спрайт
	target_rotation_deg = clamp(-velocity.y * 0.05, -MAX_TILT, MAX_TILT)

	if Input.is_action_just_pressed("jump"):
		_start_jump()

	if Input.is_action_just_pressed("zoom_climb") and not is_zooming:
		_start_zoom()

	if Input.is_action_just_pressed("dive_boost") and not is_diving:
		_start_dive()

	if Input.is_action_just_pressed("loop") and not is_looping:
		_start_loop()

func _start_jump() -> void:
	target_velocity.y = JUMP_FORCE
	target_rotation_deg = -15.0

func _start_zoom() -> void:
	is_zooming = true
	can_control = false
	target_rotation_deg = -45.0
	target_velocity.y = -ZOOM_CLIMB_ACCEL
	emit_signal("speed_factor_changed", 1.5)
	await get_tree().create_timer(BOOST_TIME).timeout
	_end_zoom()

func _end_zoom() -> void:
	is_zooming = false
	can_control = true
	target_rotation_deg = 0.0
	target_velocity.y = 0.0
	_update_speed_factor(true)

func _start_dive() -> void:
	is_diving = true
	can_control = false
	target_rotation_deg = 45.0
	target_velocity.y = DIVE_BOOST_ACCEL
	emit_signal("speed_factor_changed", 1.5)
	await get_tree().create_timer(BOOST_TIME).timeout
	_end_dive()

func _end_dive() -> void:
	is_diving = false
	can_control = true
	target_rotation_deg = 0.0
	target_velocity.y = 0.0
	_update_speed_factor(true)

# === Петля (loop) — без отката позиции по завершении ===
func _start_loop() -> void:
	is_looping = true
	can_control = false
	loop_progress = 0.0
	loop_start_rotation = rotation
	loop_center = Vector2(position.x, position.y - LOOP_RADIUS)

	# Во время петли скорость физикой не управляет положением — крутим вручную
	target_velocity = Vector2(BASE_SPEED, 0.0)
	emit_signal("speed_factor_changed", 1.3)

	if has_node("LoopStartParticles"):
		$LoopStartParticles.emitting = true
	if has_node("LoopSound"):
		$LoopSound.play()

func _process_loop(delta: float) -> void:
	if LOOP_TIME <= 0.0:
		_end_loop()
		return

	loop_progress += delta / LOOP_TIME
	if loop_progress >= 1.0:
		_end_loop()
		return

	# движение по окружности ПРОТИВ часовой стрелки
	var angle := loop_progress * TAU
	var x := loop_center.x + LOOP_RADIUS * sin(angle)
	var y := loop_center.y + LOOP_RADIUS * cos(angle)
	position = Vector2(x, y)

	# вращение спрайта по траектории
	rotation = loop_start_rotation - angle

	if abs(loop_progress - 0.5) < 0.05 and has_node("TopLoopParticles"):
		$TopLoopParticles.emitting = true

func _end_loop() -> void:
	is_looping = false
	can_control = true
	# НЕ откатываем позицию/поворот — продолжаем полёт вперёд
	target_rotation_deg = 0.0
	emit_signal("speed_factor_changed", 1.0)
	if has_node("LoopEndParticles"):
		$LoopEndParticles.emitting = true

# === Сервисные ===
func _update_speed_factor(force := false) -> void:
	# Фактор скорости по отношению к базе (для HUD/аудио/параллакса)
	var factor := clampf(target_velocity.x / BASE_SPEED, 0.5, 3.0)
	if force or abs(factor - _last_speed_factor) > 0.05:
		_last_speed_factor = factor
		emit_signal("speed_factor_changed", factor)


func _on_game_director_difficulty_changed(_multiplier: float, _storm_quota: int, _pickup_block_s: float) -> void:
	pass # Replace with function body. # блокировка по элементов TODO
