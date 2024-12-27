extends Control

@export var score_label: Label
@export var effect_label: Label
@export var score_manager: ScoreManager
var drone

func _ready():
	GameEvents.on_own_brawler_spawn.connect(func(b): drone = b)

func _process(_delta):
	if not drone:
		visible = false
	else:
		visible = true
		score_label.text = str(score_manager.get_score(drone.player_id))
