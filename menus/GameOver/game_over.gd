extends CanvasLayer

@onready var score_label: Label = $Control/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ScoreLabel
@onready var game_over_label: Label = $Control/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/GameOverLabel
@onready var main_menu_button: Button = $Control/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ButtonsContainer/MainMenuButton
@onready var play_again_button: Button = $Control/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ButtonsContainer/PlayAgainButton

func _ready() -> void:
	# Отображаем счет из глобальных переменных
	var final_score: int = InGameVars.score
	score_label.text = "Очки: " + str(final_score)
	
	# Подключаем сигналы кнопок
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	play_again_button.pressed.connect(_on_play_again_button_pressed)

func _on_main_menu_button_pressed() -> void:
	# Удаляем сцену финиша из дерева сцены
	queue_free()
	
	# Переход в главное меню
	var error_code: Error = get_tree().change_scene_to_file("res://menus/MainMenu/main_menu.tscn")
	if error_code != OK:
		push_error("Ошибка при переходе в главное меню: " + str(error_code))

func _on_play_again_button_pressed() -> void:
	# Сбрасываем счет и перезапускаем игру
	InGameVars.score = 0
	InGameVars.is_landing = false
	
	# Удаляем сцену финиша из дерева сцены
	queue_free()
	
	# Перезапускаем игровую сцену (как будто нажали кнопку играть в главном меню)
	var error_code: Error = get_tree().change_scene_to_file("res://levels/MainLevel/main.tscn")
	if error_code != OK:
		push_error("Ошибка при переходе в игру: " + str(error_code))
