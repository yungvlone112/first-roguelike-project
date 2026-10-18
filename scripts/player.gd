extends CharacterBody2D

const SHURIKEN = preload("res://scenes/shuriken.tscn")

@export var speed := 90.0
@export var attack_damage := 1
@export var attack_time := 0.15
@export var attack_cooldown := 0.35
@export var throw_cooldown := 0.5
@export var swap_cooldown := 1.5
@export var shuriken_speed := 180.0
@export var max_hp := 5
@export var iframes := 1.0

var hp := 0
var facing := Vector2.RIGHT
var can_attack := true
var swap_ready := true
var weapon := "katana"
var invincible := false
var dead := false

@onready var hitbox: Area2D = $Hitbox
@onready var slash: ColorRect = $Hitbox/Slash
@onready var hp_label: Label = $HUD/HPLabel

func _ready():
	add_to_group("player")
	max_hp += Meta.level("hp")
	attack_damage += Meta.level("dmg")
	speed += 5.0 * Meta.level("speed")
	hp = max_hp
	update_hp()
	hitbox.monitoring = false
	slash.visible = false
	hitbox.body_entered.connect(_on_hit)

func _physics_process(_delta):
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		facing = dir.normalized()
		if dir.x != 0:
			$Sprite2D.flip_h = dir.x < 0
	velocity = dir * speed
	move_and_slide()
	if Input.is_action_just_pressed("swap") and swap_ready:
		swap_weapon()
	if Input.is_action_just_pressed("attack") and can_attack:
		if weapon == "katana":
			attack()
		else:
			throw_shuriken()

func swap_weapon():
	swap_ready = false
	weapon = "shuriken" if weapon == "katana" else "katana"
	update_hp()
	await get_tree().create_timer(swap_cooldown).timeout
	swap_ready = true

func throw_shuriken():
	can_attack = false
	var s = SHURIKEN.instantiate()
	s.velocity = facing * shuriken_speed
	s.damage = attack_damage
	s.position = position
	get_parent().add_child.call_deferred(s)
	await get_tree().create_timer(throw_cooldown).timeout
	can_attack = true

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
	var w = "Катана" if weapon == "katana" else "Сюрикены"
	hp_label.text = "HP: %d/%d   Урон: %d   Оружие: %s" % [hp, max_hp, attack_damage, w]

func apply_item(kind):
	match kind:
		"heal":
			hp = min(hp + 2, max_hp)
		"damage":
			attack_damage += 1
		"speed":
			speed += 15.0
		"maxhp":
			max_hp += 1
			hp += 1
	update_hp()

func take_damage(amount):
	if invincible or dead:
		return
	hp -= amount
	update_hp()
	if hp <= 0:
		dead = true
		get_tree().call_deferred("change_scene_to_file", "res://scenes/shop.tscn")
		return
	invincible = true
	modulate.a = 0.4
	await get_tree().create_timer(iframes).timeout
	modulate.a = 1.0
	invincible = false
