extends Node2D
## Оформление комнаты по маске: пол из вариантов тайлов, накладки на стены,
## декор (без коллизии) и препятствия (с коллизией). Всё детерминировано seed'ом комнаты,
## поэтому при возвращении в комнату она выглядит так же.

const RoomLayout = preload("res://scripts/room_layout.gd")
const LIGHT = preload("res://scripts/light.gd")

const TILE := 16
const OBSTACLE_GAP := 24.0   # минимальный просвет между препятствиями (герой 16 px в ширину)
const ART := "res://art/"

# --- Темы: какие тайлы и предметы встречаются (число = вес) ---
# mats: пол из циновок татами (атлас tiles/tatami_atlas.png: 4x2 тайла на циновку, 2 варианта)
# floor: запасной вариант — случайные тайлы целиком (если mats нет)
# overlays: прозрачные накладки поверх пола ("" = без накладки)
const THEMES := {
	"tatami": {
		"mats": true,
		"overlays": {
			"": 88.0,
			"tiles/floor_scratch.png": 3.5,
			"tiles/floor_crack.png": 3.5,
			"tiles/floor_stain.png": 2.5,
			"tiles/floor_mold.png": 1.5,
			"tiles/floor_blood.png": 0.8,
		},
		"wall_decals": {
			"tiles/wall_plaster.png": 4.0,
			"tiles/wall_mold.png": 3.0,
			"tiles/wall_ofuda.png": 2.0,
			"tiles/wall_shoji.png": 2.0,
			"tiles/wall_shoji_torn.png": 1.0,
		},
		"decor": {"sandals": 3.0, "plate": 3.0, "bones": 2.0, "candle": 2.0,
			"charms": 2.0, "kokeshi": 1.0, "puddle": 3.0},
		"solid": {"pillar": 3.0, "table": 3.0, "screen": 3.0, "lantern": 2.0,
			"rubble": 2.0, "well": 1.0},
	},
	# Заготовки особых комнат: только пол-татами, без декора и препятствий
	"plain": {"mats": true},
	# Пример второй темы для других этажей
	"boards": {
		"floor": {"tiles/floor_boards.png": 100.0},
		"overlays": {"": 90.0, "tiles/floor_crack.png": 4.0, "tiles/floor_stain.png": 3.0,
			"tiles/floor_blood.png": 1.0},
		"wall_decals": {"tiles/wall_plaster.png": 4.0, "tiles/wall_mold.png": 3.0,
			"tiles/wall_ofuda.png": 2.0},
		"decor": {"sandals": 2.0, "plate": 2.0, "bones": 3.0, "candle": 3.0,
			"charms": 2.0, "puddle": 2.0},
		"solid": {"pillar": 4.0, "table": 2.0, "screen": 2.0, "lantern": 2.0,
			"rubble": 3.0},
	},
}

# --- Каталог предметов ---
# place: any (где угодно) / wall (только у стены)
# solid: прямоугольник коллизии внутри спрайта (px); без него предмет проходимый
# light: свет предмета (смещение внутри спрайта, радиус, цвет)
const PROPS := {
	"sandals": {"tex": "props/sandals.png", "place": "any"},
	"plate": {"tex": "props/plate.png", "place": "any"},
	"bones": {"tex": "props/bones.png", "place": "any"},
	"charms": {"tex": "props/charms.png", "place": "any"},
	"puddle": {"tex": "props/puddle.png", "place": "any"},
	"kokeshi": {"tex": "props/kokeshi.png", "place": "wall"},
	"candle": {"tex": "props/candle.png", "place": "any",
		"light": {"offset": Vector2(8, 4), "radius": 52.0, "tint": Color(1.0, 0.8, 0.55)}},
	"cobweb": {"tex": "props/cobweb.png", "place": "any"},
	# Крупные предметы (размер кратен 16 px): спрайт 16x32, коллизия только у основания
	"pillar": {"tex": "props/pillar.png", "solid": Rect2(2, 20, 12, 11)},
	"table": {"tex": "props/table.png", "solid": Rect2(5, 7, 38, 19)},
	"screen": {"tex": "props/screen.png", "solid": Rect2(1, 8, 46, 20)},
	"rubble": {"tex": "props/rubble.png", "solid": Rect2(2, 4, 28, 11)},
	"well": {"tex": "props/well.png", "solid": Rect2(2, 10, 28, 18)},
	"lantern": {"tex": "props/lantern.png", "solid": Rect2(3, 18, 10, 13),
		"light": {"offset": Vector2(8, 12), "radius": 96.0, "tint": Color(1.0, 0.85, 0.6)}},
}

const SPECIAL_KINDS := ["shop", "chest", "story"]
# Насколько вероятен «опасный» пол на k-м тайле от двери босса внутрь комнаты
const DANGER_CHANCE := [1.0, 0.9, 0.75, 0.55, 0.35, 0.15]

var floor_sprite: Sprite2D
var blocked: Array[Rect2] = []    # коллизии препятствий (для навигации и спавна)
var taken: Array[Rect2] = []      # всё занятое спрайтами (чтобы декор не накладывался)

var _layout
var _rng := RandomNumberGenerator.new()
var _reserved: Array[Rect2] = []     # проходы от дверей к центру: тут препятствий не бывает
var _keep_clear: Array[Rect2] = []   # центр (награды) и точки входа: тут нет и декора
var _danger := {}                    # Vector2i клетки -> глубина от двери босса
var _tex_cache := {}
var _img_cache := {}


func build(layout, data, theme_name := "tatami", floor_num := 1, boss_side := -1) -> void:
	_layout = layout
	_rng.seed = data.seed
	var special: bool = SPECIAL_KINDS.has(data.kind)
	if special:
		theme_name = "plain"
	var theme: Dictionary = THEMES.get(theme_name, THEMES["tatami"])
	_make_reserved(data.doors)
	_danger = _danger_cells(boss_side)
	_build_walls()
	_build_floor(theme)
	if special:
		return
	_place_wall_decals(theme)
	# Комната примерно вдвое больше прежней, предметов тоже больше
	var count := _rng.randi_range(4, 6 + mini(floor_num, 3))
	if data.kind == "boss":
		count = _rng.randi_range(1, 3)
	elif data.kind == "start":
		count = _rng.randi_range(2, 4)
	_place_obstacles(theme, count)
	_place_decor(theme, _rng.randi_range(14, 22))
	_place_corner_webs()
	if boss_side >= 0:
		_place_danger_marks(boss_side)


# Случайная свободная точка на полу, не ближе min_dist к avoid (для врагов)
func random_enemy_point(avoid: Vector2, min_dist := 110.0) -> Vector2:
	for i in 80:
		var cx := randi_range(1, RoomLayout.COLS - 2)
		var cy := randi_range(1, RoomLayout.ROWS - 2)
		if not _layout.is_floor(cx, cy):
			continue
		var p := Vector2(cx, cy) * TILE + Vector2(8, 8) + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if p.distance_to(avoid) < min_dist:
			continue
		if _hits_any(Rect2(p - Vector2(10, 10), Vector2(20, 20)), blocked):
			continue
		return p
	return RoomLayout.CENTER


# ---------- Резервы: гарантированный проход от каждой двери к центру ----------
func _make_reserved(doors: Array) -> void:
	var c := RoomLayout.CENTER
	var sz := RoomLayout.SIZE
	_reserved = [Rect2(c.x - 56, c.y - 40, 112, 80)]
	_keep_clear = [Rect2(c.x - 60, c.y - 32, 120, 64)]
	if doors[0]:
		_reserved.append(Rect2(c.x - 32, 0, 64, c.y))
	if doors[1]:
		_reserved.append(Rect2(c.x, c.y - 32, sz.x - c.x, 64))
	if doors[2]:
		_reserved.append(Rect2(c.x - 32, c.y, 64, sz.y - c.y))
	if doors[3]:
		_reserved.append(Rect2(0, c.y - 32, c.x, 64))
	for side in 4:
		if doors[side]:
			var s: Vector2 = RoomLayout.SPAWNS[side]
			_keep_clear.append(Rect2(s - Vector2(24, 24), Vector2(48, 48)))


# ---------- Пол ----------
# Циновки 4x2 тайла, уложены «кирпичной» кладкой: каждый второй ряд сдвинут на пол-циновки
func _mat_region(gx: int, gy: int) -> Rect2i:
	var row := floori((gy - RoomLayout.TOP) / 2.0)
	var ty := posmod(gy - RoomLayout.TOP, 2)
	var off := posmod(row, 2) * 2
	var tx := posmod(gx - 1 + off, 4)
	var mx := floori((gx - 1 + off) / 4.0)
	var variant := posmod(mx * 7 + row * 13, 2)
	return Rect2i(tx * TILE, (variant * 2 + ty) * TILE, TILE, TILE)


func _build_floor(theme: Dictionary) -> void:
	var img := Image.create(RoomLayout.COLS * TILE, RoomLayout.ROWS * TILE, false, Image.FORMAT_RGBA8)
	var use_mats: bool = theme.get("mats", false)
	var atlas: Image = _image(ART + "tiles/tatami_atlas.png") if use_mats else null
	var rect := Rect2i(0, 0, TILE, TILE)
	for gy in RoomLayout.ROWS:
		for gx in RoomLayout.COLS:
			if not _layout.is_floor(gx, gy):
				continue
			var dst := Vector2i(gx * TILE, gy * TILE)
			if use_mats:
				img.blit_rect(atlas, _mat_region(gx, gy), dst)
			else:
				img.blit_rect(_image(ART + _pick(theme["floor"])), rect, dst)
			if theme.has("overlays"):
				var ov: String = _pick(theme["overlays"])
				if ov != "":
					img.blend_rect(_image(ART + ov), rect, dst)
			var key := Vector2i(gx, gy)
			if _danger.has(key) and _rng.randf() < DANGER_CHANCE[_danger[key]]:
				img.blend_rect(_image(ART + "tiles/floor_danger.png"), rect, dst)
	_bake_shadows(img)
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.z_index = -1
	add_child(spr)
	floor_sprite = spr


# Тень от стен прямо в картинке пола: сверху сильнее (стена высокая), по бокам слабее
func _bake_shadows(img: Image) -> void:
	for gy in RoomLayout.ROWS:
		for gx in RoomLayout.COLS:
			if not _layout.is_floor(gx, gy):
				continue
			var ox := gx * TILE
			var oy := gy * TILE
			if gy > 0 and not _layout.is_floor(gx, gy - 1):
				for k in 8:
					_darken_row(img, ox, oy + k, 0.45 + 0.55 * k / 8.0)
			if gx > 0 and not _layout.is_floor(gx - 1, gy):
				for k in 4:
					_darken_col(img, ox + k, oy, 0.7 + 0.3 * k / 4.0)
			if gx < RoomLayout.COLS - 1 and not _layout.is_floor(gx + 1, gy):
				for k in 4:
					_darken_col(img, ox + TILE - 1 - k, oy, 0.7 + 0.3 * k / 4.0)


func _darken_row(img: Image, x: int, y: int, f: float) -> void:
	for i in TILE:
		var c := img.get_pixel(x + i, y)
		img.set_pixel(x + i, y, Color(c.r * f, c.g * f, c.b * f, c.a))


func _darken_col(img: Image, x: int, y: int, f: float) -> void:
	for i in TILE:
		var c := img.get_pixel(x, y + i)
		img.set_pixel(x, y + i, Color(c.r * f, c.g * f, c.b * f, c.a))


# ---------- Стены ----------
# Одна картинка на все стены: «лицо» (клетка, под которой пол) — штукатурка со столбами
# через каждые 5 клеток, всё остальное — тёмная крыша (cap). Коллизии даёт room.gd.
func _build_walls() -> void:
	var img := Image.create(RoomLayout.COLS * TILE, RoomLayout.ROWS * TILE, false, Image.FORMAT_RGBA8)
	var face := _image(ART + "wall.png")
	var post := _image(ART + "tiles/wall_post.png")
	var cap := _image(ART + "tiles/wall_cap.png")
	var rect := Rect2i(0, 0, TILE, TILE)
	for gy in RoomLayout.ROWS:
		for gx in RoomLayout.COLS:
			if _layout.wall_mask[gy * RoomLayout.COLS + gx] == 0:
				continue
			var src: Image = cap
			if _layout.is_floor(gx, gy + 1):
				src = post if gx % 5 == 0 else face
			img.blit_rect(src, rect, Vector2i(gx * TILE, gy * TILE))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.z_index = -1
	add_child(spr)


# ---------- Опасность: дорожка к двери босса и черепа по бокам ----------
func _danger_cells(boss_side: int) -> Dictionary:
	var out := {}
	if boss_side < 0:
		return out
	var r: Rect2i = RoomLayout.door_edge(boss_side)
	var d: Vector2i = RoomLayout.DIR[boss_side]
	for k in DANGER_CHANCE.size():
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				out[Vector2i(x, y) - d * k] = k
	return out


func _place_danger_marks(boss_side: int) -> void:
	var r: Rect2i = RoomLayout.door_edge(boss_side)
	var flank: Array[Vector2i] = []
	if boss_side == 0 or boss_side == 2:   # горизонтальная дверь: стены слева и справа
		flank = [Vector2i(r.position.x - 1, r.position.y), Vector2i(r.end.x, r.position.y)]
	else:                                  # вертикальная: стены сверху и снизу
		flank = [Vector2i(r.position.x, r.position.y - 1), Vector2i(r.position.x, r.end.y)]
	for c in flank:
		var s := Sprite2D.new()
		s.texture = _tex(ART + "tiles/wall_danger.png")
		s.centered = false
		s.position = Vector2(c * TILE)
		add_child(s)


# ---------- Накладки на стены, обращённые к полу снизу ----------
func _place_wall_decals(theme: Dictionary) -> void:
	var cands: Array[Vector2i] = []
	for y in range(0, RoomLayout.ROWS - 1):
		for x in RoomLayout.COLS:
			if _layout.wall_mask[y * RoomLayout.COLS + x] == 1 and _layout.is_floor(x, y + 1):
				cands.append(Vector2i(x, y))
	_shuffle(cands)
	var n := mini(_rng.randi_range(7, 11), cands.size())
	for i in n:
		if cands[i].x % 5 == 0:
			continue   # на столбах накладок не бывает
		var s := Sprite2D.new()
		s.texture = _tex(ART + _pick(theme["wall_decals"]))
		s.centered = false
		s.position = Vector2(cands[i] * TILE)
		add_child(s)


# ---------- Препятствия ----------
func _place_obstacles(theme: Dictionary, count: int) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < 200:
		tries += 1
		var id := _pick(theme["solid"])
		var def: Dictionary = PROPS[id]
		var tex := _tex(ART + def["tex"])
		var size := Vector2(tex.get_size())
		var cw := int(size.x / TILE)
		var ch := int(size.y / TILE)
		var cx := _rng.randi_range(1, RoomLayout.COLS - 1 - cw)
		var cy := _rng.randi_range(1, RoomLayout.ROWS - 1 - ch)
		if not _cells_floor(cx, cy, cw, ch):
			continue
		var pos := Vector2(cx, cy) * TILE
		var sprite_rect := Rect2(pos, size)
		if _hits_any(sprite_rect, _reserved):
			continue
		var solid: Rect2 = def["solid"]
		var body_rect := Rect2(pos + solid.position, solid.size)
		var ok := true
		for b in blocked:
			if body_rect.grow(OBSTACLE_GAP).intersects(b):
				ok = false
				break
		if not ok:
			continue
		_spawn_solid(id, pos, tex, solid)
		blocked.append(body_rect)
		taken.append(sprite_rect)
		placed += 1


func _spawn_solid(id: String, pos: Vector2, tex: Texture2D, solid: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	body.add_child(spr)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = solid.size
	col.shape = shape
	col.position = solid.position + solid.size / 2.0
	body.add_child(col)
	_add_light(body, id)
	add_child(body)


# ---------- Декор ----------
func _place_decor(theme: Dictionary, count: int) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < 300:
		tries += 1
		var id := _pick(theme["decor"])
		var def: Dictionary = PROPS[id]
		var cx := _rng.randi_range(1, RoomLayout.COLS - 2)
		var cy := _rng.randi_range(1, RoomLayout.ROWS - 2)
		if not _layout.is_floor(cx, cy):
			continue
		if def["place"] == "wall" and not _touches_wall(cx, cy):
			continue
		var pos := Vector2(cx, cy) * TILE
		var rect := Rect2(pos, Vector2(TILE, TILE))
		if _hits_any(rect, _keep_clear) or _hits_any(rect, taken):
			continue
		var s := Sprite2D.new()
		s.texture = _tex(ART + def["tex"])
		s.centered = false
		s.position = pos
		add_child(s)
		_add_light(s, id)
		taken.append(rect)
		placed += 1


# Паутина в углах, где сходятся две стены (в том числе во внутренних углах Г-комнат)
func _place_corner_webs() -> void:
	var cands: Array[Vector3i] = []   # x, y, flip
	for y in range(RoomLayout.TOP, RoomLayout.ROWS - 1):
		for x in range(1, RoomLayout.COLS - 1):
			if not _layout.is_floor(x, y) or _layout.is_floor(x, y - 1):
				continue
			var w_wall: bool = not _layout.is_floor(x - 1, y)
			var e_wall: bool = not _layout.is_floor(x + 1, y)
			if w_wall:
				cands.append(Vector3i(x, y, 0))
			elif e_wall:
				cands.append(Vector3i(x, y, 1))
	_shuffle(cands)
	for i in mini(5, cands.size()):
		if _rng.randf() < 0.6:
			var s := Sprite2D.new()
			s.texture = _tex(ART + PROPS["cobweb"]["tex"])
			s.centered = false
			s.flip_h = cands[i].z == 1
			s.position = Vector2(cands[i].x, cands[i].y) * TILE
			add_child(s)


# ---------- Свет ----------
func _add_light(parent: Node2D, id: String) -> void:
	var def: Dictionary = PROPS[id]
	if not def.has("light"):
		return
	var cfg: Dictionary = def["light"]
	var l := PointLight2D.new()
	l.set_script(LIGHT)
	l.set("light_radius", cfg["radius"])
	l.set("tint", cfg["tint"])
	l.position = cfg["offset"]
	parent.add_child(l)


# ---------- Утилиты ----------
func _cells_floor(cx: int, cy: int, cw: int, ch: int) -> bool:
	for y in range(cy, cy + ch):
		for x in range(cx, cx + cw):
			if not _layout.is_floor(x, y):
				return false
	return true


func _touches_wall(cx: int, cy: int) -> bool:
	return not (_layout.is_floor(cx - 1, cy) and _layout.is_floor(cx + 1, cy)
			and _layout.is_floor(cx, cy - 1) and _layout.is_floor(cx, cy + 1))


func _hits_any(r: Rect2, list: Array) -> bool:
	for b in list:
		if r.intersects(b):
			return true
	return false


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := _rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return weights.keys()[0]


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func _image(path: String) -> Image:
	if not _img_cache.has(path):
		var img: Image = _tex(path).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_img_cache[path] = img
	return _img_cache[path]
