extends RefCounted
## Маска комнаты на сетке 30x17 тайлов (по 16 px): где пол, где стены, где двери.

const COLS := 30
const ROWS := 17
const TILE := 16

const DIR := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W
# Клетки дверных проёмов (в кольце стен) по сторонам N E S W
const DOOR_CELLS := [Rect2i(13, 0, 4, 1), Rect2i(29, 7, 1, 3), Rect2i(13, 16, 4, 1), Rect2i(0, 7, 1, 3)]
# Куда ставим игрока, вошедшего через дверь этой стороны
const SPAWNS := [Vector2(240, 40), Vector2(440, 136), Vector2(240, 232), Vector2(40, 136)]

var floor_mask := PackedByteArray()
var wall_mask := PackedByteArray()
var doors := [false, false, false, false]


func _init(data):
	floor_mask.resize(COLS * ROWS)
	wall_mask.resize(COLS * ROWS)
	floor_mask.fill(0)
	wall_mask.fill(0)
	# Внутренность комнаты: колонки 1..28, строки 1..15
	for y in range(1, ROWS - 1):
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


func is_floor(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return false
	return floor_mask[y * COLS + x] == 1


static func spawn_point(side: int) -> Vector2:
	if side < 0:
		return Vector2(240, 136)
	return SPAWNS[side]


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
