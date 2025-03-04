extends Node3D

@onready var back_camera_reference: Node3D = $"../../BackCameraReference"



func _process(delta: float) -> void:
	if back_camera_reference:
		#global_transform = back_camera_reference.transform
		global_rotation.x = back_camera_reference.global_rotation.x
		global_rotation.y = back_camera_reference.global_rotation.y
		global_rotation.z = -back_camera_reference.global_rotation.z
		global_position = back_camera_reference.global_position
