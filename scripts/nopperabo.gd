extends "res://scripts/mob.gd"
## Нопэрапон (безликий). Спокойно подходит и не нападает, пока игрок не окажется близко:
## тогда на пустом лице проступают глаза и рот, он замирает на миг и бросается.

const REVEAL_DIST := 78.0
const FACE_TEX := "res://art/nopperabo_face.png"

var state := "calm"
var state_time := 0.0


func _ready() -> void:
	hp = 4
	speed = 24.0
	death_color = Color(0.9, 0.9, 0.95)
	setup_body("res://art/nopperabo.png", Vector2(16, 44), Vector2(0, 5))


func _physics_process(delta: float) -> void:
	if not active or not find_player():
		return
	var to := player.global_position - global_position
	if absf(to.x) > 3.0:
		sprite.flip_h = to.x < 0.0
	match state:
		"calm":
			velocity = _chase_dir(player.global_position) * speed
			move_and_slide()
			_check_stuck(delta)
			if to.length() < REVEAL_DIST:
				_reveal()
		"reveal":
			velocity = Vector2.ZERO
			state_time -= delta
			sprite.position.x = randf_range(-1.0, 1.0)   # дрожит
			if state_time <= 0.0:
				sprite.position.x = 0.0
				speed = 78.0
				state = "hunt"
		"hunt":
			velocity = _chase_dir(player.global_position) * speed
			move_and_slide()
			touch_damage()
			_check_stuck(delta)


func _reveal() -> void:
	state = "reveal"
	state_time = 0.55
	sprite.texture = load(FACE_TEX)
	Sfx.play("reveal", -4.0)
	if player != null and player.has_method("shake"):
		player.shake(2.5)
	Fx.burst(global_position + Vector2(0, -16), Color(0.9, 0.9, 0.95), 8)


# Ударить его до того, как он подошёл, тоже значит разбудить лицо
func _on_hurt() -> void:
	if state == "calm" and not dead:
		_reveal()
