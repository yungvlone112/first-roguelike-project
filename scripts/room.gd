extends Node2D

signal exited

const ENEMY = preload("res://scenes/enemy.tscn")
const SHOOTER = preload("res://scenes/shooter.tscn")
const BOSS = preload("res://scenes/boss.tscn")

var enemy_count := 2
var is_boss := false
var boss_hp := 12
var alive := 0
var started := false
var exiting := false

@onready var door = $Door
@onready var trigger: Area2D = $Trigger
@onready var exit_zone: Area2D = $Exit

func _ready():
	if is_boss:
		var b = BOSS.instantiate()
		b.max_hp = boss_hp
		b.position = Vector2(380, 135)
		$Enemies.add_child(b)
	else:
		for i in enemy_count:
			var scene = ENEMY
			if i % 3 == 2:
				scene = SHOOTER
			var e = scene.instantiate()
			e.position = Vector2(randf_range(150, 420), randf_range(50, 220))
			$Enemies.add_child(e)
	door.unlock()
	for e in $Enemies.get_children():
		alive += 1
		e.died.connect(_on_enemy_died)
	trigger.body_entered.connect(_on_enter)
	exit_zone.body_entered.connect(_on_exit)

func _on_enter(body):
	if started or not body.is_in_group("player"):
		return
	started = true
	if alive > 0:
		door.lock()
		for e in $Enemies.get_children():
			e.active = true

func _on_exit(body):
	if exiting or not body.is_in_group("player"):
		return
	if body.global_position.x < 400:
		return
	exiting = true
	exited.emit()

func _on_enemy_died():
	alive -= 1
	if alive <= 0:
		door.unlock()
