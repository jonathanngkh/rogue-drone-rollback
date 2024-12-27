extends RigidBody3D

@export var lifetime = 5.0 # Time in seconds before the bullet disappears
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	# Set a timer to destroy the bullet after its lifetime
	set_timer()
	body_entered.connect(_on_collision)
	
func set_timer() -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	timer.start()

func _on_timeout() -> void:
	queue_free() # Remove the bullet after lifetime ends

func _on_collision(body: Node) -> void:
	print("HIT")
	if body.is_in_group("bullseye"):  # Assume target is in "bullseye" group
		body.hit_by_bullet()
		queue_free() # Destroy the bullet
