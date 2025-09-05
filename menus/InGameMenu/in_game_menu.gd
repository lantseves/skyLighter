extends CanvasLayer

@export var start_seconds: int = 10

@onready var scoreLabel = $MarginContainer/HBoxContainer/MarginContainer/Score
@onready var timer_label: Label = $MarginContainer/HBoxContainer/TimerLabel
@onready var cound_down_timer: Timer = $CountDown

func reset_timer() -> void:
	InGameVars.remaining_timer = start_seconds
	_update_timer_label()
	
func start_timer() -> void:
	reset_timer()
	cound_down_timer.start()

func _ready() -> void:
	reset_timer()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	scoreLabel.text = "Score: " + str(InGameVars.score)
	_update_timer_label()


func _on_count_down_timeout() -> void:
	InGameVars.remaining_timer  -= 1
	if InGameVars.remaining_timer  <= 0:
		InGameVars.remaining_timer  = 0
		cound_down_timer.stop()
		get_tree().change_scene_to_file("res://menus/MainMenu/main_menu.tscn")
	
func _update_timer_label() -> void:
	var minutes := InGameVars.remaining_timer / 60
	var seconds := InGameVars.remaining_timer % 60
	timer_label.text = "Timer: " + "%02d:%02d" % [minutes,seconds]
