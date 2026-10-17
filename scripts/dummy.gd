extends StaticBody2D

var hp := 3

func take_damage(amount):
	hp -= amount
	modulate.a = 0.3
	await get_tree().create_timer(0.08).timeout
	modulate.a = 1.0
	if hp <= 0:
		queue_free()
