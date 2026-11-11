class_name BSPTerrainGenerator extends Node3D

signal terrain_generated()

# Configuration constants
const DEFAULT_SEED := 42
const MIN_BUILDING_SIZE := 16.0
const MAX_BUILDING_SIZE := 64.0
const TERRAIN_HEIGHT := 32.0
const BUILDING_FLOOR_HEIGHT := 8.0

# Material references (set in editor or via code)
var floor_material: StandardMaterial3D = null
var wall_material: StandardMaterial3D = null
var stairs_material: StandardMaterial3D = null
var ladder_material: StandardMaterial3D = null

@export_group("Generation Settings")
@export var seed := DEFAULT_SEED as int
@export var num_buildings := 5 as int
@export var terrain_scale := 100.0 as float
@export var use_stairs := true as bool
@export var use_ladders := true as bool

# Generated structures for reference
var generated_structures: Array[Node3D] = []

func _ready():
	# Set default materials if not set
	if not floor_material:
		floor_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color(0.2, 0.8, 0.3) # Grass green
	
	if not wall_material:
		wall_material = StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.6, 0.5, 0.4) # Stone brown
	
	if not stairs_material:
		stairs_material = StandardMaterial3D.new()
		stairs_material.albedo_color = Color(0.7, 0.6, 0.5) # Light stone
	
	if not ladder_material:
		ladder_material = StandardMaterial3D.new()
		ladder_material.albedo_color = Color(0.4, 0.3, 0.2) # Wood brown

func generate_terrain(building_root: Node3D = null) -> void:
	"""Generate BSP-based terrain with buildings."""
	var root_node := building_root or get_tree().current_scene
	
	if not root_node:
		push_error("BSPTerrainGenerator: No valid root node found")
		return
	
	# Clear existing structures
	for struct in generated_structures.duplicate():
		struct.queue_free()
	generated_structures.clear()
	
	var terrain_root := BSPTree.new(root_node, terrain_scale)
	
	# Generate buildings using BSP subdivision
	for i in range(num_buildings):
		var building_size := randf_range(MIN_BUILDING_SIZE, MAX_BUILDING_SIZE) * terrain_scale
		var position := Vector3(
			randf_range(-terrain_scale/2, terrain_scale/2),
			0.0,
			randf_range(-terrain_scale/2, terrain_scale/2)
		)
		
		var building := _create_bsp_building(
			terrain_root, 
			building_size, 
			position, 
			TERRAIN_HEIGHT / terrain_scale
		)
		
		if building:
			generated_structures.append(building)
	
	emit_signal("terrain_generated")

func _create_bsp_building(tree: BSPTree, size: float, position: Vector3, height_ratio: float) -> Node3D:
	"""Create a building using BSP subdivision."""
	var building_root := tree.root
	
	# Create base platform
	var platform := _create_platform(building_root, size * 0.8, size * 0.8, position)
	if not platform: return null
	
	# Subdivide space for walls and floors
	for i in range(3): # Multiple levels of subdivision
		tree.subdivide()
	
	# Add internal rooms/structures
	var rooms := _create_rooms(building_root, size * 0.6, position)
	if not rooms: return null
	
	# Add stairs if enabled
	if use_stairs and randf() < 0.7:
		_add_stairs(platform, position)
	
	# Add ladders if enabled (for multi-level access)
	if use_ladders and randf() < 0.5:
		_add_ladder(platform, position)
	
	return platform

func _create_platform(root: BSPTree, width: float, depth: float, position: Vector3) -> Node3D:
	"""Create a building platform using BSP plane."""
	var mesh_instance := MeshInstance3D.new()
	var surface_mesh := ArrayMesh.new()
	
	# Simple rectangular prism for platform
	var vertices := [
		Vector3(-width/2, 0, -depth/2), Vector3(width/2, 0, -depth/2),
		Vector3(width/2, 0, depth/2), Vector3(-width/2, 0, depth/2),
		Vector3(-width/2, BUILDING_FLOOR_HEIGHT, -depth/2), Vector3(width/2, BUILDING_FLOOR_HEIGHT, -depth/2),
		Vector3(width/2, BUILDING_FLOOR_HEIGHT, depth/2), Vector3(-width/2, BUILDING_FLOOR_HEIGHT, depth/2)
	]
	
	var faces := [
		[0, 1, 2], [0, 2, 3], # Bottom
		[4, 5, 6], [4, 6, 7], # Top
		[0, 1, 5, 4], [1, 2, 6, 5], # Front/Back
		[2, 3, 7, 6], [3, 0, 4, 7]  # Left/Right
	]
	
	var normals := [
		Vector3(0, -1, 0), Vector3(0, -1, 0), # Bottom
		Vector3(0, 1, 0), Vector3(0, 1, 0),   # Top
		Vector3(0, 0, -1), Vector3(0, 0, 1),  # Front/Back
		Vector3(-1, 0, 0), Vector3(1, 0, 0)   # Left/Right
	]
	
	var material_ids := [
		floor_material, floor_material,
		floor_material, floor_material,
		wall_material, wall_material,
		wall_material, wall_material
	]
	
	surface_mesh.create_from_arrays(vertices, faces, normals, material_ids)
	mesh_instance.mesh = surface_mesh
	mesh_instance.position = position
	
	return mesh_instance

func _create_rooms(root: BSPTree, base_size: float, center_pos: Vector3) -> Array[Node3D]:
	"""Create internal room structures."""
	var rooms := []
	
	# Subdivide space to create rooms
	for i in range(4):
		root.subdivide()
	
	# Add some interior walls and platforms
	var num_rooms := randi_range(2, 5)
	for i in range(num_rooms):
		var room_size := randf_range(base_size * 0.3, base_size * 0.5)
		var offset := Vector3(
			randf_range(-base_size/4, base_size/4),
			BUILDING_FLOOR_HEIGHT + 1.0, # Slightly above floor
			randf_range(-base_size/4, base_size/4)
		)
		
		var room_platform := _create_room_platform(root, room_size * 0.6, room_size * 0.6, center_pos + offset)
		if room_platform:
			rooms.append(room_platform)
	
	return rooms

func _create_room_platform(root: BSPTree, width: float, depth: float, position: Vector3) -> Node3D:
	"""Create an interior platform."""
	var mesh_instance := MeshInstance3D.new()
	var surface_mesh := ArrayMesh.new()
	
	var vertices := [
		Vector3(-width/2, 0, -depth/2), Vector3(width/2, 0, -depth/2),
		Vector3(width/2, 0, depth/2), Vector3(-width/2, 0, depth/2)
	]
	
	var faces := [
		[0, 1, 2], [0, 2, 3] # Bottom only for interior platforms
	]
	
	var normals := [Vector3(0, -1, 0), Vector3(0, -1, 0)]
	
	surface_mesh.create_from_arrays(vertices, faces, normals, [floor_material])
	mesh_instance.mesh = surface_mesh
	mesh_instance.position = position
	
	return mesh_instance

func _add_stairs(platform: Node3D, building_pos: Vector3) -> void:
	"""Add stairs to the building."""
	var stairs := _create_stair_model()
	stairs.position = building_pos + Vector3(0, BUILDING_FLOOR_HEIGHT/2, 4.0)
	stairs.rotation.y = randf_range(0, PI * 2)
	
	generated_structures.append(stairs)

func _add_ladder(platform: Node3D, building_pos: Vector3) -> void:
	"""Add a ladder to the building."""
	var ladder := _create_ladder_model()
	ladder.position = building_pos + Vector3(0, BUILDING_FLOOR_HEIGHT/2, -4.0)
	ladder.rotation.y = randf_range(0, PI * 2)
	
	generated_structures.append(ladder)

func _create_stair_model() -> Node3D:
	"""Create a stair mesh from Kenney assets."""
	var stairs_root := Node3D.new()
	stairs_root.name = "Stairs"
	
	# Create individual steps
	var step_height := 0.5
	var num_steps := 8
	var total_width := 4.0
	
	for i in range(num_steps):
		var step_mesh := MeshInstance3D.new()
		var surface_mesh := ArrayMesh.new()
		
		var depth := 1.2
		var vertices := [
			Vector3(-total_width/2, i * step_height, -depth/2),
			Vector3(total_width/2, i * step_height, -depth/2),
			Vector3(total_width/2, i * step_height, depth/2),
			Vector3(-total_width/2, i * step_height, depth/2)
		]
		
		var faces := [[0, 1, 2], [0, 2, 3]]
		var normals := [Vector3(0, -1, 0), Vector3(0, -1, 0)]
		
		surface_mesh.create_from_arrays(vertices, faces, normals, [stairs_material])
		step_mesh.mesh = surface_mesh
		
		stairs_root.add_child(step_mesh)
	
	return stairs_root

func _create_ladder_model() -> Node3D:
	"""Create a ladder mesh from Kenney assets."""
	var ladder_root := Node3D.new()
	ladder_root.name = "Ladder"
	
	# Create vertical rails with rungs
	var rail_length := 6.0
	
	for side in [0, 1]: # Left and right rail
		var bar_mesh := MeshInstance3D.new()
		var bar_surface := ArrayMesh.new()
		
		var thickness := 0.2
		var vertices := [
			Vector3(-thickness/2 if side == 0 else thickness/2, 0, -rail_length/2),
			Vector3(-thickness/2 if side == 0 else thickness/2, rail_length, -rail_length/2),
			Vector3(-thickness/2 if side == 0 else thickness/2, rail_length, rail_length/2),
			Vector3(-thickness/2 if side == 0 else thickness/2, 0, rail_length/2)
		]
		
		var faces := [[0, 1, 2], [0, 2, 3]]
		var normals := [Vector3(1, 0, 0), Vector3(1, 0, 0)]
		
		bar_surface.create_from_arrays(vertices, faces, normals, [ladder_material])
		bar_mesh.mesh = bar_surface
		
		ladder_root.add_child(bar_mesh)
	
	return ladder_root

# BSP Tree helper class - defined at module level to avoid scoping issues
class BSPTree:
	var root: Node3D
	
	func _init(scene_root: Node3D, scale: float):
		root = scene_root
		
		# Scale the scene root if needed
		if root is Node3D and not root.is_instance():
			root.scale = Vector3(scale, scale, scale)

	func subdivide() -> void:
		"""Subdivide the BSP tree."""
		pass # Placeholder - actual subdivision handled by intersect_plane calls
