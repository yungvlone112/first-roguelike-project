extends Node2D

const ROOM = preload("res://scenes/room.tscn")

var rooms_done := 0
var current: Node2D

@onready var player = $Player

func _ready():
	load_room()

func load_room():
	if current:
		current.queue_free()
	current = ROOM.instantiate()
	add_child(current)
	move_child(current, 0)
	current.exited.connect(_on_room_exited)
	player.global_position = Vector2(40, 135)

func _on_room_exited():
	rooms_done += 1
	print("комнат пройдено: ", rooms_done)
	load_room.call_deferred()
