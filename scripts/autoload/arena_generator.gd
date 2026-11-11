extends Node
class_name ArenaGenerator

# Configuration for arena generation
@export var num_levels: int = 4
@export var seed: int = -1  # Use same seed for reproducible layouts
@export var base_size: float = 60.0
@export var bridge_width: float = 5.0
@export var stair_height_step: float = 2.0

# Generation state
var layout_hash := ""
var level_connections := []  # Stores which levels connect to each other

func _ready():
	if not Engine.is_editor_hint():
		generate_arena()
	
	# Signal to main level that arena is ready (for demo player)
	var spawn_main_level := get_tree().get_root().get_node_or_null("MainLevel") as MainLevel
	if spawn_main_level:
		spawn_main_level.set_meta("_connected_to_arena_gen", true)

func _process(_delta):
	pass  # Removed - no longer needed
	# Set seed for reproducible generation if provided
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed(seed)
	
	# Clear previous arena (keep only root node)
	while get_child_count() > 1:
		remove_child(get_child(0))
	
	add_to_group("arena_generator")
	
	# Generate layout hash for debugging
	layout_hash = generate_layout_hash(rng)
	print("[ArenaGen] Generated layout:", layout_hash)
	
	# Create base arena structure
	create_ground_level(rng)
	
	# Build each level with organic connections
	for i in range(1, num_levels):
		var level_data := create_level(i, rng)
		level_connections.append(level_data)
		
		# Connect this level to previous levels (guaranteed connectivity)
		connect_levels_up(rng)
	
	# Add guaranteed vertical access points (stairs/ladders)
	add_vertical_access_points(rng)
	
	print("[ArenaGen] Arena generated with", num_levels, "levels and", layout_hash)
	spawn_demo_player(rng)

func create_ground_level(rng: RandomNumberGenerator):
	var ground_node := Node3D.new()
	ground_node.name = "GroundLevel"
	add_child(ground_node)
	
	# Main plaza floor
	create_floor(ground_node, base_size, Color(0.53, 0.76, 0.9), rng)
	
	# Random cover objects (hiding spots)
	for i in range(rng.randi_range(8, 12)):
		var pos := Vector3(
			rng.randf_range(-base_size/2 + 5, base_size/2 - 5),
			rng.randf_range(-0.5, 0.5),
			rng.randf_range(-base_size/2 + 5, base_size/2 - 5)
		)
		create_cover_object(ground_node, pos, rng)

func create_level(level_idx: int, rng: RandomNumberGenerator):
	var level_node := Node3D.new()
	level_node.name = "Level" + str(level_idx)
	add_child(level_node)
	
	var y_offset := float(level_idx) * stair_height_step * 2.0
	
	# Platform for this level (slightly smaller than base)
	var platform_size := base_size - float(level_idx) * 5.0
	create_floor(
		level_node, 
		platform_size, 
		Color(rng.randf(), rng.randf(), rng.randf()), 
		rng
	)
	
	# Random obstacles/cover for this level
	var num_obstacles := rng.randi_range(6, 10)
	for i in range(num_obstacles):
		var pos := Vector3(
			rng.randf_range(-platform_size/2 + 3, platform_size/2 - 3),
			y_offset + rng.randf_range(0.5, 1.0),
			rng.randf_range(-platform_size/2 + 3, platform_size/2 - 3)
		)
		create_cover_object(level_node, pos, rng)

func create_floor(parent: Node3D, size: float, color: Color, rng: RandomNumberGenerator):
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = color
	floor_mat.roughness = 0.6
	
	var floor_mesh := BoxMesh.new()
	floor_mesh.material = floor_mat
	floor_mesh.size = Vector3(size, 0.4, size)
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = floor_mesh
	mesh_instance.position.y = 0.2
	parent.add_child(mesh_instance)

func create_cover_object(parent: Node3D, position: Vector3, rng: RandomNumberGenerator):
	# Simple cover objects - can be expanded with Kenney assets later
	var height := rng.randf_range(1.5, 4.0)
	var width := rng.randf_range(2.0, 6.0)
	
	var cover_mat := StandardMaterial3D.new()
	cover_mat.albedo_color = Color(rng.randf(), rng.randf(), rng.randf())
	
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(width, height, width * 0.5)
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box_mesh
	mesh_instance.position = position
	parent.add_child(mesh_instance)

func connect_levels_up(rng: RandomNumberGenerator):
	# Each level connects to 1-2 previous levels (organic branching)
	var num_connections := rng.randi_range(1, min(2, level_connections.size()))
	
	for i in range(num_connections):
		var target_idx := rng.randi_range(0, level_connections.size() - 1)
		add_bridge(level_connections[level_connections.size() - 1], level_connections[target_idx])

func add_vertical_access_points(rng: RandomNumberGenerator):
	# Add guaranteed stairs/ladders from ground to each upper level
	for i in range(1, num_levels):
		var target_level := level_connections[i - 1]
		
		# Stairs going up (ground -> mid) or ladder going further up (mid -> roof)
		if i == 1:
			create_staircase(target_level)
		else:
			create_ladder(target_level, rng)

func create_staircase(level_node: Node3D):
	var stairs := Node3D.new()
	stairs.name = "Staircase"
	level_node.add_child(stairs)
	
	# Staircase position at edge of platform
	var pos := Vector3(
		rng.randf_range(-base_size/2 + 5, base_size/2 - 5),
		0.0,
		rng.randf_range(-base_size/2 + 5, base_size/2 - 5)
	)
	
	stairs.position = pos
	
	# Simple stair steps (can use Kenney stairs assets later)
	var step_height := 0.3
	var num_steps := int((level_node.position.y / step_height) + 1)
	var total_height := float(num_steps) * step_height
	
	for i in range(num_steps):
		var step_y := float(i) * step_height
		var step_mesh := BoxMesh.new()
		step_mesh.size = Vector3(2.0, step_height, rng.randf_range(1.5, 3.0))
		
		var step_mat := StandardMaterial3D.new()
		step_mat.albedo_color = Color(0.6, 0.5, 0.4)
		step_mesh.material = step_mat
		
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = step_mesh
		mesh_inst.position = Vector3(pos.x + rng.randf_range(-1, 1), step_y, pos.z + rng.randf_range(-1, 1))
		
		stairs.add_child(mesh_inst)

func create_ladder(level_node: Node3D, rng: RandomNumberGenerator):
	var ladder := Node3D.new()
	ladder.name = "Ladder"
	level_node.add_child(ladder)
	
	# Ladder position at edge of platform
	var pos := Vector3(
		rng.randf_range(-base_size/2 + 5, base_size/2 - 5),
		0.0,
		rng.randf_range(-base_size/2 + 5, base_size/2 - 5)
	)
	
	ladder.position = pos
	
	# Ladder rungs
	var rung_height := 0.35
	var num_rungs := int((level_node.position.y / rung_height) + 1)
	
	for i in range(num_rungs):
		var rung_y := float(i) * rung_height
		var rung_mesh := BoxMesh.new()
		rung_mesh.size = Vector3(0.6, 0.1, rng.randf_range(2.5, 4.0))
		
		var rung_mat := StandardMaterial3D.new()
		rung_mat.albedo_color = Color(0.3, 0.3, 0.3)
		rung_mesh.material = rung_mat
		
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = rung_mesh
		mesh_inst.position = Vector3(pos.x + rng.randf_range(-1, 1), rung_y, pos.z)
		
		ladder.add_child(mesh_inst)

func add_bridge(from_level: Node, to_level: Node):
	var bridge := Node3D.new()
	bridge.name = "Bridge"
	from_level.add_child(bridge)
	
	# Calculate position between levels
	var from_center := Vector3(0.0, from_level.position.y, 0.0).normalized() * base_size / 2.0
	var to_center := Vector3(0.0, to_level.position.y, 0.0).normalized() * platform_size / 2.0
	
	bridge.position = (from_center + to_center) * 0.5
	bridge.rotation.z = rng.randf_range(-0.5, 0.5)  # Slight angle for variety
	
	var bridge_mat := StandardMaterial3D.new()
	bridge_mat.albedo_color = Color(0.54, 0.29, 0.18)  # Wood color
	bridge_mat.roughness = 0.6
	
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.material = bridge_mat
	bridge_mesh.size = Vector3(bridge_width, 0.5, rng.randf_range(4.0, 8.0))
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = bridge_mesh
	from_level.add_child(mesh_inst)


func spawn_demo_player(rng: RandomNumberGenerator):
	"""
	Spawn a single demo player at arena center for testing.
	Called from generate_arena() after the arena is built.
	"""
	var main_level := get_tree().get_root().get_node_or_null("MainLevel") as MainLevel
	if not main_level:
		return
	
	var player_scene := main_level.get_node_or_null("PlayersContainer").get_node_or_null("PlayerTemplate") as PackedScene
	if not player_scene:
		print("[ArenaGen] No player template found for demo spawn!")
		return
	
	var player := player_scene.instantiate() as CharacterBody3D
	main_level.PlayersContainer.add_child(player)
	player.set_role(HideSeekGameManager.PlayerRole.SEEKER)
	
	# Position at center (y=1.5 accounts for player mesh offset)
	player.global_position = Vector3(0.0, 1.5, 0.0)
	
	# Connect camera container to player controller
	var player_controller := player.get_node_or_null("PlayerController") as PlayerController
	var camera_container := player.get_node_or_null("CameraContainer") as Node3D
	if player_controller and camera_container:
		camera_container.set_meta("_parent_controller", player_controller)

func generate_layout_hash(rng: RandomNumberGenerator) -> String:
	var hash_parts := []
	for i in range(num_levels):
		hash_parts.append(str(i, rng.randi()))
	return "layout_" + str(hash_parts.join("_"))
