extends Control

@export var score_label: Label
@export var effect_label: Label
@export var score_manager: ScoreManager
var drone : DroneController

func _ready() -> void:
	GameEvents.on_own_brawler_spawn.connect(func(b: DroneController) -> void: drone = b)

func _process(_delta: float) -> void:
	if not drone:
		visible = false
	else:
		visible = true
		score_label.text = str(score_manager.get_score(drone.player_id))
