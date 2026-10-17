extends CharacterBody2D

@export var speed := 90.0
@export var attack_damage := 1
@export var attack_time := 0.15
@export var attack_cooldown := 0.35

var facing := Vector2.RIGHT
var can_attack := true

@onready var hitbox: Area2D = $HitBox
@onready var slash: ColorRect = $HitBox/Slash

func _ready():
	hitbox.monitoring = false
	slash.visible = false
	hitbox.body_entered.connect(_on_hit)

func _physics_process(_delta):
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		facing = dir.normalized()
	velocity = dir * speed
	move_and_slide()
	if Input.is_action_just_pressed("attack") and can_attack:
		attack()

func attack():
	can_attack = false
	hitbox.position = facing * 14
	hitbox.rotation = facing.angle()
	hitbox.set_deferred("monitoring", true)
	slash.visible = true
	await get_tree().create_timer(attack_time).timeout
	hitbox.set_deferred("monitoring", false)
	slash.visible = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _on_hit(body):
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)
