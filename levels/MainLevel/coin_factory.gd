extends Node2D

@export var coin_silver_scene: PackedScene          # Сюда перетащи сцену облака (*.tscn)
@export var coin_gold_scene: PackedScene          # Сюда перетащи сцену облака (*.tscn)
@export var coin_platinum_scene: PackedScene          # Сюда перетащи сцену облака (*.tscn)
@export var spawn_interval: float = 2      # Каждые 15 сек
@export var min_y: float = -200.0             # Нижняя граница высоты
@export var max_y: float = 200.0              # Верхняя граница высоты
@export var spawn_x: float = 1200.0           # Координата X появления (правее экрана)
@export var randomize_x_offset: float = 50  # Разброс по X (опционально)
@export var spawn_on_ready: bool = true       # Заcпавнить сразу одно облако при старте
@onready var spawner: Node2D = $Spawner
@onready var coin_container: Node2D = $Coins

var _rng := RandomNumberGenerator.new()

func _process(delta: float) -> void:
	spawner.position += Vector2.RIGHT * 400 * delta

func _ready():
	_rng.randomize()
	# Таймер внутрь фабрики
	var t := Timer.new()
	t.wait_time = spawn_interval
	t.one_shot = false
	t.autostart = true
	add_child(t)
	t.timeout.connect(_on_timeout)
	if spawn_on_ready:
		_on_timeout()

func _on_timeout():
	_spawn_coin(coin_silver_scene)
	_spawn_coin(coin_gold_scene)
	_spawn_coin(coin_platinum_scene)
	
func _spawn_coin(coin_scene: PackedScene) -> void:
	var coin := coin_scene.instantiate()
	var y := _rng.randf_range(min_y, max_y)
	var spawner_x := spawner.position.x
	var x := spawn_x + _rng.randf_range(-randomize_x_offset, randomize_x_offset) + spawner_x
	coin.position = Vector2(x, y)
	coin_container.add_child(coin)
