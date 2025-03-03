extends CharacterBody3D

@export var speed: float = 30.0
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
var direction : Vector3
var is_alive : bool = true
var explosion_index : int = 0

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player:
		if is_alive:
			direction = (player.global_transform.origin - global_transform.origin).normalized()
			velocity = direction * speed
			move_and_slide()

func explode() -> void:
	$ExplosionGroup.get_children()[explosion_index].restart()
	explosion_index += 1
	if explosion_index > 4:
		explosion_index = 0
		
		
	#$ExplosionParticles.restart()
	if is_alive:
		is_alive = false
		#$CSGBox3D.visible = false
		$TrailParticles.visible = false
