extends Node2D

@export var coin_silver_scene: PackedScene          # Сюда перетащи сцену облака (*.tscn)
@export var coin_gold_scene: PackedScene          # Сюда перетащи сцену облака (*.tscn)
@export var coin_platinum_scene: PackedScene          # Сюда перетащи сцену облака (*.tscn)

# Вероятности типов (нормализуем внутри)
@export var p_silver: float = 0.7
@export var p_gold: float = 0.25
@export var p_platinum: float = 0.05

@export var coin_radius: float = 12.0
@export var cloud_radius: float = 120.0

# +10 из схемы
@export var safe_pad_px: float = 10.0

@onready var coins_layer: Node

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	coins_layer = $Coins
	rng.randomize()
	
func spawn_for_cloud(cloud: Node2D, cloud_type: Enums.CloudType) -> void:
	if coins_layer == null:
		coins_layer = $Coins
		
	var coins_amount := _coins_count_by_kind(cloud_type)
	
	for i in coins_amount:
		var coin_scene: PackedScene = _get_coin_scene()

		var r_min := cloud_radius + coin_radius + safe_pad_px
		var r_max := 2.0 * (cloud_radius + coin_radius + safe_pad_px)

		var theta := rng.randf() * TAU
		var r := rng.randf_range(r_min, r_max)
		var pos := cloud.global_position + Vector2(cos(theta), sin(theta)) * r

		var coin := coin_scene.instantiate() as Node2D
		coin.global_position = pos
		coins_layer.add_child(coin)

# Сколько монет сделать
func _coins_count_by_kind(cloud_type: Enums.CloudType) -> int:
	var difficulty_level:= InGameVars.difficulty_level
	match cloud_type:
		Enums.CloudType.PENALTY: return 2 + int(floor(0.3 * difficulty_level))
		Enums.CloudType.BONUS:   return 1 + int(floor(0.2 * difficulty_level))
		Enums.CloudType.EMPTY:   return int(floor(0.1 * difficulty_level))
		_:                 return 0

func _get_coin_scene() -> PackedScene:
	var s := float(max(p_silver, 0.0))
	var g := float(max(p_gold, 0.0))
	var p := float(max(p_platinum, 0.0))
	var sum := s + g + p
	if sum <= 0.0:
		s = 1.0; g = 0.0; p = 0.0; sum = 1.0
	var x := rng.randf() * sum
	if x < s:           return coin_silver_scene
	elif x < s + g:     return coin_gold_scene
	else:               return coin_platinum_scene
