extends CharacterBody2D

signal died

const PROJECTILE = preload("res://scenes/projectile.tscn")

@export var max_hp := 12
@export var chase_speed := 35.0
@export var dash_speed := 230.0

var hp := 0
var active := false
var player: Node2D
var state := "chase"
var state_time := 2.0
var dash_dir := Vector2.ZERO
var base_color: Color

func _ready():
	hp = max_hp

func _physics_process(delta):
	if not active:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	state_time -= delta
	match state:
		"chase":
			velocity = (player.global_position - global_position).normalized() * chase_speed
			if state_time <= 0:
				state = "telegraph"
				state_time = 0.7
				$Sprite2D.modulate = Color(1.0, 0.35, 0.3)
		"telegraph":
			velocity = Vector2.ZERO
			if state_time <= 0:
				dash_dir = (player.global_position - global_position).normalized()
				state = "dash"
				state_time = 0.45
				$Sprite2D.modulate = Color.WHITE
		"dash":
			velocity = dash_dir * dash_speed
			if state_time <= 0:
				state = "rest"
				state_time = 1.0
				if hp <= max_hp / 2:
					fire_ring()
		"rest":
			velocity = Vector2.ZERO
			if state_time <= 0:
				state = "chase"
				state_time = 2.0
	move_and_slide()
	if state == "chase" or state == "dash":
		for i in get_slide_collision_count():
			var c = get_slide_collision(i).get_collider()
			if c.is_in_group("player"):
				c.take_damage(1)

func fire_ring():
	for i in 8:
		var p = PROJECTILE.instantiate()
		p.velocity = Vector2.RIGHT.rotated(TAU * i / 8.0) * 90.0
		get_parent().get_parent().add_child(p)
		p.global_position = global_position

func take_damage(amount):
	hp -= amount
	$BarFill.size.x = 32.0 * max(hp, 0) / max_hp
	modulate.a = 0.3
	await get_tree().create_timer(0.08).timeout
	modulate.a = 1.0
	if hp <= 0:
		died.emit()
		queue_free()
