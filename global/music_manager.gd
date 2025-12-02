extends Node

# Менеджер фоновой музыки для всей игры
# Воспроизводит музыку непрерывно с момента запуска

var music_player: AudioStreamPlayer = null

const MUSIC_PATH: String = "res://sound/main_music.ogg"

func _ready() -> void:
	# Создаём AudioStreamPlayer для музыки
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Устанавливаем громкость музыки на 20% тише (-2 dB)
	music_player.volume_db = -2.0
	
	# Подключаем сигнал окончания трека для перезапуска
	music_player.finished.connect(_on_music_finished)
	
	# Загружаем музыку
	var music_stream: AudioStream = load(MUSIC_PATH)
	if music_stream:
		music_player.stream = music_stream
		# Настраиваем зацикливание
		if music_stream is AudioStreamOggVorbis:
			var ogg_stream: AudioStreamOggVorbis = music_stream as AudioStreamOggVorbis
			ogg_stream.loop = true
		
		# Запускаем воспроизведение
		music_player.play()
		print("Фоновая музыка запущена")
	else:
		push_error("Не удалось загрузить музыку: " + MUSIC_PATH)

func _on_music_finished() -> void:
	# Если музыка закончилась (на случай, если зацикливание не сработало)
	# Перезапускаем её
	if music_player and not music_player.playing:
		music_player.play()

func _exit_tree() -> void:
	# Останавливаем музыку при выходе
	if music_player and music_player.playing:
		music_player.stop()

