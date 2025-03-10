extends CharacterBody3D
class_name DroneController

var player_id: int = -1
@export var player_name: String = "":
	set(p_name):
		if p_name.length() > 24:
			p_name = p_name.substr(0, 21) + "..."
		player_name = p_name
		nametag.text = p_name
@onready var input: DroneInput = $Input
@onready var nametag: Label3D = $Nametag
@onready var brawler_spawner := get_tree().get_first_node_in_group('Brawler Spawner')
@onready var drone_animation_player: AnimationPlayer = $"Pivot/drone edited origins/DroneAnimationPlayer"
@onready var bullet_scene: PackedScene = preload("res://Bullet/bullet.tscn") # Bullet scene
@onready var ray_cast: RayCast3D = $Node3D/Camera3D/RayCast3D
@onready var fpv_camera: Camera3D = $Node3D/Camera3D
@onready var laser: MeshInstance3D = $Scaler/Laser
@onready var identifier_laser: MeshInstance3D = $Node3D/IdentifierLaserScaler/IdentifierLaser
@onready var you_died_overlay: TextureRect = $HUD/YouDied
@onready var engine_sound: AudioStreamPlayer = $EngineSound
@onready var battery_level: Label = $HUD/BatteryLevel
@onready var red_indicator: Node3D = $"Pivot/drone edited origins/root/node_id273/RedIndicator"
@onready var angle_mode_bool: Label = $HUD/AngleMode/AngleModeBool
@onready var altitude_mode_bool: Label = $HUD/AltitudeMode/AltitudeModeBool
@onready var settings_color_rect: ColorRect = $HUD/SettingsColorRect
@onready var angle_mode_settings_button: Button = $HUD/SettingsColorRect/AngleMode
@onready var altitude_mode_settings_button: Button = $HUD/SettingsColorRect/AltitudeMode
@onready var camera_pivot: Node3D = $Node3D
@onready var camera_angle_value: Label = $HUD/CameraAngle/CameraAngleValue


@export var health := 5
@export var bullet_speed := 60.0 # Bullet speed
@export var battery : float = 100.0
@export var battery_drain_multiplier : float = 0.4
@export var laser_drain := 0.4
@export var is_angle_assist : bool = false
@export var is_altitude_assist: bool = false
@export var altitude_assist_force : float = 11.76

@export var ramp_factor: float = 2.0 # Exponent for the exponential ramp
@export var max_thrust := 50.0 # Maximum upward force (throttle)
@export var max_yaw_speed := 8.0 # Maximum rotational speed for yaw
@export var max_pitch_speed := 6.0 # Maximum rotational speed for pitch
@export var max_roll_speed := 6.0 # Maximum rotational speed for roll

@export var friction_coefficient := 10 # Adjust this value to tune the friction intensity
@export var drag_coefficient := 0.5 # Adjust this value to tune drag intensity
@export var angular_drag_coefficient := 0.1 # Adjust this to tune angular drag intensity

 # Reduce sensitivity to 50% while zoomed in
@export var zoom_sensitivity_multiplier: float = 0.3
@export var default_fov: float = 100.0  # Normal field of view
@export var zoom_fov: float = 20.0     # Zoomed-in field of view
@export var zoom_speed: float = 15.0   # How fast the zoom transitions

@export var default_camera_angle := 20.0
@export var max_camera_angle := 60.0
@export var min_camera_angle := -30.0

# Pitch/Volume range for engine whine
@export var min_pitch := 0.9  # Pitch at zero throttle
@export var max_pitch := 1.4  # Pitch at full throttle
@export var min_volume := -10  # Volume (dB) at zero throttle
@export var max_volume := -5  # Volume (dB) at full throttle

# Aggregated Inputs
var input_dictionary : Dictionary = {
	"pitch": 0,
	"yaw": 0,
	"roll": 0,
	"throttle": 0
}

# Variables to track angular velocities
var pitch_velocity: float = 0.0
var yaw_velocity: float = 0.0
var roll_velocity: float = 0.0

var is_zoom : bool = false

var device_index : int
var string_p2 : String = ""
var respawn_count: int = 0

func _ready() -> void:
	settings_color_rect.visible = false
	angle_mode_settings_button.pressed.connect(_toggle_angle_assist)
	altitude_mode_settings_button.pressed.connect(_toggle_altitude_assist)
	battery_level.text = str(int(battery))
	#var vp = get_viewport()
	#vp.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	_snap_to_spawn()
	add_to_group("player")
	laser.get_active_material(0).albedo_color.a = 0.0
	#identifier_laser.get_active_material(0).albedo_color.a = 0.0
	#if name == "Drone":
		#device_index = 0
	#elif name == "DroneP2":
		#device_index = 1
		#string_p2 = "_p2"
	Input.stop_joy_vibration(device_index)
	$MultiplayerSynchronizer.set_multiplayer_authority(player_id)
	print("%s's MultiplayerSynchronizer authority is %s" % [name, $MultiplayerSynchronizer.get_multiplayer_authority()])
	fpv_camera.current = false
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		fpv_camera.current = true
	else:
		$HUD.visible = false
		
		

func _process(delta: float) -> void:
	# remove Drone #1 if host_only was clicked
	if name == "Drone #1" and brawler_spawner.spawn_host_avatar == false:
		queue_free()
	if Input.is_action_just_pressed("menu"):
		settings_color_rect.visible = !settings_color_rect.visible
	$HUD/FPS.text = "FPS: " + str(Engine.get_frames_per_second())
	if Input.is_action_just_pressed("debug"):
		print('device index: %s' % device_index)
		print("muid: " + str(multiplayer.get_unique_id()))
		print("name: " + name)
		print("msync mu auth: " + str($MultiplayerSynchronizer.get_multiplayer_authority()))
		print('youdied owner: ' + you_died_overlay.owner.name)
		
	if Input.is_action_pressed("aim_down_sights" + string_p2):
		fpv_camera.fov = lerp(fpv_camera.fov, zoom_fov, zoom_speed * delta)
	else:
		fpv_camera.fov = lerp(fpv_camera.fov, default_fov, zoom_speed * delta)

	if Input.is_action_pressed("camera_angle_up"):
		if camera_pivot.rotation_degrees.x < max_camera_angle:
			camera_pivot.rotation_degrees.x += 1.0
			camera_angle_value.text = str(int(camera_pivot.rotation_degrees.x)) + " °"
			
	if Input.is_action_pressed("camera_angle_down"):
		if camera_pivot.rotation_degrees.x > min_camera_angle:
			camera_pivot.rotation_degrees.x -= 1.0
			camera_angle_value.text = str(int(camera_pivot.rotation_degrees.x)) + " °"
	
	# Update the input dictionary
	input_dictionary = get_input_dictionary(input.throttle_input, input.yaw_input, input.pitch_input, input.roll_input)
	
	# Adjust engine sound based on throttle input
	update_engine_sound()
	
	# Update battery label
	battery_level.text = str(int(battery))
	# Play animation
	drone_animation_player.play("throttle_forward")
	drone_animation_player.speed_scale = 2 + input.throttle_input * 3
	# add yaw,pitch,roll animations also




#func _tick(_delta, tick):
	#pass


func _rollback_tick(delta: float, _tick: float, _is_fresh: bool) -> void:
	# Add the gravity.
	if not is_on_floor():
		if is_angle_assist:
			reset_orientation_to_neutral()
		velocity += get_gravity() * 1.2 * delta
	else:
		apply_friction(delta)
		reset_orientation_to_neutral() # can use this for ez hover
	
	if is_angle_assist:
		angle_mode_bool.text = "on"
	else:
		angle_mode_bool.text = "off"
	
	if is_altitude_assist:
		altitude_mode_bool.text = "on"
	else:
		altitude_mode_bool.text = "off"
		
	# drain battery when firing laser
	if input.is_firing:
		battery -= laser_drain
	# Start zoom
	if input.is_zooming:
		if not is_zoom:
			max_pitch_speed *= zoom_sensitivity_multiplier
			max_roll_speed *= zoom_sensitivity_multiplier
			max_yaw_speed *= zoom_sensitivity_multiplier
			is_zoom = true
	# End zoom
	else:
		if is_zoom:
			max_pitch_speed *= 1/zoom_sensitivity_multiplier
			max_roll_speed *= 1/zoom_sensitivity_multiplier
			max_yaw_speed *= 1/zoom_sensitivity_multiplier
			is_zoom = false
		
	# Apply thrust
	apply_thrust(input.throttle_input, delta)
	
	# Apply yaw
	apply_yaw(input.yaw_input, delta)

	# Apply roll
	apply_roll(input.roll_input, delta)
	
	# Apply pitch
	apply_pitch(input.pitch_input, delta)
	
	# Apply angular drag to reduce angular velocities
	apply_angular_drag(delta)
	
	# Drain battery
	drain_battery()
	
	# Apply movement
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor


func apply_exponential_ramp(input_value: float) -> float:
	# Apply the exponential curve: input^ramp_factor
	return sign(input_value) * pow(abs(input_value), ramp_factor)


func apply_thrust(throttle_input: float, delta: float) -> void:
	# Get the thrust direction (normal to the drone's plane)
	# Local "up" direction relative to the drone
	var thrust_direction := transform.basis.y.normalized()
	
	if is_altitude_assist:
		# deadzone
		if throttle_input > -0.2 and throttle_input < 0.2:
			velocity += altitude_assist_force * thrust_direction * delta
		elif throttle_input >= 0.2:
			velocity += (altitude_assist_force * thrust_direction * delta) + throttle_input * altitude_assist_force * 2 * thrust_direction * delta
		elif throttle_input <= -0.2:
			velocity += Vector3.ZERO * delta
	else:
		throttle_input = apply_exponential_ramp(throttle_input)

		# Scale the thrust direction by the input and maximum thrust
		var thrust_force := thrust_direction * throttle_input * max_thrust

		# Apply thrust directly to velocity, scaled by delta
		if throttle_input > 0:
			velocity += thrust_force * delta

	# Introduce drag to counter excessive acceleration
	apply_drag(delta)


func apply_drag(delta: float) -> void:
	# Drag reduces velocity proportionally to its current magnitude
	var drag_force := velocity * drag_coefficient * delta
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
	var target_rotation := transform.basis.get_euler()
	target_rotation.x = 0 # Set pitch to 0 (parallel to the ground)
	target_rotation.z = 0 # Set roll to 0 (parallel to the ground)

	# Create a quaternion from the target rotation (Euler angles)
	var target_quaternion := Quaternion.from_euler(target_rotation)

	# Interpolate from the current rotation to the target rotation
	var current_quaternion := transform.basis.get_rotation_quaternion()
	var smooth_quat := current_quaternion.slerp(target_quaternion, 0.2) # Adjust 0.1 for smoothness

	# Apply the interpolated rotation
	transform.basis = Basis(smooth_quat)

func get_input_dictionary(throttle_input: float, yaw_input: float, pitch_input: float, roll_input: float) -> Dictionary:
	pitch_input = apply_exponential_ramp(abs(pitch_input))
	yaw_input = apply_exponential_ramp(abs(yaw_input))
	roll_input = apply_exponential_ramp(abs(roll_input))
	throttle_input = apply_exponential_ramp(abs(throttle_input))
	return {
		"pitch": pitch_input,
		"yaw": yaw_input,
		"roll": roll_input,
		"throttle": throttle_input,
	}

func drain_battery() -> void:
	# battery drains based on how far sticks are pushed. half value for all except throttle since 4 motors involved.
	battery -= battery_drain_multiplier * (input_dictionary["pitch"]/2 + input_dictionary["yaw"]/2 + input_dictionary["roll"]/2 + input_dictionary["throttle"])
	

func update_engine_sound() -> void:
	# Audio pitch, not aerial pitch
	var pitch : float = lerp(min_pitch, max_pitch, input_dictionary["throttle"] * 1.2+(input_dictionary["yaw"]/2)+(input_dictionary["pitch"]/2)+(input_dictionary["roll"]/2))
	var volume : float = lerp(min_volume, max_volume, input_dictionary["throttle"]*1.2+(input_dictionary["yaw"]/2)+(input_dictionary["pitch"]/2)+(input_dictionary["roll"]/2))

	# Apply pitch and volume to the engine sound
	engine_sound.pitch_scale = pitch
	engine_sound.volume_db = volume

	# Start the engine sound if not already playing
	if not engine_sound.playing:
		engine_sound.play()

func hit_by_bullet() -> void:
	print(name + " was hit by bullet()")
	for mesh in red_indicator.get_children():
		var mesh_surface_override : Mesh = mesh.get_surface_override_material(0)
		var tween := create_tween()
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


func _snap_to_spawn() -> void:
	#pass
	var spawns := get_tree().get_nodes_in_group("Spawn Points")
	var idx := hash(player_id + respawn_count * 39) % spawns.size()
	var spawn : Node3D = spawns[idx]
	
	global_transform = spawn.global_transform

func _toggle_angle_assist() -> void:
	if is_angle_assist:
		angle_mode_settings_button.text = "Angle Assist :       off"
		is_angle_assist = false
	else:
		angle_mode_settings_button.text = "Angle Assist :       on"
		is_angle_assist = true

func _toggle_altitude_assist() -> void:
	if is_altitude_assist:
		is_altitude_assist = false
		altitude_mode_settings_button.text = "Altitude Assist :       off"
	else:
		is_altitude_assist = true
		altitude_mode_settings_button.text = "Altitude Assist :       on"
