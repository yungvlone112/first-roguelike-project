extends CharacterBody2D

@export var speed := 90.0
@export var attack_damage := 1
@export var attack_time := 0.15
@export var attack_cooldown := 0.35
@export var max_hp := 5
@export var iframes := 1.0

var dead := false
var hp := 0
var facing := Vector2.RIGHT
var can_attack := true
var invincible := false

@onready var hitbox: Area2D = $HitBox
@onready var slash: ColorRect = $HitBox/Slash
@onready var hp_label: Label = $HUD/HPLabel

func _ready():
	add_to_group("player")
	hp = max_hp
	update_hp()
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
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)

func update_hp():
	hp_label.text = "HP: %d" % hp

func take_damage(amount):
	if invincible or dead:
		return
	hp -= amount
	update_hp()
	if hp <= 0:
		dead = true
		get_tree().call_deferred("reload_current_scene")
		return
	invincible = true
	modulate.a = 0.4
	await get_tree().create_timer(iframes).timeout
	modulate.a = 1.0
	invincible = false
