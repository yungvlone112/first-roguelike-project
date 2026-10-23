extends Node2D
## Заготовки особых комнат: магазин, сундук, сюжетная. Пока на плейсхолдерах.
##
## Свои комнаты: положи сцену res://scenes/rooms/shop.tscn (или chest.tscn / story.tscn) —
## она подставится вместо заготовки. Если у корня сцены есть метод setup(room, data),
## он будет вызван (room — узел комнаты, data — её RoomData, data.state хранит состояние).

const KINDS := ["shop", "chest", "story"]
const RoomLayout = preload("res://scripts/room_layout.gd")
const CUSTOM_DIR := "res://scenes/rooms/"

const CHEST_TEX = preload("res://art/props/chest.png")
const CHEST_OPEN_TEX = preload("res://art/props/chest_open.png")
const PEDESTAL_TEX = preload("res://art/props/pedestal.png")
const ALTAR_TEX = preload("res://art/props/altar.png")

# Товары магазина (цена в душах)
const ITEMS := {
	"heal": {"name": "Лечение", "cost": 3, "color": Color(0.3, 0.9, 0.4)},
	"damage": {"name": "+Урон", "cost": 8, "color": Color(1.0, 0.6, 0.1)},
	"speed": {"name": "+Скорость", "cost": 5, "color": Color(0.3, 0.6, 1.0)},
	"maxhp": {"name": "+Макс. HP", "cost": 6, "color": Color(1.0, 0.4, 0.6)},
}
const STORY_TEXT := "Сюжетная комната (заготовка).\nЗдесь будет сцена."

var room
var data
var _dialog: Control


func setup(room_node, room_data) -> void:
	room = room_node
	data = room_data
	var path: String = CUSTOM_DIR + data.kind + ".tscn"
	if ResourceLoader.exists(path):
		var scene = load(path).instantiate()
		add_child(scene)
		if scene.has_method("setup"):
			scene.setup(room, data)
		return
	match data.kind:
		"chest":
			_chest()
		"shop":
			_shop()
		"story":
			_story()


# ---------- Сундук ----------
func _chest() -> void:
	var pos := RoomLayout.CENTER
	var opened: bool = data.state.get("opened", false)
	var spr := _sprite(CHEST_OPEN_TEX if opened else CHEST_TEX, pos)
	_solid(pos + Vector2(0, 2), Vector2(12, 8))
	_label("Сундук", pos + Vector2(0, 14))
	if not opened:
		var area := _trigger(pos, Vector2(30, 30))
		area.body_entered.connect(_open_chest.bind(spr, area))


func _open_chest(body, spr: Sprite2D, area: Area2D) -> void:
	if not body.is_in_group("player") or data.state.get("opened", false):
		return
	data.state["opened"] = true
	spr.texture = CHEST_OPEN_TEX
	area.set_deferred("monitoring", false)
	Sfx.play("pickup")
	room.spawn_pickup.call_deferred("heal", RoomLayout.CENTER + Vector2(-16, 28))
	room.spawn_pickup.call_deferred(["damage", "speed", "maxhp"].pick_random(), RoomLayout.CENTER + Vector2(16, 28))


# ---------- Магазин ----------
func _shop() -> void:
	var sold: Array = data.state.get("sold", [])
	data.state["sold"] = sold
	var rng := RandomNumberGenerator.new()
	rng.seed = data.seed
	var kinds: Array = ITEMS.keys()
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = t
	var door_side := 0
	for s in 4:
		if data.doors[s]:
			door_side = s
	var c := RoomLayout.CENTER
	var row_y := c.y + 64.0 if door_side == 0 else c.y - 64.0   # подальше от прохода от двери
	for i in 3:
		var kind: String = kinds[i]
		var pos := Vector2(c.x - 40.0 + 40.0 * i, row_y)
		_sprite(PEDESTAL_TEX, pos)
		var item := ColorRect.new()
		item.color = ITEMS[kind]["color"]
		item.size = Vector2(8, 8)
		item.position = pos + Vector2(-4, -14)
		add_child(item)
		var lbl := _label("%s\n%d душ" % [ITEMS[kind]["name"], ITEMS[kind]["cost"]], pos + Vector2(0, 14))
		if sold.has(i):
			item.visible = false
			lbl.text = "Продано"
		else:
			var area := _trigger(pos, Vector2(20, 20))
			area.body_entered.connect(_buy.bind(i, kind, item, lbl))
	_label("Магазин", Vector2(c.x, 44))


# Заготовка: покупка происходит при касании пьедестала
func _buy(body, idx: int, kind: String, item: ColorRect, lbl: Label) -> void:
	if not body.is_in_group("player"):
		return
	var sold: Array = data.state["sold"]
	if sold.has(idx):
		return
	var cost: int = ITEMS[kind]["cost"]
	if Meta.souls < cost:
		lbl.text = "Нужно %d душ" % cost
		return
	Meta.add_souls(-cost)
	body.apply_item(kind)
	sold.append(idx)
	item.visible = false
	lbl.text = "Продано"


# ---------- Сюжетная комната ----------
func _story() -> void:
	var pos := RoomLayout.CENTER
	_sprite(ALTAR_TEX, pos)
	_solid(pos + Vector2(0, 2), Vector2(14, 10))
	_label("Сюжет", pos + Vector2(0, 16))
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var box := ColorRect.new()
	box.color = Color(0, 0, 0, 0.75)
	box.position = Vector2(30, 196)
	box.size = Vector2(420, 56)
	box.visible = false
	layer.add_child(box)
	var txt := Label.new()
	txt.text = STORY_TEXT
	txt.position = Vector2(10, 8)
	box.add_child(txt)
	_dialog = box
	var area := _trigger(pos, Vector2(48, 48))
	area.body_entered.connect(_story_toggle.bind(true))
	area.body_exited.connect(_story_toggle.bind(false))


func _story_toggle(body, show_it: bool) -> void:
	if not body.is_in_group("player"):
		return
	_dialog.visible = show_it
	if show_it:
		data.state["seen"] = true


# ---------- Помощники ----------
func _sprite(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	add_child(s)
	return s


func _solid(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	body.add_child(cs)
	add_child(body)


func _trigger(pos: Vector2, size: Vector2) -> Area2D:
	var a := Area2D.new()
	a.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	a.add_child(cs)
	add_child(a)
	return a


func _label(text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(72, 10)
	l.position = pos - Vector2(36, 0)
	add_child(l)
	return l
