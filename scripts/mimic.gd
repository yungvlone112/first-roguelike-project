extends "res://scripts/mob.gd"
## Мимик: сундук, который оказался с зубами. Присев, прыгает на игрока (в прыжке бьёт сильнее),
## потом на миг замирает, и тут его можно бить.

const OPEN_TEX := "res://art/props/mimic_open.png"
const SNAP_TEX := "res://art/props/mimic_snap.png"

var state := "wake"
var state_time := 0.7
var hop_dir := Vector2.ZERO
var tex_open: Texture2D
var tex_snap: Texture2D


func _ready() -> void:
	hp = 6
	speed = 150.0
	death_color = Color(0.55, 0.35, 0.2)
	setup_body(OPEN_TEX, Vector2(24, 14), Vector2(0, 5))
	tex_open = sprite.texture
	tex_snap = load(SNAP_TEX)
	active = true
	Sfx.play("snap", -3.0)


func _physics_process(delta: float) -> void:
	if not active or not find_player():
		return
	state_time -= delta
	match state:
		"wake":
			velocity = Vector2.ZERO
			sprite.position.x = randf_range(-1.0, 1.0)
			if state_time <= 0.0:
				sprite.position.x = 0.0
				_squat()
		"squat":
			velocity = Vector2.ZERO
			if state_time <= 0.0:
				hop_dir = (player.global_position - global_position).normalized()
				state = "hop"
				state_time = 0.4
				contact_damage = 2
				sprite.scale = Vector2.ONE
				sprite.texture = tex_open
				Sfx.play("clack", -8.0)
		"hop":
			velocity = hop_dir * speed
			sprite.position.y = -sin((1.0 - state_time / 0.4) * PI) * 14.0
			if state_time <= 0.0:
				state = "land"
				state_time = 0.7
				contact_damage = 1
				sprite.position.y = 0.0
				sprite.texture = tex_snap
				Sfx.play("snap", -8.0)
		"land":
			velocity = Vector2.ZERO
			if state_time <= 0.0:
				_squat()
	move_and_slide()
	touch_damage()


func _squat() -> void:
	state = "squat"
	state_time = 0.35
	sprite.texture = tex_open
	sprite.scale = Vector2(1.15, 0.82)
