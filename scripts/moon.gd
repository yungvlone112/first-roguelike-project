extends PointLight2D
## Лунный свет из сёдзи: холодное пятно с решёткой на полу под окном.
## Целое сёдзи светит ровно и мягко; рваное — ярче, резче и мерцает, будто сквозняк.

@export var torn := false

var t := 0.0


func _ready() -> void:
	texture = load("res://art/tiles/moon_beam_torn.png" if torn else "res://art/tiles/moon_beam.png")
	color = Color(0.5, 0.85, 0.95) if torn else Color(0.62, 0.72, 1.0)
	energy = 1.2 if torn else 0.85
	t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta
	if torn:
		var gust := maxf(0.0, sin(t * 1.7) * sin(t * 0.63 + 1.0))
		energy = 1.1 + 0.35 * gust + 0.12 * sin(t * 13.0)
	else:
		energy = 0.85 + 0.05 * sin(t * 0.9)
