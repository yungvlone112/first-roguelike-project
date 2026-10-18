extends CharacterBody2D

signal died

const PROJECTILE = preload("res://scenes/projectile.tscn")

@export var speed := 35.0
@export var shoot_interval := 2.0
@export var telegraph := 0.5
@export var bullet_speed := 110.0

var hp := 2
var active := false
var player: Node2D
var timer := 1.0
var shooting := false

func _physics_process(delta):
	if not active:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := Vector2.ZERO
	if dist > 150:
		dir = to_player.normalized()
	elif dist < 90:
		dir = -to_player.normalized()
	velocity = Vector2.ZERO if shooting else dir * speed
	move_and_slide()
	timer -= delta
	if timer <= 0 and not shooting:
		shoot()

func shoot():
	shooting = true
	$Sprite2D.modulate = Color(2.5, 2.5, 2.5)
	await get_tree().create_timer(telegraph).timeout
	$Sprite2D.modulate = Color.WHITE
	var p = PROJECTILE.instantiate()
	p.velocity = (player.global_position - global_position).normalized() * bullet_speed
	get_parent().get_parent().add_child(p)
	p.global_position = global_position
	timer = shoot_interval
	shooting = false

func take_damage(amount):
	Sfx.play("hit")
	hp -= amount
	modulate.a = 0.3
	await get_tree().create_timer(0.08).timeout
	modulate.a = 1.0
	if hp <= 0:
		died.emit()
		queue_free()
