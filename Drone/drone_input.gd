extends BaseNetInput
class_name DroneInput

#@onready var _player: Node3D = get_parent()

var throttle_input : float
var pitch_input : float
var roll_input : float
var yaw_input : float
var is_firing : bool
var is_just_pressed_firing : bool
var is_just_released_firing : bool
var is_zooming : bool = false
var toggle_angle_mode : bool

func _gather() -> void:
	# Throttle
	throttle_input = Input.get_action_strength("throttle_forward")
	# Pitch
	pitch_input = Input.get_action_strength("pitch_backward") - Input.get_action_strength("pitch_forward")
	# Roll
	roll_input = Input.get_action_strength("roll_left") - Input.get_action_strength("roll_right")
	# Yaw
	yaw_input = Input.get_action_strength("yaw_left") - Input.get_action_strength("yaw_right")
	
	# Fire
	is_firing = Input.is_action_pressed("shoot")
	is_just_pressed_firing = Input.is_action_just_pressed("shoot")
	is_just_released_firing = Input.is_action_just_released("shoot")
	
	# Zoom
	is_zooming = Input.is_action_pressed("aim_down_sights")
	
	# Angle Mode
	toggle_angle_mode = Input.is_action_just_released("toggle_angle_mode")
	
	## Movement
	#movement = Vector3(
		#Input.get_axis("move_west", "move_east"),
		#Input.get_action_strength("move_jump"),
		#Input.get_axis("move_north", "move_south")
	#)
	#
	## Aim
	#aim = Vector3(
		#Input.get_axis("aim_west", "aim_east"),
		#0.0,
		#Input.get_axis("aim_north", "aim_south")
	#)
	#
	#if aim.length():
		## Prefer gamepad
		## Reset timeout for mouse motion
		#_last_mouse_input = NetworkTime.local_time - switch_time
	#elif NetworkTime.local_time - _last_mouse_input > switch_time:
		## Use movement if no mouse motion recently
		#aim = movement
	#elif _has_aim:
		## Use mouse raycast
		#aim = (_aim_target - _player.global_position).normalized()
	#else:
		## Fall back to mouse projected to player height
		#aim = (_projected_target - _player.global_position).normalized()
	#
	## Always aim horizontally, never up or down
	#aim.y = 0
	#aim = aim.normalized()
	#
	## Hide mouse if inactive
	#if NetworkTime.local_time - _last_mouse_input >= switch_time:
		#DisplayServer.mouse_set_mode(
			#DisplayServer.MOUSE_MODE_CONFINED_HIDDEN if _confine_mouse else DisplayServer.MOUSE_MODE_HIDDEN
		#)
	#else:
		#DisplayServer.mouse_set_mode(
			#DisplayServer.MOUSE_MODE_CONFINED if _confine_mouse else DisplayServer.MOUSE_MODE_VISIBLE
		#)
	#
	#is_firing = Input.is_action_pressed("weapon_fire")

#func _physics_process(_delta):
	#if not camera:
		#camera = get_viewport().get_camera_3d()
#
	## Aim
	#var mouse_pos = get_viewport().get_mouse_position()
	#var ray_origin = camera.project_ray_origin(mouse_pos)
	#var ray_normal = camera.project_ray_normal(mouse_pos)
	#var ray_length = 128
#
	#var space = camera.get_world_3d().direct_space_state
	#var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(
		#ray_origin, ray_origin + ray_normal * ray_length
	#))
#
	#if not hit.is_empty():
		## Aim at raycast hit
		#_aim_target = hit.position
		#_has_aim = true
	#else:
		## Project to player's height
		#var height_diff = _player.global_position.y - ray_origin.y
		#_projected_target = ray_origin + ray_normal * (height_diff / ray_normal.y)
		#_has_aim = false
