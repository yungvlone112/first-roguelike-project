extends Node

const SAVE_PATH := "user://save.json"
const NAMES = {"hp": "Здоровье +1", "dmg": "Урон +1", "speed": "Скорость +5"}
const BASE_COST = {"hp": 5, "dmg": 8, "speed": 4}

var souls := 0
var levels := {"hp": 0, "dmg": 0, "speed": 0}

func _ready():
	load_game()

func level(kind):
	return levels[kind]

func cost(kind):
	return BASE_COST[kind] * (levels[kind] + 1)

func buy(kind) -> bool:
	var c = cost(kind)
	if souls < c:
		return false
	souls -= c
	levels[kind] += 1
	save_game()
	return true

func add_souls(n):
	souls += n
	save_game()

func save_game():
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"souls": souls, "levels": levels}))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	souls = int(data.get("souls", 0))
	var lv = data.get("levels", {})
	for k in levels:
		levels[k] = int(lv.get(k, 0))
