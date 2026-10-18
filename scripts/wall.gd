extends StaticBody2D

@export var size := Vector2(16, 16)

func _ready():
	var shape := RectangleShape2D.new()
	shape.size = size
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = size / 2
	$Visual.size = size
	$Visual.position = Vector2.ZERO

func lock():
	visible = true
	$CollisionShape2D.set_deferred("disabled", false)

func unlock():
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
