extends Control

func _on_arcade_button_pressed() -> void:
	# Запускаем музыку при первом клике пользователя
	# Это необходимо для работы в браузерах, которые блокируют автозапуск аудио
	MusicManager.start_music()
	
	InGameVars.score = 0
	InGameVars.is_landing = false  # Сбрасываем флаг режима посадки
	get_tree().change_scene_to_file("res://levels/MainLevel/main.tscn")
