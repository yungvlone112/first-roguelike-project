extends RefCounted
## Маска комнаты на сетке 48x27 тайлов (по 16 px = 768x432): где пол, где стены, где двери.
## Камера следует за игроком (лимиты в player.tscn), комната больше одного экрана 480x270.
## Северная стена двухрядная (крыша + «лицо»), поэтому пол начинается с ряда TOP.

const COLS := 48
const ROWS := 27
const TILE := 16
const TOP := 2                       # первый ряд пола (ряды 0..1 — северная стена)
const SIZE := Vector2(768, 432)      # COLS * TILE, ROWS * TILE
const CENTER := Vector2(384, 224)    # середина пола: босс, награды, портал

const DIR := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W
# Клетки дверных проёмов (в кольце стен) по сторонам N E S W
# (северная дверь занимает оба ряда стены)
const DOOR_CELLS := [Rect2i(22, 0, 4, 2), Rect2i(47, 12, 1, 4), Rect2i(22, 26, 4, 1), Rect2i(0, 12, 1, 4)]
# Куда ставим игрока, вошедшего через дверь этой стороны
const SPAWNS := [Vector2(384, 64), Vector2(728, 224), Vector2(384, 380), Vector2(40, 224)]

var floor_mask := PackedByteArray()
var wall_mask := PackedByteArray()
var doors := [false, false, false, false]


func _init(data):
	floor_mask.resize(COLS * ROWS)
	wall_mask.resize(COLS * ROWS)
	floor_mask.fill(0)
	wall_mask.fill(0)
	# Внутренность комнаты: колонки 1..COLS-2, строки TOP..ROWS-2
	for y in range(TOP, ROWS - 1):
		for x in range(1, COLS - 1):
			floor_mask[y * COLS + x] = 1
	# Вырезы углов
	for cut in data.cuts:
		for y in range(cut.position.y, cut.end.y):
			for x in range(cut.position.x, cut.end.x):
				floor_mask[y * COLS + x] = 0
	# Дверные проёмы считаем полом (поверх них в игре встанет запираемая дверь)
	for side in 4:
		doors[side] = data.doors[side]
		if doors[side]:
			var r: Rect2i = DOOR_CELLS[side]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					floor_mask[y * COLS + x] = 1
	# Стена = не-пол, у которого рядом (включая диагональ) есть пол
	for y in ROWS:
		for x in COLS:
			if is_floor(x, y):
				continue
			var near := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if is_floor(x + dx, y + dy):
						near = true
			if near:
				wall_mask[y * COLS + x] = 1
	# Над «лицом» стены (клетка, под которой пол) добавляем ряд крыши: стена двухрядная
	var roof: Array[int] = []
	for y in range(1, ROWS):
		for x in COLS:
			if wall_mask[y * COLS + x] == 1 and is_floor(x, y + 1) \
					and wall_mask[(y - 1) * COLS + x] == 0 and not is_floor(x, y - 1):
				roof.append((y - 1) * COLS + x)
	for i in roof:
		wall_mask[i] = 1


func is_floor(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return false
	return floor_mask[y * COLS + x] == 1


static func spawn_point(side: int) -> Vector2:
	if side < 0:
		return CENTER
	return SPAWNS[side]


# Клетки двери, ближайшие к комнате (у северной двери это нижний из двух рядов)
static func door_edge(side: int) -> Rect2i:
	var r: Rect2i = DOOR_CELLS[side]
	if side == 0:
		return Rect2i(r.position.x, r.end.y - 1, r.size.x, 1)
	return r


func door_rect(side: int) -> Rect2:
	var r: Rect2i = DOOR_CELLS[side]
	return Rect2(Vector2(r.position * TILE), Vector2(r.size * TILE))


# Проверка формы: двери и точки входа на полу, весь пол одной связной областью
func check() -> bool:
	for side in 4:
		if not doors[side]:
			continue
		var r: Rect2i = DOOR_CELLS[side]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if not is_floor(x - DIR[side].x, y - DIR[side].y):
					return false
		var sp: Vector2 = SPAWNS[side]
		if not is_floor(int(sp.x / TILE), int(sp.y / TILE)):
			return false
	var first := -1
	var total := 0
	for i in floor_mask.size():
		if floor_mask[i] == 1:
			total += 1
			if first < 0:
				first = i
	if first < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(COLS * ROWS)
	seen.fill(0)
	seen[first] = 1
	var stack: Array[int] = [first]
	var count := 1
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % COLS
		@warning_ignore("integer_division")
		var y := (i - x) / COLS
		for d in DIR:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if is_floor(nx, ny) and seen[ny * COLS + nx] == 0:
				seen[ny * COLS + nx] = 1
				count += 1
				stack.append(ny * COLS + nx)
	return count == total


# Стены, склеенные в крупные прямоугольники (меньше коллизий)
func wall_rects() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var used := PackedByteArray()
	used.resize(COLS * ROWS)
	used.fill(0)
	for y in ROWS:
		for x in COLS:
			if wall_mask[y * COLS + x] == 0 or used[y * COLS + x] == 1:
				continue
			var w := 1
			while x + w < COLS and wall_mask[y * COLS + x + w] == 1 and used[y * COLS + x + w] == 0:
				w += 1
			var h := 1
			var grow := true
			while grow and y + h < ROWS:
				for i in w:
					var k := (y + h) * COLS + x + i
					if wall_mask[k] == 0 or used[k] == 1:
						grow = false
						break
				if grow:
					h += 1
			for yy in h:
				for xx in w:
					used[(y + yy) * COLS + x + xx] = 1
			out.append(Rect2i(x, y, w, h))
	return out
