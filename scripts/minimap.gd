extends Control
## Мини-карта этажа: посещённые комнаты и соседние с ними.

const DIR := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const CELL := Vector2(9, 6)
const STEP := Vector2(12, 9)

var rooms := {}
var current := Vector2i.ZERO


func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh(new_rooms: Dictionary, cell: Vector2i) -> void:
	rooms = new_rooms
	current = cell
	queue_redraw()


# 0 — неизвестна, 1 — видна из соседней посещённой, 2 — посещена
func _known(c: Vector2i) -> int:
	if rooms[c].visited:
		return 2
	for side in 4:
		var n: Vector2i = c + DIR[side]
		if rooms.has(n) and rooms[n].visited and rooms[n].doors[(side + 2) % 4]:
			return 1
	return 0


func _draw() -> void:
	var link := Color(0.45, 0.45, 0.42, 0.9)
	var gap := STEP - CELL
	for c in rooms:
		var k := _known(c)
		if k == 0:
			continue
		var d = rooms[c]
		var pos := Vector2(c) * STEP
		var col := Color(0.55, 0.55, 0.5, 0.9) if k == 2 else Color(0.25, 0.25, 0.3, 0.8)
		if d.kind == "boss":
			col = Color(0.8, 0.2, 0.2, 0.95) if k == 2 else Color(0.45, 0.15, 0.15, 0.85)
		if c == current:
			col = Color(1.0, 0.9, 0.5)
		draw_rect(Rect2(pos, CELL), col)
		if k == 2:
			if d.doors[0]:
				draw_rect(Rect2(pos + Vector2(3, -gap.y), Vector2(3, gap.y)), link)
			if d.doors[1]:
				draw_rect(Rect2(pos + Vector2(CELL.x, 2), Vector2(gap.x, 2)), link)
			if d.doors[2]:
				draw_rect(Rect2(pos + Vector2(3, CELL.y), Vector2(3, gap.y)), link)
			if d.doors[3]:
				draw_rect(Rect2(pos + Vector2(-gap.x, 2), Vector2(gap.x, 2)), link)
