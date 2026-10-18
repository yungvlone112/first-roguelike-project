extends Area2D

var velocity := Vector2.ZERO
var damage := 1
var life := 4.0

func _ready():
	body_entered.connect(_on_body)

func _physics_process(delta):
	position += velocity * delta
	life -= delta
	if life <= 0:
		queue_free()

func _on_body(body):
	if body.is_in_group("player"):
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
