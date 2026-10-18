extends Node

func burst(pos: Vector2, color: Color, amount := 14):
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.emitting = true
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)
