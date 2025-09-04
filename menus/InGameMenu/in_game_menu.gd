extends CanvasLayer

@export var start_seconds: int = 10

@onready var scoreLabel = $MarginContainer/HBoxContainer/MarginContainer/Score
@onready var timer_label: Label = $MarginContainer/HBoxContainer/TimerLabel
@onready var cound_down: Timer = $CountDown

signal time_up
var remaining: int 

func reset_timer() -> void:
	remaining = start_seconds
	_update_timer_label()
	
func start_timer() -> void:
	reset_timer()
	cound_down.start()

func _ready() -> void:
	reset_timer()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	scoreLabel.text = "Score: " + str(InGameVars.score)


func _on_count_down_timeout() -> void:
	remaining -= 1
	if remaining <= 0:
		remaining = 0
		_update_timer_label()
		cound_down.stop()
		get_tree().change_scene_to_file("res://menus/MainMenu/main_menu.tscn")
	_update_timer_label()
	
func _update_timer_label() -> void:
	var minutes := remaining / 60
	var seconds := remaining % 60
	timer_label.text = "Timer: " + "%02d:%02d" % [minutes,seconds]
