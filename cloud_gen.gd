extends Node3D

@export var cloud_count: int = 200 # Number of clouds
@export var cloud_scale: Vector2 = Vector2(3, 7) # Random scaling range for clouds
@export var area_size: Vector2 = Vector2(50, 50) # XZ area of cloud distribution
@export var cloud_height: float = 10.0 # Base height of clouds
@export var height_variation: float = 3.0 # Height randomness

var cloud_packed_scene: PackedScene = preload("res://icosphere_001.tscn")
var multi_mesh_instance: MultiMeshInstance3D

func _ready() -> void:
	_generate_clouds()

func _generate_clouds() -> void:
	var cloud_mesh := preload("res://icosphere_001.tscn").instantiate()
	#cloud_mesh.radius = 1.5
	#cloud_mesh.height = 0.6
	#cloud_mesh.radial_segments = 8
	#cloud_mesh.rings = 4
	
	# Create MultiMeshInstance for optimized instancing
	multi_mesh_instance = MultiMeshInstance3D.new()
	var multi_mesh: MultiMesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = cloud_mesh.mesh
	multi_mesh.instance_count = cloud_count
	multi_mesh_instance.multimesh = multi_mesh
	add_child(multi_mesh_instance)

	# Position clouds using Perlin Noise for natural placement
	for i in range(cloud_count):
		var x: float = randf_range(-area_size.x / 2, area_size.x / 2)
		var z: float = randf_range(-area_size.y / 2, area_size.y / 2)
		var height_offset: float = noise_2d(x * 0.1, z * 0.1) * height_variation
		var y: float = cloud_height + height_offset
		
		var transform: = Transform3D()
		transform.origin = Vector3(x, y, z)
		
		# Random rotation
		transform.basis = Basis(Vector3.UP, randf_range(0, TAU))
		
		# Random scale
		var scale_factor := randf_range(cloud_scale.x, cloud_scale.y)
		transform = transform.scaled(Vector3(scale_factor, scale_factor, scale_factor))
		
		multi_mesh.set_instance_transform(i, transform)

# Simple 2D noise function for smooth placement
func noise_2d(x: float, y: float) -> float:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.3
	return noise.get_noise_2d(x, y)
