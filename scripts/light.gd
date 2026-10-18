extends PointLight2D

@export var light_radius := 110.0

var t := 0.0

func _ready():
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / (size / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	texture = ImageTexture.create_from_image(img)
	texture_scale = light_radius / 64.0
	color = Color(1.0, 0.85, 0.6)

func _process(delta):
	t += delta
	energy = 1.0 + 0.06 * sin(t * 9.0) + 0.04 * sin(t * 23.0)
