extends Node3D
class_name NetworkWeaponHitscan3D
## A 3D-specific implementation of a networked hitscan (raycast) weapon.

@onready var input: DroneInput = $"../Input"
@onready var hit_marker_sound: AudioStreamPlayer = $"../HitMarkerSound"
@onready var camera: Camera3D = $"../Node3D/Camera3D"
@onready var laser_sound: AudioStreamPlayer = $"../LaserSound"
@onready var laser_hum_sound: AudioStreamPlayer = $"../LaserHumSound"
@onready var crosshair: TextureRect = $"../HUD/Crosshair"
@onready var hitmarker: TextureRect = $"../HUD/Hitmarker"
@onready var ray_cast: RayCast3D = $"../Node3D/Camera3D/RayCast3D"
@onready var identifier_laser_scaler: Node3D = $"../Node3D/IdentifierLaserScaler"
@onready var identifier_laser: MeshInstance3D = $"../Node3D/IdentifierLaserScaler/IdentifierLaser"

@onready var laser: MeshInstance3D = $"../Scaler/Laser"
#@export var laser_transparency: float = 0.0:
	#get:
		#return laser.get_active_material(0).albedo_color.a
	#set(transparency):
		#laser.get_active_material(0).albedo_color.a = transparency
var identifier_laser_transparency: float = 0.0
	#get:
		#return identifier_laser.get_active_material(0).albedo_color.a
	#set(transparency):
		#identifier_laser.get_active_material(0).albedo_color.a = transparency

## Maximum distance to cast the ray
@export var max_distance: float = 5000.0

## Mask used to detect raycast hits
@export_flags_3d_physics var collision_mask: int = 0xFFFFFFFF

## Colliders excluded from raycast hits
@export var exclude: Array[RID] = []


var _weapon: _NetworkWeaponProxy
func _ready() -> void:
	NetworkTime.on_tick.connect(_tick)
	#laser_transparency = laser.get_active_material(0).albedo_color.a
	
## Try to fire the weapon and return the projectile.
## [br][br]
## Returns true if the weapon was fired.
func fire() -> bool:
	if not can_fire():
		return false
	
	_apply_data(_get_data())
	_after_fire()
	return true

## Check whether this weapon can be fired.
func can_fire() -> bool:
	return _weapon.can_fire()

func _init() -> void:
	_weapon = _NetworkWeaponProxy.new()
	add_child(_weapon, true, INTERNAL_MODE_BACK)
	_weapon.owner = self

	_weapon.c_can_fire = _can_fire
	_weapon.c_can_peer_use = _can_peer_use
	_weapon.c_after_fire = _after_fire
	_weapon.c_spawn = _spawn
	_weapon.c_get_data = _get_data
	_weapon.c_apply_data = _apply_data
	_weapon.c_is_reconcilable = _is_reconcilable
	_weapon.c_reconcile = _reconcile

## Override this method with your own can fire logic.
## [br][br]
## See [NetworkWeapon].
func _can_fire() -> bool:
	return true

## Override this method to check if a given peer can use this weapon.
## [br][br]
## See [NetworkWeapon].
func _can_peer_use(peer_id: int) -> bool:
	return true

## Override this method to run any logic needed after successfully firing the 
## weapon.
## [br][br]
## See [NetworkWeapon].
func _after_fire() -> void:
	pass

func _spawn() -> void:
	# No projectile is spawned for a hitscan weapon.
	pass

func _get_data() -> Dictionary:
	# Collect data needed to synchronize the firing event.
	return {
		"origin": camera.global_transform.origin,
		"direction": -camera.global_transform.basis.z  # Forward direction from the middle of the camera
	}

func _apply_data(data: Dictionary) -> void:
	# Reproduces the firing event on all peers.
	var origin : Vector3 = data["origin"]
	var direction : Vector3 = data["direction"]

	# Perform the raycast from origin in the given direction.
	var space_state := get_world_3d().direct_space_state

	# Create a PhysicsRayQueryParameters3D object.
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.from = origin
	ray_params.to = origin + direction * max_distance

	# Set collision masks or exclude objects:
	ray_params.collision_mask = collision_mask
	ray_params.exclude = exclude

	var result := space_state.intersect_ray(ray_params)

	if result:
		# Handle the hit result, such as spawning hit effects.
		_on_hit(result)

	# Play firing effects on all peers.
	_on_fire()

func _is_reconcilable(request_data: Dictionary, local_data: Dictionary) -> bool:
	# Always reconcilable
	return true

func _reconcile(local_data: Dictionary, remote_data: Dictionary) -> void:
	# Nothing to do on reconcile
	pass

## Override to implement raycast hit logic.
## [br][br]
## The parameter is the result of a
## [method PhysicsDirectSpaceState3D.intersect_ray] call.
func _on_hit(result: Dictionary) -> void:
	if result.collider.is_in_group('player') or result.collider.is_in_group('bullseye'):
		if result.collider == get_parent():
			print("collider detected self, ignored")
			return
		hit_marker_sound.play()
		animate_hitmarker()
		print(str(multiplayer.get_unique_id()) + " shot " + str(result.collider))
	if result.collider.is_in_group('bullseye'):
		result.collider.explode()
		hit_marker_sound.play()
		animate_hitmarker()
		
	# Implement hit effect logic here.
	# var hit_position = result.position
	# var hit_normal = result.normal
	# var collider = result.collider

	# For example, you might emit a signal or instantiate a hit effect scene:
	# emit_signal("hit_detected", hit_position, hit_normal, collider)
	pass


## Override to implement firing effects, like muzzle flash or sound.
func _on_fire() -> void:
	# Implement firing effect logic here.
	#laser.get_active_material(0).albedo_color.a = 1.0
	
	pass


func _tick(_delta: float, _t: int) -> void:
	if input.is_firing:
		fire()
		#identifier_laser.visible = true

func _rollback_tick(delta: float, tick: float, is_fresh: bool) -> void:
	if input.is_firing:
		identifier_laser_scaler.visible = true
	else:
		identifier_laser_scaler.visible = false
		

func _process(_delta: float) -> void:
	#if input.is_just_released_firing:
		#identifier_laser_scaler.visible = false
	#if input.is_just_pressed_firing:
		#identifier_laser_transparency = 1.0
		#identifier_laser.get_active_material(0).albedo_color.a = 1.0
		#laser.get_active_material(0).albedo_color.a = 1.0
	
	#if input.is_just_released_firing:
		#identifier_laser_transparency = 0.0
		#laser.get_active_material(0).albedo_color.a = 0.0
	
	if Input.is_action_just_pressed("shoot"):
		#laser.get_active_material(0).albedo_color.a = 1.0
		#identifier_laser.get_active_material(0).albedo_color.a = 1.0
		laser_sound.play()
		laser_hum_sound.play()

	if Input.is_action_just_released("shoot"):
		laser_sound.stop()
		laser_hum_sound.stop()
		#laser.get_active_material(0).albedo_color.a = 0.0
		#identifier_laser.get_active_material(0).albedo_color.a = 0.0
		#laser.get_active_material(0).albedo_color.a = 0.0
		#var laser_material = laser.get_active_material(0)
		#var tween = create_tween()
		#tween.tween_property(laser_material, "albedo_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		#var identifier_laser_material = identifier_laser.get_active_material(0)
		#var tween2 = create_tween()
		#tween2.tween_property(identifier_laser_material, "albedo_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
# copied from drone:
#func shoot_bullet() -> void:
	## Instantiate the bullet
	#var bullet = bullet_scene.instantiate()
#
	## Add the bullet to the scene and apply a force to shoot it forward
	#get_parent().add_child(bullet)
	## Set the bullet's initial position and rotation to match the drone's current position and facing direction
	#bullet.global_transform.origin = transform.origin - 3*transform.basis.z  # Position in front of the drone
	#bullet.rotation_degrees = transform.basis.get_euler() # Match the drone's rotation
	#bullet.apply_impulse(-transform.basis.z * bullet_speed + velocity, Vector3.ZERO)


func shoot_laser() -> void:
	if ray_cast.is_colliding():
		var collider := ray_cast.get_collider()
		if collider == self:
			return
		print(str(multiplayer.get_unique_id()) + " shot " + str(collider))
		if collider.is_in_group("bullseye") or collider.is_in_group("player"):
			animate_hitmarker()
			if not hit_marker_sound.is_playing():
				hit_marker_sound.play()
				collider.hit_by_bullet()

func animate_hitmarker() -> void:
	var tween := create_tween()
	tween.tween_property(crosshair, "self_modulate", Color("ffffff"), 0.2 ).from(Color("ff0000"))
	var tween_diagonal := create_tween()
	tween_diagonal.tween_property(hitmarker, "self_modulate", Color("ffffff00"), 0.2 ).from(Color("ff0000"))
	
#if Input.is_action_just_pressed("shoot" + string_p2):
	#laser_sound.play()
	#laser_hum_sound.play()
	#
#if Input.is_action_pressed("shoot" + string_p2):
	##shoot_bullet()
	#shoot_laser()
	#laser.get_active_material(0).albedo_color.a = 1.0
	#identifier_laser.get_active_material(0).albedo_color.a = 1.0
#
#if Input.is_action_just_released("shoot" + string_p2):
	#laser_sound.stop()
	#laser_hum_sound.stop()
	#var laser_material = laser.get_active_material(0)
	#var tween = create_tween()
	#tween.tween_property(laser_material, "albedo_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	#var identifier_laser_material = identifier_laser.get_active_material(0)
	#var tween2 = create_tween()
	#tween2.tween_property(identifier_laser_material, "albedo_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
