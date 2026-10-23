extends "res://scripts/mob.gd"
## Рокурокуби: держится на расстоянии, раскачивает голову, а потом вытягивает шею
## по прямой в сторону игрока и втягивает обратно. Бить надо по телу.

const MAX_REACH := 150.0
const NECK_COLOR := Color(0.78, 0.7, 0.68)

var state := "keep"
var state_time := 1.8
var head: Area2D
var head_sprite: Sprite2D
var neck: Line2D
var head_rest := Vector2(0, -22)
var tex_full: Texture2D
var tex_headless: Texture2D


func _ready() -> void:
	hp = 3
	speed = 34.0
	death_color = Color(0.7, 0.55, 0.75)
	setup_body("res://art/rokurokubi.png", Vector2(16, 44), Vector2(0, 5))
	tex_full = sprite.texture
	tex_headless = load("res://art/rokurokubi_nohead.png")
	neck = Line2D.new()
	neck.width = 3.0
	neck.default_color = NECK_COLOR
	neck.visible = false
	add_child(neck)
	head = Area2D.new()
	head.monitoring = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 6.0
	cs.shape = sh
	head.add_child(cs)
	head_sprite = Sprite2D.new()
	head_sprite.texture = load("res://art/rokurokubi_head.png")
	head.add_child(head_sprite)
	head.visible = false
	head.position = head_rest
	add_child(head)
	head.body_entered.connect(_on_head_body)


func _process(_delta: float) -> void:
	if head.visible:
		neck.points = PackedVector2Array([Vector2(0, -18), head.position])


func _physics_process(delta: float) -> void:
	if not active or not find_player():
		return
	state_time -= delta
	var to := player.global_position - global_position
	var dist := to.length()
	if absf(to.x) > 3.0 and state == "keep":
		sprite.flip_h = to.x < 0.0
	match state:
		"keep":
			var dir := Vector2.ZERO
			if dist > 170.0:
				dir = _chase_dir(player.global_position)
			elif dist < 110.0:
				dir = -to.normalized()
			velocity = dir * speed
			move_and_slide()
			_check_stuck(delta)
			if state_time <= 0.0 and dist < 210.0:
				_begin_telegraph()
		"telegraph":
			velocity = Vector2.ZERO
			move_and_slide()
			var t := Time.get_ticks_msec() / 70.0
			head.position = head_rest + Vector2(sin(t) * 2.5, -3.0 + cos(t * 0.7) * 1.5)
			if state_time <= 0.0:
				_begin_stretch()
		_:
			velocity = Vector2.ZERO
			move_and_slide()


func _begin_telegraph() -> void:
	state = "telegraph"
	state_time = 0.65
	sprite.texture = tex_headless
	head.position = head_rest
	head.rotation = 0.0
	head.visible = true
	neck.visible = true
	Sfx.play("creak", -9.0)


func _begin_stretch() -> void:
	state = "stretch"
	var from := global_position + head_rest
	var dir := (player.global_position - from).normalized()
	var length := minf(player.global_position.distance_to(from) + 24.0, MAX_REACH)
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * length, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] is StaticBody2D:
		length = maxf(8.0, from.distance_to(hit["position"]) - 6.0)
	head.rotation = dir.angle() + PI / 2.0
	head.set_deferred("monitoring", true)
	Sfx.play("creak", -4.0, 1.3)
	var tw := create_tween()
	tw.tween_property(head, "position", head_rest + dir * length, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(head, "position", head_rest, 0.3)
	tw.tween_callback(_end_stretch)


func _end_stretch() -> void:
	head.visible = false
	neck.visible = false
	head.set_deferred("monitoring", false)
	sprite.texture = tex_full
	state = "keep"
	state_time = randf_range(2.2, 3.2)


func _on_head_body(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(1)
