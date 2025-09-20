extends Node2D

# --- СЦЕНЫ ОБЛАКОВ ---
@export var cloud_bonus_scene: PackedScene
@export var cloud_penalty_scene: PackedScene
@export var cloud_empty_scene: PackedScene

# --- ГЕОМЕТРИЯ/СПАВН ---
@export var window_margin: float = 350.0
@onready var spawn_x: float = get_viewport().get_visible_rect().size.x + 300         # базовый X спавна (прибавится к позиции игрока)
@export var spawn_on_ready: bool = true
@onready var player: Node2D = $"../Player"          # двигающийся «маяк» спавна
@onready var cloud_container: Node2D = $Clouds
@onready var coin_factory: Node2D = $"../CoinFactory"

@onready var min_y: float = window_margin
@onready var max_y: float = get_viewport().get_visible_rect().size.y - window_margin

# --- СКОРОСТЬ/СЛОЖНОСТЬ ---
@export var base_speed: float = 300.0                # V
@export var difficulty_level: float = 0.0            # L
@export var k_speed: float = 0.03                    # current_speed = V * (1 + 0.03 * L)
@export var k_spacing: float = 0.03                  # (1 - 0.03 * L)
@export var min_px_floor: float = 32.0               # нижняя граница интервала (страховка)

# --- ВНУТРЕННЕЕ ---
var _rng := RandomNumberGenerator.new()

#смещение для penalty cloud
@export var penalty_spawn_offset: float = 50.0     
#смещение для bonus cloud
@export var bonus_spawn_offset: float = 200.0 

# на сколько ещё нужно пройти вперёд до спавна следующего облака
var _next_distance_px: float = 0.0
# накопленный прогресс движения вперёд
var _progress_px: float = 0.0
# самый правый достигнутый X спавнера (игнорируем движение назад)
var _last_progress_x: float = 0.0

func _ready() -> void:
	_rng.randomize()
	_last_progress_x = player.global_position.x
	_schedule_next()

	if spawn_on_ready:
		_spawn_one()  # мгновенный первый спавн по желанию

func _process(delta: float) -> void:

	# считаем только продвижение вперёд (вправо)
	var x := player.global_position.x
	if x > _last_progress_x:
		_progress_px += (x - _last_progress_x)
		_last_progress_x = x

		# Если прошли далеко одним рывком — можем заспавнить несколько раз подряд
		while _progress_px >= _next_distance_px and _next_distance_px > 0.0:
			_progress_px -= _next_distance_px
			_spawn_one()
			_schedule_next()

# ----------------------
# ЛОГИКА РАСЧЁТА ИНТЕРВАЛА
# ----------------------
func _schedule_next() -> void:
	var base_min: float = 0.6 * InGameVars.current_speed
	var base_max: float = 1.0 * InGameVars.current_speed

	# factor в [0..1]
	var factor: float = clampf(1.0 - k_spacing * difficulty_level, 0.0, 1.0)

	var interval_min: float = max(min_px_floor, base_min * factor)
	var interval_max: float = max(interval_min,  base_max * factor)

	_next_distance_px = _rng.randf_range(interval_min, interval_max)

# ----------------------
# СПАВН ОДНОГО ОБЛАКА
# ----------------------
func _spawn_one() -> void:
	var kind := _pick_cloud_type_norm()
	var scene: PackedScene
	match kind:
		Enums.CloudType.PENALTY:
			scene = cloud_penalty_scene
		Enums.CloudType.BONUS:
			scene = cloud_bonus_scene
		Enums.CloudType.EMPTY:
			scene = cloud_empty_scene
		_:
			scene = cloud_empty_scene

	var cloud := scene.instantiate() as Node2D
	var y := _calculeta_position_y(kind)
	var x := spawn_x + player.global_position.x

	cloud.position = Vector2(x, y)
	cloud_container.add_child(cloud)
	coin_factory.spawn_for_cloud(cloud, kind)

func _calculeta_position_y(cloudType: Enums.CloudType) -> float:
	match cloudType:
		Enums.CloudType.PENALTY:
			return _calculate_position_y(penalty_spawn_offset)
		Enums.CloudType.BONUS:
			return _calculate_position_y(bonus_spawn_offset)
		_: 
			return _rng.randf_range(min_y, max_y)
	
func _calculate_position_y(offset: float) -> float:
	var position_min: float = max(min_y, player.get_player_y() - offset)
	var position_max: float = min(max_y, player.get_player_y() + offset)
	return _rng.randf_range(position_min, position_min)
# ----------------------
# ВЫБОР ТИПА ОБЛАКА (нормализовано до 100)
# ----------------------
func _pick_cloud_type_norm() -> Enums.CloudType:
	var w_empty   := 55.0 - 0.5 * InGameVars.difficulty_level
	var w_bonus   := 30.0 - 1.0 * InGameVars.difficulty_level
	var w_penalty := 15.0 + 1.5 * InGameVars.difficulty_level

	w_empty   = max(w_empty, 0.0)
	w_bonus   = max(w_bonus, 0.0)
	w_penalty = max(w_penalty, 0.0)

	var total := w_empty + w_bonus + w_penalty
	if total <= 0.0:
		w_empty = 100.0; w_bonus = 0.0; w_penalty = 0.0
	else:
		var k := 100.0 / total
		w_empty   *= k
		w_bonus   *= k
		w_penalty *= k

	var roll := _rng.randf_range(0.0, 100.0)
	if roll < w_penalty:
		return Enums.CloudType.PENALTY
	elif roll < w_penalty + w_bonus:
		return Enums.CloudType.BONUS
	else:
		return Enums.CloudType.EMPTY
