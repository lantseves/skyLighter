extends CanvasLayer

var score_label: Label = null
var game_over_label: Label = null
var main_menu_button: Button = null
var play_again_button: Button = null

func _ready() -> void:
	# Инициализируем узлы с проверкой, как в других местах кода
	score_label = get_node_or_null("Control/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ScoreLabel")
	game_over_label = get_node_or_null("Control/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/GameOverLabel")
	main_menu_button = get_node_or_null("Control/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ButtonsContainer/MainMenuButton")
	play_again_button = get_node_or_null("Control/CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ButtonsContainer/PlayAgainButton")
	
	# Проверяем, что все узлы найдены
	if not score_label:
		push_error("ScoreLabel не найден в GameOver сцене")
		return
	if not game_over_label:
		push_error("GameOverLabel не найден в GameOver сцене")
		return
	if not main_menu_button:
		push_error("MainMenuButton не найден в GameOver сцене")
		return
	if not play_again_button:
		push_error("PlayAgainButton не найден в GameOver сцене")
		return
	
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
