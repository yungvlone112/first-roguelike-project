extends "res://scripts/mob.gd"
## Тэкэ-тэкэ: ползёт на руках, оставляя за собой кровавый след. Раз в пару секунд
## скрежещет и рывком бросается по прямой туда, где стоял игрок.

const FRAME_A := "res://art/tekeke_a.png"
const FRAME_B := "res://art/tekeke_b.png"
const TRAIL := "res://art/fx_trail.png"
const MAX_TRAIL := 60

var state := "crawl"
var state_time := 2.0
var lunge_dir := Vector2.ZERO
var anim := 0.0
var trail_timer := 0.0
var tex_a: Texture2D
var tex_b: Texture2D
var trail_tex: Texture2D


func _ready() -> void:
	hp = 2
	speed = 32.0
	death_color = Color(0.7, 0.1, 0.15)
	setup_body(FRAME_A, Vector2(24, 12), Vector2(0, 6))
	tex_a = sprite.texture
	tex_b = load(FRAME_B)
	trail_tex = load(TRAIL)


func _physics_process(delta: float) -> void:
	if not active or not find_player():
		return
	state_time -= delta
	anim += delta * (14.0 if state == "lunge" else 5.0)
	sprite.texture = tex_a if int(anim) % 2 == 0 else tex_b
	var to := player.global_position - global_position
	if absf(to.x) > 2.0 and state != "lunge":
		sprite.flip_h = to.x < 0.0      # спрайт нарисован лицом вправо
	match state:
		"crawl":
			velocity = _chase_dir(player.global_position) * speed
			if state_time <= 0.0:
				state = "telegraph"
				state_time = 0.45
				Sfx.play("scrape", -5.0)
		"telegraph":
			velocity = Vector2.ZERO
			sprite.position.x = randf_range(-1.5, 1.5)
			if state_time <= 0.0:
				sprite.position.x = 0.0
				lunge_dir = to.normalized()
				state = "lunge"
				state_time = 0.38
		"lunge":
			velocity = lunge_dir * 215.0
			if state_time <= 0.0:
				state = "rest"
				state_time = 0.6
		"rest":
			velocity = Vector2.ZERO
			if state_time <= 0.0:
				state = "crawl"
				state_time = randf_range(1.6, 2.6)
	move_and_slide()
	touch_damage()
	if state == "crawl":
		_check_stuck(delta)
	_drop_trail(delta)


func _drop_trail(delta: float) -> void:
	trail_timer -= delta
	if trail_timer > 0.0 or velocity.length() < 5.0:
		return
	trail_timer = 0.14
	var room = get_parent().get_parent()
	if room == null or room.get_child_count() > 400:
		return
	var s := Sprite2D.new()
	s.texture = trail_tex
	s.z_index = -1
	room.add_child(s)
	s.global_position = global_position + Vector2(0, 10)
	s.rotation = velocity.angle()
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 8.0)
	tw.tween_callback(s.queue_free)
