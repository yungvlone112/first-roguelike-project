extends Node2D
## Заготовки особых комнат: магазин, сундук, сюжетная. Пока на плейсхолдерах.
##
## Свои комнаты: положи сцену res://scenes/rooms/shop.tscn (или chest.tscn / story.tscn) —
## она подставится вместо заготовки. Если у корня сцены есть метод setup(room, data),
## он будет вызван (room — узел комнаты, data — её RoomData, data.state хранит состояние).

const KINDS := ["shop", "chest", "story"]
const RoomLayout = preload("res://scripts/room_layout.gd")
const CUSTOM_DIR := "res://scenes/rooms/"

const MIMIC = preload("res://scripts/mimic.gd")
const MIMIC_CHANCE := 0.35
const MERCHANT_TEX = preload("res://art/merchant.png")
const LIGHT = preload("res://scripts/light.gd")
const MERCHANT_LINES := ["Души... три души.", "Всё имеет цену.", "Бери, пока темно.",
	"Ты ещё жив? Любопытно.", "Тише. Они слушают."]
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
# Иногда сундук оказывается мимиком: решается один раз по seed комнаты и запоминается в data.state
func _chest() -> void:
	var pos := RoomLayout.CENTER
	var opened: bool = data.state.get("opened", false)
	if not data.state.has("mimic"):
		var rng := RandomNumberGenerator.new()
		rng.seed = data.seed
		data.state["mimic"] = rng.randf() < MIMIC_CHANCE
	var spr := _sprite(CHEST_OPEN_TEX if opened else CHEST_TEX, pos)
	var body := _solid(pos + Vector2(0, 4), Vector2(28, 14))
	_label("Сундук", pos + Vector2(0, 18))
	if not opened:
		var area := _trigger(pos, Vector2(48, 44))
		area.body_entered.connect(_open_chest.bind(spr, area, body))


func _open_chest(body_node, spr: Sprite2D, area: Area2D, body: StaticBody2D) -> void:
	if not body_node.is_in_group("player") or data.state.get("opened", false):
		return
	area.set_deferred("monitoring", false)
	if data.state.get("mimic", false):
		_wake_mimic(spr, body)
		return
	data.state["opened"] = true
	spr.texture = CHEST_OPEN_TEX
	Sfx.play("pickup")
	room.spawn_pickup.call_deferred("heal", RoomLayout.CENTER + Vector2(-16, 32))
	room.spawn_pickup.call_deferred(["damage", "speed", "maxhp"].pick_random(), RoomLayout.CENTER + Vector2(16, 32))


# Мимик: сундук исчезает, на его месте зубастая тварь; за победу — награда как из настоящего сундука
func _wake_mimic(spr: Sprite2D, body: StaticBody2D) -> void:
	spr.queue_free()
	body.queue_free()
	var m = MIMIC.new()
	m.position = RoomLayout.CENTER
	m.died.connect(_on_mimic_died)
	room.spawn_extra_enemy.call_deferred(m)


func _on_mimic_died() -> void:
	data.state["opened"] = true
	room.spawn_pickup.call_deferred("heal", RoomLayout.CENTER + Vector2(-16, 12))
	room.spawn_pickup.call_deferred(["damage", "speed", "maxhp"].pick_random(), RoomLayout.CENTER + Vector2(16, 12))
	room.spawn_pickup.call_deferred(["damage", "speed", "maxhp"].pick_random(), RoomLayout.CENTER + Vector2(0, 30))


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
		item.position = pos + Vector2(-4, -26)
		add_child(item)
		var lbl := _label("%s\n%d душ" % [ITEMS[kind]["name"], ITEMS[kind]["cost"]], pos + Vector2(0, 16))
		if sold.has(i):
			item.visible = false
			lbl.text = "Продано"
		else:
			var area := _trigger(pos, Vector2(20, 20))
			area.body_entered.connect(_buy.bind(i, kind, item, lbl))
	_label("Магазин", Vector2(c.x, 44))
	_merchant(Vector2(c.x, row_y + (42.0 if door_side == 0 else -42.0)))


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


# ---------- Призрак-торговец ----------
# Покачивается, светит холодным светом; когда игрок подходит, роняет реплику и шепчет.
func _merchant(pos: Vector2) -> void:
	var holder := Node2D.new()
	holder.position = pos
	add_child(holder)
	var spr := Sprite2D.new()
	spr.texture = MERCHANT_TEX
	spr.modulate = Color(1, 1, 1, 0.9)
	holder.add_child(spr)
	var tw := create_tween().set_loops()
	tw.tween_property(spr, "position:y", -3.0, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "position:y", 0.0, 1.3).set_trans(Tween.TRANS_SINE)
	var glow := PointLight2D.new()
	glow.set_script(LIGHT)
	glow.set("light_radius", 70.0)
	glow.set("tint", Color(0.6, 0.7, 1.0))
	glow.position = Vector2(0, -8)
	holder.add_child(glow)
	_solid(pos + Vector2(0, 14), Vector2(16, 12))
	var line := _label("", pos + Vector2(0, -44))
	line.custom_minimum_size = Vector2(160, 10)   # реплики длиннее обычной подписи
	line.position = pos + Vector2(-80, -44)
	var area := _trigger(pos, Vector2(120, 100))
	area.body_entered.connect(_merchant_greet.bind(line, pos))


func _merchant_greet(body, line: Label, pos: Vector2) -> void:
	if not body.is_in_group("player"):
		return
	line.text = MERCHANT_LINES.pick_random()
	Sfx.play("bell", -14.0)
	Sfx.whisper(pos, -16.0)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(line):
		line.text = ""


# ---------- Сюжетная комната ----------
func _story() -> void:
	var pos := RoomLayout.CENTER
	_sprite(ALTAR_TEX, pos)
	_solid(pos + Vector2(0, 6), Vector2(28, 16))
	_label("Сюжет", pos + Vector2(0, 22))
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
	var area := _trigger(pos, Vector2(64, 64))
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


func _solid(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	body.add_child(cs)
	add_child(body)
	return body


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
