extends CharacterBody3D
class_name DroneController

var player_id: int = -1
var player_name: String = "":
	set(p_name):
		if p_name.length() > 24:
			p_name = p_name.substr(0, 21) + "..."
		player_name = p_name
		nametag.text = p_name
@onready var nametag: Label3D = $Nametag
@onready var drone_animation_player: AnimationPlayer = $"Pivot/drone edited origins/DroneAnimationPlayer"
@onready var bullet_scene: PackedScene = preload("res://Bullet/bullet.tscn") # Bullet scene
@onready var ray_cast: RayCast3D = $Node3D/Camera3D/RayCast3D
@onready var fpv_camera: Camera3D = $Node3D/Camera3D
@onready var laser: MeshInstance3D = $Scaler/Laser
@onready var identifier_laser: MeshInstance3D = $IdentifierLaserScaler/IdentifierLaser
@onready var you_died_overlay: TextureRect = $HUD/YouDied
@onready var engine_sound: AudioStreamPlayer = $EngineSound
@onready var hit_marker_sound: AudioStreamPlayer = $HitMarkerSound
@onready var laser_sound: AudioStreamPlayer = $LaserSound
@onready var laser_hum_sound: AudioStreamPlayer = $LaserHumSound
@onready var crosshair: TextureRect = $HUD/Crosshair
@onready var hitmarker: TextureRect = $HUD/Hitmarker
@onready var red_indicator: Node3D = $"Pivot/drone edited origins/root/node_id273/RedIndicator"

@export var health := 5
@export var bullet_speed = 60.0 # Bullet speed

@export var ramp_factor: float = 2.0 # Exponent for the exponential ramp
@export var max_thrust = 100.0 # Maximum upward force (throttle)
@export var max_yaw_speed = 5.0 # Maximum rotational speed for yaw
@export var max_pitch_speed = 3.0 # Maximum rotational speed for pitch
@export var max_roll_speed = 3.0 # Maximum rotational speed for roll

@export var friction_coefficient = 10 # Adjust this value to tune the friction intensity
@export var drag_coefficient = 0.1 # Adjust this value to tune drag intensity
@export var angular_drag_coefficient = 0.1 # Adjust this to tune angular drag intensity

 # Reduce sensitivity to 50% while zoomed in
@export var zoom_sensitivity_multiplier: float = 0.3
@export var default_fov: float = 60.0  # Normal field of view
@export var zoom_fov: float = 20.0     # Zoomed-in field of view
@export var zoom_speed: float = 15.0   # How fast the zoom transitions

# Pitch/Volume range for engine whine
@export var min_pitch = 0.9  # Pitch at zero throttle
@export var max_pitch = 1.4  # Pitch at full throttle
@export var min_volume = -10  # Volume (dB) at zero throttle
@export var max_volume = -5  # Volume (dB) at full throttle

# Variables to track angular velocities
var pitch_velocity: float = 0.0
var yaw_velocity: float = 0.0
var roll_velocity: float = 0.0

var device_index : int
var string_p2 : String = ""

func _ready() -> void:
	add_to_group("player")
	laser.get_active_material(0).albedo_color.a = 0.0
	#identifier_laser.get_active_material(0).albedo_color.a = 0.0
	if name == "Drone":
		device_index = 0
	elif name == "DroneP2":
		device_index = 1
		string_p2 = "_p2"
	Input.stop_joy_vibration(device_index)
	$MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())
	print("%s multi auth is %s" % [name, $MultiplayerSynchronizer.get_multiplayer_authority()])
	fpv_camera.current = false
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		fpv_camera.current = true
	else:
		$HUD.visible = false
		
		


func _physics_process(delta: float) -> void:
	$HUD/FPS.text = "FPS: " + str(Engine.get_frames_per_second())
	#if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id() or owner.name != "MainNetworking":
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		if Input.is_action_just_pressed("debug"):
			print('device index: %s' % device_index)
			print("muid: " + str(multiplayer.get_unique_id()))
			print("name: " + name)
			print("msync mu auth: " + str($MultiplayerSynchronizer.get_multiplayer_authority()))
			print('youdied owner: ' + you_died_overlay.owner.name)
		# Handle ADS
		#if device_index == 0:
		# Get throttle input (left stick Y-axis)
		var throttle_input = Input.get_action_strength("throttle_forward" + string_p2)
		# Get pitch input (right stick Y-axis)
		var pitch_input = Input.get_action_strength("pitch_backward" + string_p2) - Input.get_action_strength("pitch_forward" + string_p2)
		# Get roll input (right stick X-axis)
		var roll_input = Input.get_action_strength("roll_left" + string_p2) - Input.get_action_strength("roll_right" + string_p2)
		# Get yaw input (left stick X-axis)
		var yaw_input = Input.get_action_strength("yaw_left" + string_p2) - Input.get_action_strength("yaw_right" + string_p2)
		
		if Input.is_action_pressed("aim_down_sights" + string_p2): # Check if L1 is held
			fpv_camera.fov = lerp(fpv_camera.fov, zoom_fov, zoom_speed * delta)
		else:
			fpv_camera.fov = lerp(fpv_camera.fov, default_fov, zoom_speed * delta)
		
		if Input.is_action_just_pressed("aim_down_sights" + string_p2):
			max_pitch_speed *= zoom_sensitivity_multiplier
			max_roll_speed *= zoom_sensitivity_multiplier
			max_yaw_speed *= zoom_sensitivity_multiplier
			
		if Input.is_action_just_released("aim_down_sights" + string_p2):
			max_pitch_speed *= 1/zoom_sensitivity_multiplier
			max_roll_speed *= 1/zoom_sensitivity_multiplier
			max_yaw_speed *= 1/zoom_sensitivity_multiplier
			
		if Input.is_action_just_pressed("shoot" + string_p2):
			laser_sound.play()
			laser_hum_sound.play()
			
		if Input.is_action_pressed("shoot" + string_p2):
			#shoot_bullet()
			shoot_laser()
			laser.get_active_material(0).albedo_color.a = 1.0
			identifier_laser.get_active_material(0).albedo_color.a = 1.0

		if Input.is_action_just_released("shoot" + string_p2):
			laser_sound.stop()
			laser_hum_sound.stop()
			var laser_material = laser.get_active_material(0)
			var tween = create_tween()
			tween.tween_property(laser_material, "albedo_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			var identifier_laser_material = identifier_laser.get_active_material(0)
			var tween2 = create_tween()
			tween2.tween_property(identifier_laser_material, "albedo_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

		# Add the gravity.
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			apply_friction(delta)
			reset_orientation_to_neutral() # can use this for ez hover
		
		# Apply thrust
		apply_thrust(throttle_input, delta)
		
		# Apply angular drag to reduce angular velocities
		apply_angular_drag(delta)
		
		# Apply yaw
		apply_yaw(yaw_input, delta)

		# Apply roll
		apply_roll(roll_input, delta)
		
		# Apply pitch
		apply_pitch(pitch_input, delta)
		
		# Adjust engine sound based on throttle input
		update_engine_sound(throttle_input, yaw_input, pitch_input, roll_input)
		

		# Play animation
		drone_animation_player.play("throttle_forward")
		drone_animation_player.speed_scale = 2 + throttle_input * 3
		# add yaw,pitch,roll animations also

		# Move using built-in velocity
		move_and_slide()


func apply_exponential_ramp(input_value: float) -> float:
	# Apply the exponential curve: input^ramp_factor
	return sign(input_value) * pow(abs(input_value), ramp_factor)

func apply_thrust(throttle_input: float, delta: float) -> void:
	throttle_input = apply_exponential_ramp(throttle_input)
	# Get the thrust direction (normal to the drone's plane)
	var thrust_direction = transform.basis.y.normalized() # Local "up" direction relative to the drone

	# Scale the thrust direction by the input and maximum thrust
	var thrust_force = thrust_direction * throttle_input * max_thrust

	# Apply thrust directly to velocity, scaled by delta
	if throttle_input > 0:
		velocity += thrust_force * delta

	# Introduce drag to counter excessive acceleration
	apply_drag(delta)


func apply_drag(delta: float) -> void:
	# Drag reduces velocity proportionally to its current magnitude
	var drag_force = velocity * drag_coefficient * delta
	velocity -= drag_force


# Apply yaw rotation
func apply_yaw(yaw_input: float, delta: float) -> void:
	yaw_input = apply_exponential_ramp(yaw_input)
	# Apply yaw rotation around the Y-axis (horizontal plane)
	yaw_velocity = yaw_input * max_yaw_speed * delta
	rotate_object_local(Vector3(0, 1, 0), yaw_velocity)

 # Apply pitch rotation and thrust
func apply_pitch(pitch_input: float, delta: float) -> void:
	pitch_input = apply_exponential_ramp(pitch_input)
	# Apply pitch rotation around the drone's local X-axis
	pitch_velocity = pitch_input * max_pitch_speed * delta
	
	# Rotate the drone using its local X-axis
	rotate_object_local(Vector3(1, 0, 0), pitch_velocity)


func apply_roll(roll_input: float, delta: float) -> void:
	roll_input = apply_exponential_ramp(roll_input)
	# Apply roll rotation around the drone's local Z-axis
	roll_velocity = roll_input * max_roll_speed * delta
	
	# Rotate the drone using its local Z-axis
	rotate_object_local(Vector3(0, 0, 1), roll_velocity)


# Apply angular drag function
func apply_angular_drag(delta: float) -> void:
	# Apply drag to each angular velocity component (pitch, yaw, roll)
	pitch_velocity -= pitch_velocity * angular_drag_coefficient * delta
	yaw_velocity -= yaw_velocity * angular_drag_coefficient * delta
	roll_velocity -= roll_velocity * angular_drag_coefficient * delta
	

# Apply friction function
func apply_friction(delta: float) -> void:
	# Apply friction to the x and z components of the velocity
	velocity.x -= velocity.x * friction_coefficient * delta
	velocity.z -= velocity.z * friction_coefficient * delta

#
#func reset_orientation_to_neutral() -> void:
	## Set the drone's pitch and roll to neutral (parallel to the ground)
	#var target_rotation = transform.basis.get_euler()
	#target_rotation.x = 0 # Set pitch to 0 (parallel to the ground)
	#target_rotation.z = 0 # Set roll to 0 (parallel to the ground)
#
	## Apply the new rotation (convert Euler back to Quaternion if needed)
	#transform.basis = Basis().from_euler(target_rotation)


func reset_orientation_to_neutral() -> void: # but 'smoothly'
	# Set the drone's pitch and roll to neutral (parallel to the ground)
	var target_rotation = transform.basis.get_euler()
	target_rotation.x = 0 # Set pitch to 0 (parallel to the ground)
	target_rotation.z = 0 # Set roll to 0 (parallel to the ground)

	# Create a quaternion from the target rotation (Euler angles)
	var target_quaternion = Quaternion.from_euler(target_rotation)

	# Interpolate from the current rotation to the target rotation
	var current_quaternion = transform.basis.get_rotation_quaternion()
	var smooth_quat = current_quaternion.slerp(target_quaternion, 0.2) # Adjust 0.1 for smoothness

	# Apply the interpolated rotation
	transform.basis = Basis(smooth_quat)

func shoot_bullet() -> void:
	# Instantiate the bullet
	var bullet = bullet_scene.instantiate()

	# Add the bullet to the scene and apply a force to shoot it forward
	get_parent().add_child(bullet)
	# Set the bullet's initial position and rotation to match the drone's current position and facing direction
	bullet.global_transform.origin = transform.origin - 3*transform.basis.z  # Position in front of the drone
	bullet.rotation_degrees = transform.basis.get_euler() # Match the drone's rotation
	bullet.apply_impulse(-transform.basis.z * bullet_speed + velocity, Vector3.ZERO)

# need to move to rpc call, determined by server.
# should just send input. this code would then move to server, and it would also have arguments for who is shooting and who was shot
func shoot_laser() -> void:
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		print(str(multiplayer.get_unique_id()) + " shot " + str(collider))
		if collider == self:
			return
		if collider.is_in_group("bullseye") or collider.is_in_group("player"):
			animate_hitmarker()
			if not hit_marker_sound.is_playing():
				hit_marker_sound.play()
				collider.hit_by_bullet()

func animate_hitmarker() -> void:
	var tween = create_tween()
	tween.tween_property(crosshair, "self_modulate", Color("ffffff"), 0.2 ).from(Color("ff0000"))
	var tween_diagonal = create_tween()
	tween_diagonal.tween_property(hitmarker, "self_modulate", Color("ffffff00"), 0.2 ).from(Color("ff0000"))


func update_engine_sound(throttle_input: float, yaw_input: float, pitch_input: float, roll_input: float) -> void:
	# Calculate pitch and volume based on throttle
	#pitch_input = abs(pitch_input)
	#yaw_input = abs(yaw_input)
	#roll_input = abs(roll_input)
	
	pitch_input = apply_exponential_ramp(abs(pitch_input))
	yaw_input = apply_exponential_ramp(abs(yaw_input))
	roll_input = apply_exponential_ramp(abs(roll_input))
	throttle_input = apply_exponential_ramp(throttle_input)
	var pitch = lerp(min_pitch, max_pitch, throttle_input * 1.2+(yaw_input/2)+(pitch_input/2)+(roll_input/2))
	var volume = lerp(min_volume, max_volume, throttle_input*1.2+(yaw_input/2)+(pitch_input/2)+(roll_input/2))

	# Apply pitch and volume to the engine sound
	engine_sound.pitch_scale = pitch
	engine_sound.volume_db = volume

	# Start the engine sound if not already playing
	if not engine_sound.playing:
		engine_sound.play()

func hit_by_bullet() -> void:
	print(name + " was hit by bullet()")
	for mesh in red_indicator.get_children():
		var mesh_surface_override = mesh.get_surface_override_material(0)
		var tween = create_tween()
		tween.tween_property(mesh_surface_override, "albedo_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).from(1.0)
		
	Input.start_joy_vibration(device_index, 1, 1, 0.2)
		
	if health > 0:
		health -= 1
		print(name + "'s health was reduced by 1")
	
		if health <= 0:
			self.you_died_overlay.visible = true
			#print(name + " died")
			death()

func death() -> void:
	#you_died_overlay.self_modulate.a = 1
	you_died_overlay.visible = true
	print(name + " died")
