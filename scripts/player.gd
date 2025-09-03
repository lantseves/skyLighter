extends CharacterBody2D

signal speed_factor_changed(factor)

# Настройки физики
const GRAVITY = 900.0
const JUMP_FORCE = -400.0
const BASE_SPEED = 300.0
const ZOOM_CLIMB_ACCEL = 600.0
const DIVE_BOOST_ACCEL = 500.0
const JET_DASH_ACCEL = 800.0
const LOOP_TIME = 2.5
const LOOP_RADIUS = 250.0
const MAX_Y_POSITION = 100.0
const MIN_Y_POSITION = 980.0
const MAX_X_POSITION = 1720.0
const CENTER_X = 960.0
const RETURN_SPEED = 120.0
const SPEED_LERP_FACTOR = 5.0
const ROTATION_SPEED = 5.0  # Скорость вращения

# Состояния
var is_zooming = false
var is_diving = false
var is_dashing = false
var is_looping = false
var can_control = true
var target_x = CENTER_X
var target_velocity = Vector2(BASE_SPEED, 0)
var target_rotation = 0.0  # Целевой угол поворота

# Переменные для петли
var loop_progress = 0.0
var loop_start_position = Vector2.ZERO
var loop_start_rotation = 0.0
var loop_center = Vector2.ZERO

func _ready():
	position = Vector2(CENTER_X, MIN_Y_POSITION - 500)
	target_rotation = 0.0
	rotation_degrees = 0.0

func _physics_process(delta):
	if is_looping:
		process_loop(delta)
		move_and_collide(Vector2.ZERO)
		return
	
	# Плавное вращение к целевому углу
	if abs(rotation_degrees - target_rotation) > 0.5:
		rotation_degrees = lerp(rotation_degrees, target_rotation, ROTATION_SPEED * delta)
	else:
		rotation_degrees = target_rotation
	
	if can_control:
		handle_input()
	
	velocity = velocity.lerp(target_velocity, SPEED_LERP_FACTOR * delta)
	
	if not is_diving and not is_zooming and not is_dashing:
		target_velocity.y += GRAVITY * delta
	
	if not is_dashing and abs(position.x - target_x) > 10.0:
		return_to_center()
	
	position.y = clamp(position.y, MAX_Y_POSITION, MIN_Y_POSITION)
	position.x = clamp(position.x, 0.0, MAX_X_POSITION)
	
	move_and_slide()

func return_to_center():
	var direction = sign(target_x - position.x)
	target_velocity.x = direction * RETURN_SPEED
	
	if abs(position.x - target_x) < 50.0:
		target_velocity.x = direction * RETURN_SPEED * 0.5
	
	if abs(position.x - target_x) < 5.0:
		target_velocity.x = 0.0
		position.x = target_x

func handle_input():
	if Input.is_action_just_pressed("jump"):
		start_jump()
	
	if Input.is_action_just_pressed("zoom_climb") and not is_zooming:
		start_zoom()
	
	if Input.is_action_just_pressed("dive_boost") and not is_diving:
		start_dive()
	
	if Input.is_action_just_pressed("jet_dash") and not is_dashing:
		start_dash()
	
	if Input.is_action_just_pressed("loop") and not is_looping and can_control:
		start_loop()

func start_jump():
	target_velocity.y = JUMP_FORCE
	target_rotation = -15.0  # Легкий подъем при прыжке

func start_zoom():
	is_zooming = true
	can_control = false
	target_rotation = -45.0  # Сильный подъем
	target_velocity.y = -ZOOM_CLIMB_ACCEL
	target_velocity.x = JET_DASH_ACCEL
	emit_signal("speed_factor_changed", 1.5)
	await get_tree().create_timer(1.5).timeout
	end_zoom()

func end_zoom():
	is_zooming = false
	can_control = true
	target_rotation = 0.0  # Возврат в горизонтальное положение
	target_x = CENTER_X
	target_velocity.y = 0
	target_velocity.x = BASE_SPEED
	emit_signal("speed_factor_changed", 1.0)

func start_dive():
	is_diving = true
	can_control = false
	target_rotation = 45.0  # Нос вниз
	target_velocity.y = DIVE_BOOST_ACCEL
	target_velocity.x = JET_DASH_ACCEL
	emit_signal("speed_factor_changed", 1.5)
	await get_tree().create_timer(1.5).timeout
	end_dive()

func end_dive():
	is_diving = false
	can_control = true
	target_rotation = 0.0  # Возврат в горизонтальное положение
	target_x = CENTER_X
	target_velocity.y = 0
	target_velocity.x = BASE_SPEED
	emit_signal("speed_factor_changed", 1.0)

func start_dash():
	is_dashing = true
	can_control = false
	target_rotation = 0.0  # Сохраняем горизонтальное положение
	target_velocity.x = JET_DASH_ACCEL
	emit_signal("speed_factor_changed", 2.0)
	await get_tree().create_timer(0.8).timeout
	end_dash()

func end_dash():
	is_dashing = false
	can_control = true
	target_rotation = 0.0
	target_x = CENTER_X
	target_velocity.x = BASE_SPEED
	emit_signal("speed_factor_changed", 1.0)

func start_loop():
	is_looping = true
	can_control = false
	loop_progress = 0.0
	
	# Сохраняем начальное состояние
	loop_start_position = position
	loop_start_rotation = rotation
	loop_center = Vector2(position.x, position.y - LOOP_RADIUS)
	
	# Фиксируем скорость
	target_velocity = Vector2(BASE_SPEED, 0)
	emit_signal("speed_factor_changed", 1.3)
	
	# Эффекты
	if has_node("LoopStartParticles"):
		$LoopStartParticles.emitting = true
	if has_node("LoopSound"):
		$LoopSound.play()

func process_loop(delta):
	if LOOP_TIME <= 0:
		end_loop()
		return
	
	loop_progress += delta / LOOP_TIME
	
	if loop_progress >= 1.0:
		end_loop()
		return
	
	# Угол для вращения ПРОТИВ часовой стрелки
	var angle = loop_progress * 2 * PI
	
	# Траектория ПРОТИВ часовой стрелки
	var x = loop_center.x + LOOP_RADIUS * sin(angle)
	var y = loop_center.y + LOOP_RADIUS * cos(angle)
	position = Vector2(x, y)
	
	# Вращение ПРОТИВ часовой стрелки
	rotation = loop_start_rotation - angle
	
	# Эффект в верхней точке
	if abs(loop_progress - 0.5) < 0.05 and has_node("TopLoopParticles"):
		$TopLoopParticles.emitting = true

func end_loop():
	is_looping = false
	can_control = true
	
	# Возвращаем в исходную позицию и вращение
	position = loop_start_position
	rotation = loop_start_rotation
	target_rotation = 0.0  # Сбрасываем целевой угол
	
	emit_signal("speed_factor_changed", 1.0)
	if has_node("LoopEndParticles"):
		$LoopEndParticles.emitting = true
