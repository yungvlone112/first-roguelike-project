extends Control

var info: Label
var buttons := {}

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.18)
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.position = Vector2(110, 30)
	box.custom_minimum_size = Vector2(260, 0)
	add_child(box)
	var title := Label.new()
	title.text = "Додзё: улучшения"
	box.add_child(title)
	info = Label.new()
	box.add_child(info)
	for kind in ["hp", "dmg", "speed"]:
		var b := Button.new()
		b.pressed.connect(_on_buy.bind(kind))
		box.add_child(b)
		buttons[kind] = b
	var start := Button.new()
	start.text = "Начать забег"
	start.pressed.connect(_on_start)
	box.add_child(start)
	refresh()

func refresh():
	info.text = "Души: %d" % Meta.souls
	for kind in buttons:
		buttons[kind].text = "%s (ур. %d): %d душ" % [Meta.NAMES[kind], Meta.level(kind), Meta.cost(kind)]

func _on_buy(kind):
	if Meta.buy(kind):
		refresh()

func _on_start():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
