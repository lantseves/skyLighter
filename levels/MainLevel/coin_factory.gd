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

@onready var player: Node2D = null

func _ready() -> void:
	coins_layer = $Coins
	rng.randomize()
	# Находим игрока для очистки монет
	call_deferred("_find_player")

func _find_player() -> void:
	# Получаем ссылку на игрока через родительский узел
	if get_parent():
		player = get_parent().get_node_or_null("Player")
	
	# Если не получилось через родителя, пробуем через дерево сцены
	if not player:
		var scene_tree: SceneTree = get_tree()
		if scene_tree:
			var root: Node = scene_tree.get_root()
			if root:
				player = root.get_node_or_null("Main/Player")
	
	# Если все еще не нашли, пробуем относительный путь
	if not player:
		player = get_node_or_null("../Player")
	
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

func _physics_process(_delta: float) -> void:
	# Проверяем видимость для оптимизации на веб-платформе
	if not visible or not is_inside_tree():
		return
	
	# Если игрок еще не найден, пытаемся найти его снова
	if not player:
		_find_player()
		return
	
	# Удаляем монеты, которые ушли за левый край экрана
	_cleanup_off_screen_coins()

# Удаляет монеты, которые ушли за левый край экрана
func _cleanup_off_screen_coins() -> void:
	if not coins_layer or not player:
		return
	
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var camera: Camera2D = viewport.get_camera_2d()
	
	# Определяем левую границу экрана (с отступом для безопасности)
	var left_boundary: float
	if camera:
		var camera_center: Vector2 = camera.get_screen_center_position()
		left_boundary = camera_center.x - viewport_size.x * 0.5 - 200.0  # Отступ 200 пикселей
	else:
		# Если камеры нет, используем позицию игрока
		left_boundary = player.global_position.x - viewport_size.x * 0.5 - 200.0
	
	# Проверяем все монеты и удаляем те, что ушли за левый край
	var coins_to_remove: Array[Node] = []
	for coin_child: Node in coins_layer.get_children():
		if coin_child is Node2D:
			var coin: Node2D = coin_child as Node2D
			if coin.global_position.x < left_boundary:
				coins_to_remove.append(coin)
	
	# Удаляем монеты, которые ушли за экран
	for coin: Node in coins_to_remove:
		coin.queue_free()
