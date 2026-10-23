extends "res://scripts/mob.gd"
## Кокэси на стене. Если игрок смотрит на неё слишком долго (идёт в её сторону на расстоянии),
## она сначала поворачивается лицом, потом оживает и скачет к нему. Одного удара хватает.
## stare_only: «аномалия» — куклы только поворачиваются лицом, когда игрок подходит.

const SLEEP_TEX := "res://art/props/kokeshi.png"
const BACK_TEX := "res://art/props/kokeshi_back.png"
const TURN_TEX := "res://art/props/kokeshi_turn.png"
const AWAKE_TEX := "res://art/props/kokeshi_awake.png"
const SEE_DIST := 130.0
const STARE_DIST := 150.0

var stare_only := false
var state := "asleep"       # asleep / turned / awake
var gaze := 0.0
var hop_t := 0.0
var tex_turn: Texture2D
var tex_awake: Texture2D


func _ready() -> void:
	hp = 1
	speed = 62.0
	death_color = Color(0.8, 0.2, 0.2)
	setup_body(BACK_TEX if stare_only else SLEEP_TEX, Vector2(8, 10), Vector2(0, 2))
	tex_turn = load(TURN_TEX)
	tex_awake = load(AWAKE_TEX)
	_set_asleep(true)


# Спящая кукла не мешает ходить и не получает урон
func _set_asleep(v: bool) -> void:
	collision_layer = 0 if v else 1
	collision_mask = 0 if v else 1


func _physics_process(delta: float) -> void:
	if not find_player():
		return
	var to := player.global_position - global_position
	match state:
		"asleep":
			if stare_only:
				if to.length() < STARE_DIST:
					state = "turned"
					sprite.texture = tex_turn
					Sfx.play("creak", -12.0, 1.4)
				return
			var looking := false
			if to.length() < SEE_DIST:
				var facing = player.get("facing")
				if facing != null and (-to.normalized()).dot(facing) > 0.75:
					looking = true
			if looking:
				gaze += delta
			else:
				gaze = maxf(0.0, gaze - delta * 0.6)
			sprite.position.x = randf_range(-0.6, 0.6) if gaze > 1.2 else 0.0
			if gaze > 2.0 and sprite.texture != tex_turn:
				sprite.texture = tex_turn
				Sfx.play("creak", -12.0, 1.4)
			if gaze >= 3.0:
				_awaken()
		"awake":
			hop_t += delta
			var rhythm := 1.0 if int(hop_t * 5.0) % 2 == 0 else 0.25
			velocity = _chase_dir(player.global_position) * speed * rhythm
			sprite.position.y = -absf(sin(hop_t * 10.0)) * 4.0
			move_and_slide()
			touch_damage()
			_check_stuck(delta)


func _awaken() -> void:
	state = "awake"
	sprite.position.x = 0.0
	sprite.texture = tex_awake
	_set_asleep(false)
	Sfx.play("clack", -4.0)
	Fx.burst(global_position, Color(0.55, 0.1, 0.12), 8)


func _on_died() -> void:
	Meta.add_souls(1)
