extends Node2D
## Комната этажа: стены и двери по маске, оформление, враги, награды, выход на соседние комнаты.
## Выходы, начало боя и портал работают по позиции игрока (каждый физический кадр),
## а не по событиям Area2D: так нельзя «застрять» с открытыми дверями.

signal exited(side: int)   # игрок вышел через дверь стороны side (0 N, 1 E, 2 S, 3 W)
signal descend             # игрок вошёл в портал после босса

const ENEMY = preload("res://scenes/enemy.tscn")
const SHOOTER = preload("res://scenes/shooter.tscn")
const BOSS = preload("res://scenes/boss.tscn")
const PICKUP = preload("res://scenes/pickup.tscn")
const WALL = preload("res://scenes/wall.tscn")
const RoomLayout = preload("res://scripts/room_layout.gd")
const RoomDressing = preload("res://scripts/room_dressing.gd")
const RoomSpecial = preload("res://scripts/room_special.gd")
const LIGHT = preload("res://scripts/light.gd")
const DOOR_TEX = preload("res://art/tiles/door_sealed.png")
const DOOR_BOSS_TEX = preload("res://art/tiles/door_boss.png")
const PORTAL_TEX = preload("res://art/props/torii.png")
# Оттенок пола особых комнат (чтобы отличать заготовки, пока нет своих текстур)
const TINTS := {
	"shop": Color(1.3, 1.15, 0.8),
	"chest": Color(0.85, 0.95, 1.3),
	"story": Color(1.1, 0.85, 1.3),
}

const LEAVE_COOLDOWN := 0.8

# Игрок вошёл в эту зону (центр комнаты ± 250x120): начинается бой
var trigger_rect := Rect2(RoomLayout.CENTER - Vector2(250, 120), Vector2(500, 240))
var bounds := Rect2(Vector2.ZERO, RoomLayout.SIZE)   # вся комната целиком

var data                      # FloorGen.RoomData
var entry_side := -1          # через какую дверь вошли (-1: старт этажа)
var floor_num := 1
var theme := "tatami"
var boss_hp := 12
var boss_side := -1           # сторона двери, ведущей в комнату босса (-1: такой двери нет)

var layout
var dressing
var enemies: Node2D
var doors := {}               # сторона -> Wall (запираемая дверь)
var astar: AStarGrid2D
var pending := {}             # живые враги комнаты: instance_id -> true
var started := false
var locked := false
var player: Node2D
var leave_cd := 0.0
var portal_pos := Vector2.ZERO
var portal_ready_ms := -1     # когда портал начнёт принимать игрока (-1: портала нет)


func _ready():
	layout = RoomLayout.new(data)
	_build_walls()
	dressing = RoomDressing.new()
	add_child(dressing)
	dressing.build(layout, data, theme, floor_num, boss_side)
	if TINTS.has(data.kind):
		dressing.floor_sprite.modulate = TINTS[data.kind]
	_build_doors()
	_build_nav()
	enemies = Node2D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	if not data.cleared:
		_spawn_enemies(RoomLayout.spawn_point(entry_side))
	for e in enemies.get_children():
		var id: int = e.get_instance_id()
		pending[id] = true
		e.died.connect(_on_enemy_died.bind(id))
	if RoomSpecial.KINDS.has(data.kind):
		var special := RoomSpecial.new()
		add_child(special)
		special.setup(self, data)
	if data.kind == "boss" and data.cleared:
		_spawn_portal(false)


# ---------- Построение ----------
func _build_walls() -> void:
	for r in layout.wall_rects():
		var w = WALL.instantiate()
		w.size = Vector2(r.size * RoomLayout.TILE)
		w.position = Vector2(r.position * RoomLayout.TILE)
		add_child(w)
		w.get_node("Visual").visible = false   # картинку стен рисует RoomDressing


func _build_doors() -> void:
	for side in 4:
		if not data.doors[side]:
			continue
		var rect: Rect2 = layout.door_rect(side)
		var d = WALL.instantiate()
		d.size = rect.size
		d.position = rect.position
		add_child(d)
		d.get_node("Visual").texture = DOOR_BOSS_TEX if side == boss_side else DOOR_TEX
		d.unlock()
		doors[side] = d
		if side == boss_side:
			_add_boss_door_light(rect)


# Красное пульсирующее свечение у двери в комнату босса
func _add_boss_door_light(rect: Rect2) -> void:
	var l := PointLight2D.new()
	l.set_script(LIGHT)
	l.set("light_radius", 70.0)
	l.set("tint", Color(1.0, 0.25, 0.25))
	l.position = rect.get_center()
	add_child(l)


func _build_nav() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, RoomLayout.COLS, RoomLayout.ROWS)
	astar.cell_size = Vector2(RoomLayout.TILE, RoomLayout.TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in RoomLayout.ROWS:
		for x in RoomLayout.COLS:
			if not layout.is_floor(x, y):
				astar.set_point_solid(Vector2i(x, y), true)
	# Дверные проёмы враги не используют: они всегда внутри комнаты
	for side in 4:
		if data.doors[side]:
			var dr: Rect2i = RoomLayout.DOOR_CELLS[side]
			for y in range(dr.position.y, dr.end.y):
				for x in range(dr.position.x, dr.end.x):
					astar.set_point_solid(Vector2i(x, y), true)
	for r in dressing.blocked:
		var x0 := floori(r.position.x / RoomLayout.TILE)
		var y0 := floori(r.position.y / RoomLayout.TILE)
		var x1 := floori((r.end.x - 0.01) / RoomLayout.TILE)
		var y1 := floori((r.end.y - 0.01) / RoomLayout.TILE)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				astar.set_point_solid(Vector2i(x, y), true)


func _spawn_enemies(spawn: Vector2) -> void:
	if data.kind == "boss":
		var b = BOSS.instantiate()
		b.max_hp = boss_hp
		b.position = RoomLayout.CENTER
		enemies.add_child(b)
		return
	for i in data.enemy_count:
		var scene = ENEMY
		if i % 3 == 2:
			scene = SHOOTER
		var e = scene.instantiate()
		e.position = dressing.random_enemy_point(spawn)
		enemies.add_child(e)


# ---------- Каждый физический кадр ----------
func _physics_process(delta):
	if leave_cd > 0.0:
		leave_cd -= delta
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var p: Vector2 = player.global_position
	# 1. Выход через открытую дверь (в том числе если игрок уже «за краем»)
	if not locked:
		for side in doors:
			if _exit_rect(side).has_point(p):
				leave_cd = LEAVE_COOLDOWN
				exited.emit(side)
				return
	# 2. Портал после босса
	if portal_ready_ms >= 0 and Time.get_ticks_msec() >= portal_ready_ms:
		if Rect2(portal_pos + Vector2(-8, 2), Vector2(16, 16)).has_point(p):
			leave_cd = LEAVE_COOLDOWN
			descend.emit()
			return
	# 3. Начало боя
	if not started and trigger_rect.has_point(p):
		_start_combat()
	# 4. Страховки
	_keep_player_inside(p)
	_keep_enemies_inside()


# Зона выхода: дверной проём + 8 px внутрь комнаты + всё, что дальше за краем экрана
func _exit_rect(side: int) -> Rect2:
	var r: Rect2 = layout.door_rect(side)
	match side:
		0:
			return Rect2(r.position.x, -200.0, r.size.x, 200.0 + r.size.y + 8.0)
		1:
			return Rect2(r.position.x - 8.0, r.position.y, r.size.x + 208.0, r.size.y)
		2:
			return Rect2(r.position.x, r.position.y - 8.0, r.size.x, r.size.y + 208.0)
		_:
			return Rect2(-200.0, r.position.y, 200.0 + r.size.x + 8.0, r.size.y)


func _keep_player_inside(p: Vector2) -> void:
	if not bounds.has_point(p):
		push_warning("Игрок оказался за пределами комнаты без двери, возвращаю")
		player.global_position = RoomLayout.spawn_point(entry_side)
		return
	if locked:
		for side in doors:
			if layout.door_rect(side).grow(2.0).has_point(p):
				player.global_position = RoomLayout.spawn_point(side)   # выталкиваем из запертой двери
				return


func _keep_enemies_inside() -> void:
	for e in enemies.get_children():
		var cx := floori(e.position.x / RoomLayout.TILE)
		var cy := floori(e.position.y / RoomLayout.TILE)
		var inside: bool = cx >= 1 and cx <= RoomLayout.COLS - 2 and cy >= 1 \
				and cy <= RoomLayout.ROWS - 2 and layout.is_floor(cx, cy)
		if not inside:
			unstick(e)


# Переставляет застрявшего или вылетевшего за пределы врага в свободную точку (вызывают и сами враги)
func unstick(e: Node2D) -> void:
	var avoid := RoomLayout.CENTER
	if player != null and is_instance_valid(player):
		avoid = player.global_position
	e.global_position = dressing.random_enemy_point(avoid, 90.0)
	if e is CharacterBody2D:
		(e as CharacterBody2D).velocity = Vector2.ZERO
	push_warning("Враг застрял, переставлен на свободное место")


# ---------- Ход боя ----------
func _start_combat() -> void:
	started = true
	if pending.is_empty():
		return
	_lock_doors()
	Sfx.play("door")
	for e in enemies.get_children():
		e.active = true


func _lock_doors() -> void:
	locked = true
	for side in doors:
		var zone: Rect2 = layout.door_rect(side).grow(8.0)
		for e in enemies.get_children():
			if zone.has_point(e.position):
				unstick(e)   # чтобы дверь не захлопнулась на враге
		doors[side].lock()


func _unlock_doors() -> void:
	locked = false
	for side in doors:
		doors[side].unlock()


func _on_enemy_died(id: int) -> void:
	if not pending.has(id):
		return   # повторный сигнал смерти одного и того же врага
	pending.erase(id)
	Meta.add_souls(1)
	if pending.is_empty():
		data.cleared = true
		_unlock_doors()
		Sfx.play("door")
		drop_rewards.call_deferred()


func drop_rewards() -> void:
	if data.kind == "boss":
		Meta.add_souls(10)
		spawn_pickup("heal", RoomLayout.CENTER + Vector2(-44, 0))
		spawn_pickup(["damage", "speed", "maxhp"].pick_random(), RoomLayout.CENTER + Vector2(44, 0))
		_spawn_portal(true)
	elif randf() < 0.3:
		spawn_pickup("heal", RoomLayout.CENTER)


func spawn_pickup(kind, pos) -> void:
	var p = PICKUP.instantiate()
	p.kind = kind
	p.position = pos
	add_child(p)


# Тории-портал на следующий этаж (появляется после босса)
func _spawn_portal(delayed: bool) -> void:
	if portal_ready_ms >= 0:
		return   # портал уже есть
	var holder := Node2D.new()
	holder.position = RoomLayout.CENTER + Vector2(0, -16)
	add_child(holder)
	var spr := Sprite2D.new()
	spr.texture = PORTAL_TEX
	spr.position = Vector2(0, -4)
	holder.add_child(spr)
	var l := PointLight2D.new()
	l.set_script(LIGHT)
	l.set("light_radius", 70.0)
	l.set("tint", Color(1.0, 0.45, 0.4))
	l.position = Vector2(0, 6)
	holder.add_child(l)
	portal_pos = holder.position
	portal_ready_ms = Time.get_ticks_msec() + (1000 if delayed else 0)


# ---------- Навигация врагов ----------
# Куда идти из точки from к точке to: напрямую или в обход стен и препятствий
func steer(from: Vector2, to: Vector2) -> Vector2:
	var direct := (to - from).normalized()
	if astar == null:
		return direct
	var a := Vector2i(floori(from.x / RoomLayout.TILE), floori(from.y / RoomLayout.TILE))
	var b := Vector2i(floori(to.x / RoomLayout.TILE), floori(to.y / RoomLayout.TILE))
	if a == b or not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return direct
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return direct
	var path := astar.get_id_path(a, b)
	if path.size() <= 2:
		return direct
	var next_pos := Vector2(path[1]) * RoomLayout.TILE + Vector2(8, 8)
	return (next_pos - from).normalized()
