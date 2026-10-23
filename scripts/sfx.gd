extends Node

const SOUNDS = {
	"swing": preload("res://audio/swing.wav"),
	"throw": preload("res://audio/throw.wav"),
	"hit": preload("res://audio/hit.wav"),
	"hurt": preload("res://audio/hurt.wav"),
	"pickup": preload("res://audio/pickup.wav"),
	"door": preload("res://audio/door.wav"),
	"step_tatami": preload("res://audio/step_tatami.wav"),
	"step_boards": preload("res://audio/step_boards.wav"),
	"step_stone": preload("res://audio/step_stone.wav"),
	"whisper1": preload("res://audio/whisper1.wav"),
	"whisper2": preload("res://audio/whisper2.wav"),
	"whisper3": preload("res://audio/whisper3.wav"),
	"reveal": preload("res://audio/reveal.wav"),
	"creak": preload("res://audio/creak.wav"),
	"scrape": preload("res://audio/scrape.wav"),
	"snap": preload("res://audio/snap.wav"),
	"clack": preload("res://audio/clack.wav"),
	"bell": preload("res://audio/bell.wav")
}

var ambient_player: AudioStreamPlayer
var surface := "tatami"   # на чём стоит игрок: tatami / boards / stone (ставит main.gd)

func _ready():
	ambient_player = AudioStreamPlayer.new()
	ambient_player.stream = preload("res://audio/ambient.wav")
	ambient_player.volume_db = -10.0
	add_child(ambient_player)

func start_ambient():
	if not ambient_player.playing:
		ambient_player.play()

func play(sound_name, volume_db := -6.0, pitch := 1.0):
	var p := AudioStreamPlayer.new()
	p.stream = SOUNDS[sound_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# Шаг игрока: звук зависит от поверхности, чуть плавают громкость и высота
func step():
	play("step_" + surface, -17.0 + randf_range(-2.0, 2.0), randf_range(0.88, 1.12))


# Шёпот «из комнаты»: позиционный звук рядом с игроком, не из конкретного места
func whisper(pos: Vector2, volume_db := -13.0):
	var p := AudioStreamPlayer2D.new()
	p.stream = SOUNDS["whisper" + str(randi_range(1, 3))]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.85, 1.1)
	p.max_distance = 420.0
	add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

func hit():
	play("hit")
	hit_stop(0.05)

func hit_stop(duration):
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
