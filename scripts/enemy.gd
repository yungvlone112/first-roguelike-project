extends CharacterBody2D

signal died

@export var speed := 40.0
var hp := 3
var active := false
var dead := false
var announced := false
var stuck_time := 0.0
var player: Node2D

func _physics_process(delta):
	if not active:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	velocity = _chase_dir(player.global_position) * speed
	move_and_slide()
	for i in get_slide_collision_count():
		var c = get_slide_collision(i).get_collider()
		if c.is_in_group("player"):
			c.take_damage(1)
	_check_stuck(delta)

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

# Если враг долго «идёт», но не двигается (угол, стена), комната переставляет его
func _check_stuck(delta: float) -> void:
	var far := global_position.distance_to(player.global_position) > 28.0
	if far and velocity.length() > 1.0 and get_real_velocity().length() < speed * 0.15:
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
