extends Node2D

const ROOM = preload("res://scenes/room.tscn")

var floor_num := 1
var room_idx := 0
var rooms_in_floor := 5
var current: Node2D
var transitioning := false

@onready var player = $Player
@onready var info: Label = $Player/HUD/InfoLabel

func log_msg(text):
	print("[%.2f] %s" % [Time.get_ticks_msec() / 1000.0, text])

func _ready():
	start_floor()

func start_floor():
	room_idx = 0
	rooms_in_floor = randi_range(5, 6)
	log_msg("НОВЫЙ ЭТАЖ %d, комнат: %d" % [floor_num, rooms_in_floor])
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
	log_msg("загружена комната %d из %d, врагов: %d, надпись: %s" % [room_idx + 1, rooms_in_floor, current.enemy_count, info.text])

func _on_room_exited():
	if transitioning:
		log_msg("лишний сигнал выхода проигнорирован")
		return
	transitioning = true
	log_msg("выход из комнаты %d из %d (этаж %d)" % [room_idx + 1, rooms_in_floor, floor_num])
	room_idx += 1
	if room_idx >= rooms_in_floor:
		floor_num += 1
		start_floor.call_deferred()
	else:
		load_room.call_deferred()
