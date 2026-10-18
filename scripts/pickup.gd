extends Area2D

@export var kind := "heal"

const COLORS = {
	"heal": Color(0.3, 0.9, 0.4),
	"damage": Color(1.0, 0.6, 0.1),
	"speed": Color(0.3, 0.6, 1.0),
	"maxhp": Color(1.0, 0.4, 0.6)
}
const NAMES = {
	"heal": "Лечение",
	"damage": "+Урон",
	"speed": "+Скорость",
	"maxhp": "+Макс. HP"
}

func _ready():
	$ColorRect.color = COLORS[kind]
	$Tag.text = NAMES[kind]
	$Tag.add_theme_font_size_override("font_size", 8)
	body_entered.connect(_on_body)

func _on_body(body):
	if body.is_in_group("player"):
		body.apply_item(kind)
		queue_free()
