extends PointLight2D

@export var light_radius := 110.0
@export var tint := Color(1.0, 0.85, 0.6)

static var _shared_tex: ImageTexture

var t := 0.0
# 0..1: чем ближе враг, тем сильнее дрожит и сжимается свет (ставит main.gd у света игрока)
var tension := 0.0
var _applied_tension := -1.0

func _ready():
	if _shared_tex == null:
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := Vector2(size / 2.0, size / 2.0)
		for y in size:
			for x in size:
				var d := Vector2(x, y).distance_to(c) / (size / 2.0)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_shared_tex = ImageTexture.create_from_image(img)
	texture = _shared_tex
	texture_scale = light_radius / 64.0
	color = tint
	t = randf() * 10.0   # чтобы свечи и фонари мерцали не синхронно

func _process(delta):
	t += delta
	var flick := 0.06 * sin(t * 9.0) + 0.04 * sin(t * 23.0)
	energy = 1.0 + flick * (1.0 + 5.0 * tension) - 0.25 * tension
	if tension != _applied_tension:
		_applied_tension = tension
		texture_scale = light_radius / 64.0 * (1.0 - 0.3 * tension)
		color = tint.lerp(Color(1.0, 0.45, 0.4), tension * 0.6)
