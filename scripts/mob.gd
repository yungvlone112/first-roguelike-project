extends CharacterBody2D
## Общая основа новых существ: HP, смерть, спрайт и коллизия, навигация к игроку.
## Контракт с комнатой тот же, что у yurei/karakasa: сигнал died, поля active и hp, метод take_damage.

signal died

var hp := 3
var speed := 40.0
var active := false
var dead := false
var announced := false
var stuck_time := 0.0
var contact_damage := 1
var death_color := Color(0.8, 0.85, 1.0)
var player: Node2D
var sprite: Sprite2D
var body_shape: CollisionShape2D


func setup_body(tex_path: String, size: Vector2, offset := Vector2(0, 5)) -> void:
	sprite = Sprite2D.new()
	sprite.texture = load(tex_path)
	add_child(sprite)
	body_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	body_shape.shape = shape
	body_shape.position = offset
	add_child(body_shape)


func find_player() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	return player != null


func touch_damage() -> void:
	for i in get_slide_collision_count():
		var c = get_slide_collision(i).get_collider()
		if c != null and c.is_in_group("player"):
			c.take_damage(contact_damage)


func take_damage(amount):
	if dead:
		return
	Sfx.hit()
	hp -= amount
	if hp <= 0:
		dead = true
		active = false
	_on_hurt()
	modulate.a = 0.3
	await get_tree().create_timer(0.08).timeout
	modulate.a = 1.0
	if dead and not announced:   # сигнал смерти отправляется ровно один раз
		announced = true
		Fx.burst(global_position, death_color)
		_on_died()
		died.emit()
		queue_free()


func _on_hurt() -> void:
	pass


func _on_died() -> void:
	pass


# Если существо долго «идёт», но не двигается (угол, стена), комната переставляет его
func _check_stuck(delta: float) -> void:
	var far := global_position.distance_to(player.global_position) > 28.0
	if far and velocity.length() > 1.0 and get_real_velocity().length() < maxf(speed, 20.0) * 0.15:
		stuck_time += delta
	else:
		stuck_time = 0.0
	if stuck_time > 1.5:
		stuck_time = 0.0
		var room = get_parent().get_parent()
		if room != null and room.has_method("unstick"):
			room.unstick(self)


func _chase_dir(target: Vector2) -> Vector2:
	var room = get_parent().get_parent()   # Enemies -> Room (у кокэси: dressing -> Room)
	if room != null and room.has_method("steer"):
		return room.steer(global_position, target)
	return (target - global_position).normalized()
