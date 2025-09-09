extends ParallaxBackground

# Скорость движения фона
@export var scroll_speed: int = 100  # Медленная скорость для фона меню
@export var design_size := Vector2(1920, 1080)

enum ScaleMode { FIT_HEIGHT, FIT_WIDTH, COVER, CONTAIN }
@export var mode: ScaleMode = ScaleMode.FIT_HEIGHT

@export var overscan := 1.0  # 1.03–1.08 при необходимост

func _process(delta):
	# Плавное движение влево
	scroll_offset.x -= scroll_speed * delta
	#_apply_scale()
	#get_viewport().size_changed.connect(_apply_scale)

#func _apply_scale() -> void:
	#var vp := get_viewport().get_visible_rect().size
	#if design_size.x <= 0.0 or design_size.y <= 0.0:
		#return
#
	#var sx := vp.x / design_size.x
	#var sy := vp.y / design_size.y
	#var s := 1.0
#
	#match mode:
		#ScaleMode.FIT_HEIGHT: s = sy
		#ScaleMode.FIT_WIDTH:  s = sx
		#ScaleMode.COVER:      s = max(sx, sy) # закрыть весь экран
		#ScaleMode.CONTAIN:    s = min(sx, sy) # целиком влезть, могут быть поля
#
	#s *= overscan
	#scale = Vector2(s, s)
