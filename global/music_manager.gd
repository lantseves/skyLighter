extends Node

# Менеджер фоновой музыки для всей игры
# Воспроизводит музыку непрерывно с момента запуска

var music_player: AudioStreamPlayer = null
var music_started: bool = false

func _ready() -> void:
	# Получаем AudioStreamPlayer из сцены через get_node для надежности в браузере
	music_player = get_node_or_null("MusicPlayer") as AudioStreamPlayer
	
	# Проверяем наличие AudioStreamPlayer из сцены
	if not music_player:
		push_error("AudioStreamPlayer не найден в сцене MusicManager")
		return
	
	# Подключаем сигнал окончания трека для перезапуска
	if not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)
	
	# Проверяем наличие stream
	if music_player.stream:
		# Настраиваем зацикливание (должно быть уже настроено в сцене, но на всякий случай)
		if music_player.stream is AudioStreamOggVorbis:
			var ogg_stream: AudioStreamOggVorbis = music_player.stream as AudioStreamOggVorbis
			ogg_stream.loop = true
		
		# НЕ запускаем музыку автоматически - браузеры блокируют автозапуск
		# Музыка будет запущена после первого пользовательского взаимодействия
		print("Музыка загружена, ожидание пользовательского взаимодействия")
	else:
		push_error("AudioStream не настроен в MusicPlayer")

func start_music() -> void:
	# Запускаем музыку после первого пользовательского взаимодействия
	# Это необходимо для работы в браузерах, которые блокируют автозапуск аудио
	if not music_started and music_player and music_player.stream:
		music_player.play()
		music_started = true
		print("Фоновая музыка запущена")

func _on_music_finished() -> void:
	# Если музыка закончилась (на случай, если зацикливание не сработало)
	# Перезапускаем её
	if music_player and not music_player.playing:
		music_player.play()

func _exit_tree() -> void:
	# Останавливаем музыку при выходе
	if music_player and music_player.playing:
		music_player.stop()

