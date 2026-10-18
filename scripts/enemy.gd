extends CharacterBody2D

signal died

@export var speed := 40.0
var hp := 3
var active := false
var player: Node2D

func _physics_process(_delta):
	if not active:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	velocity = (player.global_position - global_position).normalized() * speed
	move_and_slide()
	for i in get_slide_collision_count():
		var c = get_slide_collision(i).get_collider()
		if c.is_in_group("player"):
			c.take_damage(1)

func take_damage(amount):
	hp -= amount
	modulate.a = 0.3
	await get_tree().create_timer(0.08).timeout
	modulate.a = 1.0
	if hp <= 0:
		died.emit()
		queue_free()
