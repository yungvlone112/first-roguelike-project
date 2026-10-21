extends RefCounted
## Генерация этажа: извилистый путь к боссу + ответвления + особые комнаты в тупиках.

const RoomLayout = preload("res://scripts/room_layout.gd")

const DIR := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W
const GRID := Vector2i(6, 4)
# Какие две стороны касаются угла: 0 лево-верх, 1 право-верх, 2 лево-низ, 3 право-низ
const CORNER_SIDES := [[0, 3], [0, 1], [2, 3], [2, 1]]
# Особые комнаты (по одной на этаж); порядок важен: сюжетная занимает самый дальний тупик
const SPECIAL_KINDS := ["story", "shop", "chest"]


class RoomData:
	var cell := Vector2i.ZERO
	var doors := [false, false, false, false]   # N E S W
	var kind := "normal"                        # start / normal / boss / shop / chest / story
	var seed := 0
	var cuts: Array[Rect2i] = []                # вырезы-углы в тайлах (x, y, w, h)
	var enemy_count := 0
	var visited := false
	var cleared := false
	var state := {}                             # состояние особых комнат (куплено, открыто и т.д.)


# Возвращает Dictionary: Vector2i (клетка на карте) -> RoomData
static func generate(floor_num: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for attempt in 60:
		var rooms := _try_generate(floor_num, rng, true)
		if not rooms.is_empty():
			return rooms
	return _try_generate(floor_num, rng, false)   # запасной вариант без особых комнат


static func _try_generate(floor_num: int, rng: RandomNumberGenerator, with_specials: bool) -> Dictionary:
	# 1. Главный путь старт -> босс (самонепересекающийся, минимум 2 поворота)
	var path := _make_path(rng.randi_range(5, 6), rng)
	if path.is_empty():
		return {}
	var rooms := {}
	var on_path := {}
	for i in path.size():
		rooms[path[i]] = _make(path[i], rng)
		on_path[path[i]] = true
		if i > 0:
			_link(rooms[path[i - 1]], _side_between(path[i - 1], path[i]), rooms[path[i]])
	var start: Vector2i = path[0]
	var boss_cell: Vector2i = path[path.size() - 1]
	rooms[start].kind = "start"
	rooms[start].cleared = true
	rooms[boss_cell].kind = "boss"

	# 2. Ответвления: новые комнаты цепляются к любой комнате, кроме босса
	var branches: Array = []
	var branch_count := clampi(3 + floor_num, 4, 6)
	for i in branch_count:
		var hosts: Array = rooms.keys()
		if not branches.is_empty() and rng.randf() < 0.45:
			hosts = branches
		var cell := _grow(rooms, hosts, boss_cell, rng)
		if cell.x < 0:
			cell = _grow(rooms, rooms.keys(), boss_cell, rng)
		if cell.x >= 0:
			branches.append(cell)

	# 3. Пара петель (не между двумя комнатами главного пути и никогда не к боссу)
	var loops := 0
	var keys: Array = rooms.keys()
	for i in 12:
		if loops >= 2:
			break
		var c: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var side := rng.randi_range(0, 3)
		var nb: Vector2i = c + DIR[side]
		if c == boss_cell or nb == boss_cell or not rooms.has(nb) or rooms[c].doors[side]:
			continue
		if on_path.has(c) and on_path.has(nb):
			continue
		_link(rooms[c], side, rooms[nb])
		loops += 1

	# 4. Особые комнаты: только тупики с одной дверью
	if with_specials:
		var dist := _distances(rooms, start)
		for kind in SPECIAL_KINDS:
			var hosts: Array = []
			for c in rooms:
				if c != boss_cell and not SPECIAL_KINDS.has(rooms[c].kind):
					hosts.append(c)
			if kind == "story":
				hosts.sort_custom(func(a, b): return dist[a] > dist[b])
				hosts = hosts.slice(0, 3)
			var cell := _grow(rooms, hosts, boss_cell, rng)
			if cell.x < 0:
				return {}
			rooms[cell].kind = kind
			rooms[cell].cleared = true

	for c in rooms:
		var r = rooms[c]
		if r.kind == "normal":
			r.enemy_count = rng.randi_range(2, 3 + floor_num)
		_assign_shape(r, rng)
	return rooms


# Случайный самонепересекающийся путь из length клеток
static func _make_path(length: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	for attempt in 80:
		var start := Vector2i(rng.randi_range(0, GRID.x - 1), rng.randi_range(0, GRID.y - 1))
		var path: Array[Vector2i] = [start]
		var used := {start: true}
		if _extend(path, used, length, rng) and _turns(path) >= 2:
			return path
	var none: Array[Vector2i] = []
	return none


static func _extend(path: Array[Vector2i], used: Dictionary, length: int, rng: RandomNumberGenerator) -> bool:
	if path.size() == length:
		return true
	var cur: Vector2i = path.back()
	var sides := [0, 1, 2, 3]
	for i in range(3, 0, -1):
		var j := rng.randi_range(0, i)
		var t = sides[i]
		sides[i] = sides[j]
		sides[j] = t
	for side in sides:
		var nxt: Vector2i = cur + DIR[side]
		if _in_grid(nxt) and not used.has(nxt):
			path.append(nxt)
			used[nxt] = true
			if _extend(path, used, length, rng):
				return true
			path.pop_back()
			used.erase(nxt)
	return false


static func _turns(path: Array[Vector2i]) -> int:
	var t := 0
	for i in range(2, path.size()):
		if path[i] - path[i - 1] != path[i - 1] - path[i - 2]:
			t += 1
	return t


# Добавляет новую комнату рядом с одной из hosts (кроме босса) и соединяет дверью.
# Возвращает клетку новой комнаты или (-1, -1), если места нет.
static func _grow(rooms: Dictionary, hosts: Array, boss_cell: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var opts: Array = []
	for h in hosts:
		if h == boss_cell:
			continue
		for side in 4:
			var nb: Vector2i = h + DIR[side]
			if _in_grid(nb) and not rooms.has(nb):
				opts.append([h, side])
	if opts.is_empty():
		return Vector2i(-1, -1)
	var o: Array = opts[rng.randi_range(0, opts.size() - 1)]
	var host: Vector2i = o[0]
	var new_cell: Vector2i = host + DIR[o[1]]
	rooms[new_cell] = _make(new_cell, rng)
	_link(rooms[host], o[1], rooms[new_cell])
	return new_cell


static func _distances(rooms: Dictionary, start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for side in 4:
			if rooms[c].doors[side]:
				var nb: Vector2i = c + DIR[side]
				if not dist.has(nb):
					dist[nb] = dist[c] + 1
					queue.append(nb)
	return dist


static func _side_between(a: Vector2i, b: Vector2i) -> int:
	for side in 4:
		if a + DIR[side] == b:
			return side
	return 0


static func _make(cell: Vector2i, rng: RandomNumberGenerator) -> RoomData:
	var r := RoomData.new()
	r.cell = cell
	r.seed = rng.randi()
	return r


static func _link(a, side: int, b) -> void:
	a.doors[side] = true
	b.doors[(side + 2) % 4] = true


static func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID.x and c.y < GRID.y


# ---------- Форма комнаты ----------
static func _assign_shape(r, rng: RandomNumberGenerator) -> void:
	r.cuts.clear()
	if r.kind != "normal" and r.kind != "boss":
		return   # старт и особые комнаты всегда прямоугольные (удобно рисовать свои)
	var roll := rng.randf()
	var shape := "rect"
	if r.kind == "boss":
		shape = "cross" if roll < 0.6 else "rect"
	elif roll < 0.25:
		shape = "rect"
	elif roll < 0.65:
		shape = "L"
	elif roll < 0.80:
		shape = "Z"
	else:
		shape = "cross"
	match shape:
		"L":
			r.cuts.append(_corner_cut(rng.randi_range(0, 3), r, rng))
		"Z":
			var pair: Array = [0, 3] if rng.randf() < 0.5 else [1, 2]
			for c in pair:
				r.cuts.append(_corner_cut(c, r, rng))
		"cross":
			for c in 4:
				r.cuts.append(_cut_rect(c, rng.randi_range(5, 8), rng.randi_range(3, 5)))
	# Страховка: если форма вышла битой (не связана, дверь заперта вырезом), оставляем прямоугольник
	if not RoomLayout.new(r).check():
		r.cuts.clear()


# Большой вырез (настоящий «Г») допустим, только если обе стороны у этого угла без дверей.
static func _corner_cut(corner: int, r, rng: RandomNumberGenerator) -> Rect2i:
	var sides: Array = CORNER_SIDES[corner]
	var free: bool = not r.doors[sides[0]] and not r.doors[sides[1]]
	var w: int
	var h: int
	if free and rng.randf() < 0.6:
		w = rng.randi_range(9, 14)
		h = rng.randi_range(5, 7)
	else:
		w = rng.randi_range(5, 11)
		h = rng.randi_range(3, 6)
	return _cut_rect(corner, w, h)


static func _cut_rect(corner: int, w: int, h: int) -> Rect2i:
	match corner:
		0:
			return Rect2i(1, 1, w, h)
		1:
			return Rect2i(29 - w, 1, w, h)
		2:
			return Rect2i(1, 16 - h, w, h)
		_:
			return Rect2i(29 - w, 16 - h, w, h)
