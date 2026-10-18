extends Node2D

signal exited

var alive := 0
var started := false

@onready var door = $Door
@onready var trigger: Area2D = $Trigger
@onready var exit_zone: Area2D = $Exit

func _ready():
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
	if body.is_in_group("player"):
		exited.emit()

func _on_enemy_died():
	alive -= 1
	if alive <= 0:
		door.unlock()
