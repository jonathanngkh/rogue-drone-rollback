extends CharacterBody3D

@export var speed: float = 30.0
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
var direction : Vector3


func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player:
		direction = (player.global_transform.origin - global_transform.origin).normalized()
		velocity = direction * speed
		move_and_slide()
