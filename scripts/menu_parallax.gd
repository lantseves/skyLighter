extends ParallaxBackground

# Скорость движения фона
var scroll_speed = 100  # Медленная скорость для фона меню

func _process(delta):
	# Плавное движение влево
	scroll_offset.x -= scroll_speed * delta
