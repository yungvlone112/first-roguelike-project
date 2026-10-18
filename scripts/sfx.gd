extends Node

const SOUNDS = {
	"swing": preload("res://audio/swing.wav"),
	"throw": preload("res://audio/throw.wav"),
	"hit": preload("res://audio/hit.wav"),
	"hurt": preload("res://audio/hurt.wav"),
	"pickup": preload("res://audio/pickup.wav"),
	"door": preload("res://audio/door.wav")
}

var ambient_player: AudioStreamPlayer

func _ready():
	ambient_player = AudioStreamPlayer.new()
	ambient_player.stream = preload("res://audio/ambient.wav")
	ambient_player.volume_db = -19.0
	add_child(ambient_player)

func start_ambient():
	if not ambient_player.playing:
		ambient_player.play()

func play(sound_name, volume_db := -6.0):
	var p := AudioStreamPlayer.new()
	p.stream = SOUNDS[sound_name]
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
