extends Node2D

const ROOM = preload("res://scenes/room.tscn")

var floor_num := 1
var room_idx := 0
var rooms_in_floor := 5
var current: Node2D
var transitioning := false
var ambient := 0.14
var dark: CanvasModulate

@onready var player = $Player
@onready var info: Label = $Player/HUD/InfoLabel

func _ready():
	dark = CanvasModulate.new()
	add_child(dark)
	apply_ambient()
	start_floor()

func apply_ambient():
	dark.color = Color(ambient, ambient * 0.85, minf(ambient * 1.4, 1.0))

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_MINUS:
			ambient = maxf(0.05, ambient - 0.05)
			apply_ambient()
		elif event.physical_keycode == KEY_EQUAL:
			ambient = minf(1.0, ambient + 0.05)
			apply_ambient()

func start_floor():
	room_idx = 0
	rooms_in_floor = randi_range(5, 6)
	load_room()

func load_room():
	transitioning = false
	if current:
		current.queue_free()
	current = ROOM.instantiate()
	if room_idx == 0:
		current.enemy_count = 1
	elif room_idx == rooms_in_floor - 1:
		current.is_boss = true
		current.boss_hp = 8 + 4 * floor_num
	else:
		current.enemy_count = randi_range(2, 3 + floor_num)
	player.global_position = Vector2(40, 135)
	add_child(current)
	move_child(current, 0)
	current.exited.connect(_on_room_exited)
	info.text = "Этаж %d, комната %d из %d" % [floor_num, room_idx + 1, rooms_in_floor]

func _on_room_exited():
	if transitioning:
		return
	transitioning = true
	room_idx += 1
	if room_idx >= rooms_in_floor:
		floor_num += 1
		start_floor.call_deferred()
	else:
		load_room.call_deferred()
