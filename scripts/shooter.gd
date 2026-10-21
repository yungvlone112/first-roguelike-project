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
var dead := false
var announced := false
var stuck_time := 0.0

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
		dir = _chase_dir(player.global_position)
	elif dist < 90:
		dir = -to_player.normalized()
	velocity = Vector2.ZERO if shooting else dir * speed
	move_and_slide()
	_check_stuck(delta, dir)
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
	if dead:
		return
	Sfx.hit()
	hp -= amount
	if hp <= 0:
		dead = true
		active = false
	modulate.a = 0.3
	await get_tree().create_timer(0.08).timeout
	modulate.a = 1.0
	if dead and not announced:   # сигнал смерти отправляется ровно один раз
		announced = true
		Fx.burst(global_position, Color(0.8, 0.85, 1.0))
		died.emit()
		queue_free()

# Если стрелок долго «идёт», но не двигается, комната переставляет его
func _check_stuck(delta: float, dir: Vector2) -> void:
	if dir != Vector2.ZERO and not shooting and get_real_velocity().length() < speed * 0.15:
		stuck_time += delta
	else:
		stuck_time = 0.0
	if stuck_time > 1.5:
		stuck_time = 0.0
		var room = get_parent().get_parent()
		if room != null and room.has_method("unstick"):
			room.unstick(self)

func _chase_dir(target: Vector2) -> Vector2:
	var room = get_parent().get_parent()   # Enemies -> Room
	if room != null and room.has_method("steer"):
		return room.steer(global_position, target)
	return (target - global_position).normalized()
