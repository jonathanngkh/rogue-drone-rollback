extends AudioStreamPlayer3D
class_name PlayRandomStream3D

@export var sounds: Array[AudioStream] = []

static var idx := 0

func _ready() -> void:
	if autoplay:
		play_random()

func play_random() -> void:
	stream = sounds.pick_random()
	play()
