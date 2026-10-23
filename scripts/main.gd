extends Node2D

const ROOM = preload("res://scenes/room.tscn")
const FloorGen = preload("res://scripts/floor_gen.gd")
const RoomLayout = preload("res://scripts/room_layout.gd")
const Minimap = preload("res://scripts/minimap.gd")

var floor_num := 1
var rooms := {}               # Vector2i (клетка на карте этажа) -> RoomData
var cell := Vector2i.ZERO     # где сейчас игрок
var current: Node2D
var transitioning := false
var ambient := 0.14
var dark: CanvasModulate
var fade: ColorRect
var minimap: Control
var transition_time := 0.0

@onready var player = $Player
@onready var info: Label = $Player/HUD/InfoLabel

func _ready():
	RenderingServer.set_default_clear_color(Color(0.02, 0.015, 0.03))
	dark = CanvasModulate.new()
	add_child(dark)
	apply_ambient()
	_make_overlay()
	start_floor()

func _make_overlay():
	var map_layer := CanvasLayer.new()
	map_layer.layer = 5
	add_child(map_layer)
	minimap = Minimap.new()
	minimap.position = Vector2(480 - 6 - FloorGen.GRID.x * 12, 6)
	map_layer.add_child(minimap)
	var top := CanvasLayer.new()
	top.layer = 10
	add_child(top)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = Vector2(480, 270)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fade)

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
	rooms = FloorGen.generate(floor_num)
	for c in rooms:
		if rooms[c].kind == "start":
			cell = c
	enter_room(cell, -1)

func enter_room(c: Vector2i, entry_side: int):
	cell = c
	var data = rooms[c]
	data.visited = true
	if current:
		remove_child(current)   # сразу убираем из дерева, чтобы старые стены не мешали физике
		current.queue_free()
	for n in get_children():
		if n is Area2D:         # улетевшие сюрикены
			n.queue_free()
	current = ROOM.instantiate()
	current.data = data
	current.entry_side = entry_side
	current.floor_num = floor_num
	current.boss_hp = 8 + 4 * floor_num
	current.boss_side = -1
	for side in 4:   # если за одной из дверей комната босса, помечаем её как опасную
		if data.doors[side] and rooms[c + FloorGen.DIR[side]].kind == "boss":
			current.boss_side = side
	player.global_position = RoomLayout.spawn_point(entry_side)
	player.velocity = Vector2.ZERO
	var cam: Camera2D = player.get_node("Camera2D")
	cam.force_update_scroll()
	cam.reset_smoothing()   # при входе в комнату камера сразу на игроке, без наезда
	add_child(current)
	move_child(current, 0)
	current.exited.connect(_on_room_exited)
	current.descend.connect(_on_descend)
	info.text = "Этаж %d" % floor_num
	minimap.refresh(rooms, cell)

func _on_room_exited(side: int):
	if transitioning:
		return
	_go.call_deferred(side)

func _go(side: int):
	var target: Vector2i = cell + FloorGen.DIR[side]
	if not rooms.has(target):
		push_warning("За дверью %d нет комнаты (клетка %s)" % [side, cell])
		return
	_begin_transition()
	await _fade_to(1.0, 0.12)
	enter_room(target, (side + 2) % 4)
	await _fade_to(0.0, 0.15)
	_end_transition()

func _begin_transition():
	transitioning = true
	transition_time = 0.0
	player.set_physics_process(false)

func _end_transition():
	player.set_physics_process(true)
	transitioning = false

# Страховка: если переход почему-то завис, разблокируем игрока
func _process(delta):
	if not transitioning:
		return
	transition_time += delta
	if transition_time > 2.5:
		push_warning("Переход завис, сбрасываю")
		fade.color.a = 0.0
		_end_transition()

func _on_descend():
	if transitioning:
		return
	_descend.call_deferred()

func _descend():
	_begin_transition()
	await _fade_to(1.0, 0.4)
	floor_num += 1
	start_floor()
	await _fade_to(0.0, 0.4)
	_end_transition()

func _fade_to(alpha: float, time: float):
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, time)
	await tw.finished
