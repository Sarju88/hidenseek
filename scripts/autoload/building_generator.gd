extends Node
class_name BuildingGenerator

# Office building configuration - enclosed, multi-level workspace
@export var num_rooms: int = 6
@export var floor_height: float = 4.0
@export var corridor_width: float = 3.5
@export var office_size_range_min: float = 8.0
@export var office_size_range_max: float = 14.0

# Internal state
var layout_seed := "" as String
var rooms_placed := []  # List of room nodes for debugging

func _ready():
	if not Engine.is_editor_hint():
		print("[BuildingGen] Starting office building generation...")
		generate_building()
		print("[BuildingGen] Generation complete. Spawned", get_child_count(), "nodes.")
		add_debug_visual()
	else:
		print("[BuildingGen] Editor mode - skipping generation")

func add_debug_visual():
	var debug_sphere := SphereMesh.new()
	debug_sphere.radius = 1.0
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0)  # Bright red for visibility
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = debug_sphere
	mesh_inst.material = material
	add_child(mesh_inst)
	print("[BuildingGen] Debug sphere added at origin - if visible, camera is working!")

func generate_building():
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed(Time.get_ticks_msec())
	layout_seed = "layout_" + str(rng.randi())
	print("[BuildingGen] Generated layout:", layout_seed)
	
	while get_child_count() > 1:
		remove_child(get_child(0))
	add_to_group("building_generator")
	
	# Create enclosed office building structure
	create_ground_floor_lobby(rng)
	create_upper_floors(rng)
	
	# Add office-specific furniture and cover objects (for hiding)
	add_office_furniture(rng)

func create_ground_floor_lobby(rng: RandomNumberGenerator):
	var lobby := Node3D.new()
	lobby.name = "Lobby"
	add_child(lobby)
	
	# Main entrance area - enclosed but open enough for navigation
	create_enclosed_space(lobby, Vector2(0.0, 0.0), rng, is_lobby=true)
	
	# Generate interconnected offices and corridors
	for i in range(1, num_rooms + 2):  # +2 for additional office spaces
		var parent_node := select_parent_node(rng)
		if parent_node:
			var offset := calculate_room_offset(parent_node, rng)
			create_office_or_corridor(parent_node, offset, rng)

func create_upper_floors(rng: RandomNumberGenerator):
	for floor_idx in range(1, 3):  # 2 upper floors
		var previous_floor := get_child(floor_idx - 1) as Node3D
		if not previous_floor or previous_floor.get_name() != "Floor" + str(floor_idx - 1):
			continue
			
		var new_floor := Node3D.new()
		new_floor.name = "Floor" + str(floor_idx)
		add_child(new_floor)
		
		# Stairs/ladder to reach this floor
		create_vertical_access(previous_floor, new_floor, rng)
		
		# Fewer offices on upper floors (more realistic office building)
		var rooms_on_this_floor := min(2, num_rooms - floor_idx)
		for i in range(rooms_on_this_floor):
			var parent := select_parent_node(rng)
			if parent:
				create_office_or_corridor(parent, Vector2.ZERO, rng)

func create_enclosed_space(parent_node: Node3D, offset: Vector2, rng: RandomNumberGenerator, is_lobby := false):
	# Create a fully enclosed space with walls on all sides
	var room_w := rng.randf_range(14.0, 20.0)  # Larger lobby area
	var room_h := rng.randf_range(14.0, 20.0)
	
	var space_node := Node3D.new()
	space_node.name = "LobbySpace" if is_lobby else "OfficeSpace" + str(rng.randi())
	parent_node.add_child(space_node)
	space_node.position.x = offset.x
	space_node.position.z = offset.y
	
	# Floor for this space
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.32, 0.35) if is_lobby else Color(0.18, 0.20, 0.24)
	
	var floor_mesh := BoxMesh.new()
	floor_mesh.material = floor_mat
	floor_mesh.size = Vector3(room_w, 0.5, room_h)
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = floor_mesh
	
	parent_node.add_child(mesh_inst)
	
	# Fully enclosed walls (no gaps except for doors to other areas)
	create_enclosed_walls(space_node, room_w, room_h, rng)

func create_office_or_corridor(parent_node: Node3D, offset: Vector2, rng: RandomNumberGenerator):
	var is_office := rng.randf() > 0.4  # 60% chance of office
	
	if is_office:
		create_enclosed_office(parent_node, offset, rng)
	else:
		create_corridor(parent_node, offset, rng)

func create_enclosed_office(parent_node: Node3D, offset: Vector2, rng: RandomNumberGenerator):
	var office_w := rng.randf_range(office_size_range_min, office_size_range_max)
	var office_h := rng.randf_range(office_size_range_min, office_size_range_max)
	
	var office_node := Node3D.new()
	office_node.name = "Office" + str(rng.randi())
	parent_node.add_child(office_node)
	office_node.position.x = offset.x
	office_node.position.z = offset.y
	
	# Office floor (darker for hiding)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.18, 0.22)
	
	var floor_mesh := BoxMesh.new()
	floor_mesh.material = floor_mat
	floor_mesh.size = Vector3(office_w, 0.4, office_h)
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = floor_mesh
	
	parent_node.add_child(mesh_inst)
	
	# Fully enclosed walls for privacy (hiding spots!)
	create_enclosed_walls(office_node, office_w, office_h, rng)
	
	# Add office desk as cover object
	add_office_desk(office_node, rng)

func create_corridor(parent_node: Node3D, offset: Vector2, rng: RandomNumberGenerator):
	var corridor_w := rng.randf_range(corridor_width * 1.5, corridor_width * 2.5)
	var corridor_h := rng.randf_range(corridor_width * 0.8, corridor_width * 1.5)
	
	var corridor_node := Node3D.new()
	corridor_node.name = "Corridor" + str(rng.randi())
	parent_node.add_child(corridor_node)
	corridor_node.position.x = offset.x
	corridor_node.position.z = offset.y
	
	# Corridor floor (slightly lighter than offices)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.25, 0.28, 0.32)
	
	var floor_mesh := BoxMesh.new()
	floor_mesh.material = floor_mat
	floor_mesh.size = Vector3(corridor_w, 0.4, corridor_h)
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = floor_mesh
	
	parent_node.add_child(mesh_inst)

func create_enclosed_walls(parent: Node3D, width: float, height: float, rng: RandomNumberGenerator):
	"""Create fully enclosed walls (4 sides forming a closed room)."""
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.12, 0.10, 0.15)  # Dark office walls
	
	for side in range(4):
		var wall_node := Node3D.new()
		wall_node.name = "Wall" + str(side)
		
		# Position each wall to form a closed box around the center
		var pos_offset := Vector2(0.0, height / 2.0) if side == 1 else \
			Vector2(width/2.0, height/2.0) if side == 2 else \
			-Vector2(width/2.0, height/2.0) if side == 3 else \
			-Vector2(0.0, height/2.0)
		
		wall_node.position = pos_offset
		
		var wall_mesh := BoxMesh.new()
		# Wall thickness is small but enough to be solid
		wall_mesh.size = Vector3(height / 2.0, 4.5, width / 2.0 if side != 1 else height / 2.0)
		
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = wall_mesh
		
		parent.add_child(wall_node)
		parent.add_child(mesh_inst)

func add_office_desk(parent: Node3D, rng: RandomNumberGenerator):
	"""Add a desk as cover/hiding spot in office."""
	var desk_size := Vector3(rng.randf_range(1.5, 2.5), 0.9, rng.randf_range(1.8, 2.5))
	
	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.35, 0.28, 0.22)
	
	var desk_mesh := BoxMesh.new()
	desk_mesh.material = desk_mat
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = desk_mesh
	# Position at random location within office bounds
	mesh_inst.position = Vector3(
		rng.randf_range(-desk_size.x/2 + 0.5, desk_size.x/2 - 0.5),
		0.45,
		rng.randf_range(-desk_size.z/2 + 0.5, desk_size.z/2 - 0.5)
	)
	
	parent.add_child(mesh_inst)

func add_office_furniture(rng: RandomNumberGenerator):
	"""Add random furniture pieces as additional hiding spots."""
	for room in get_children():
		if room.get_name().startswith("Office") or room.get_name() == "LobbySpace":
			# Add 1-2 cover objects per office/lobby
			var num_furniture := rng.randi_range(1, 3)
			
			for i in range(num_furniture):
				var furniture_type := rng.randi_range(0, 3)
				
				match furniture_type:
					0: add_file_cabinet(room, rng)
					1: add_bookshelf(room, rng)
					2: add_chair(room, rng)
					3: add_plant(room, rng)

func add_file_cabinet(parent: Node3D, rng: RandomNumberGenerator):
	var cabinet_size := Vector3(rng.randf_range(0.8, 1.5), 1.8, rng.randf_range(1.2, 2.0))
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.38, 0.32)
	
	var mesh := BoxMesh.new()
	mesh.material = mat
	
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = Vector3(
		rng.randf_range(-cabinet_size.x/2 + 0.3, cabinet_size.x/2 - 0.3),
		cabinet_size.y / 2.0,
		rng.randf_range(-cabinet_size.z/2 + 0.3, cabinet_size.z/2 - 0.3)
	)
	
	parent.add_child(inst)

func add_bookshelf(parent: Node3D, rng: RandomNumberGenerator):
	var shelf_size := Vector3(rng.randf_range(1.2, 2.0), 2.2, rng.randf_range(0.4, 0.7))
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.42, 0.38)
	
	var mesh := BoxMesh.new()
	mesh.material = mat
	
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = Vector3(
		rng.randf_range(-shelf_size.x/2 + 0.3, shelf_size.x/2 - 0.3),
		shelf_size.y / 2.0,
		rng.randf_range(-shelf_size.z/2 + 0.3, shelf_size.z/2 - 0.3)
	)
	
	parent.add_child(inst)

func add_chair(parent: Node3D, rng: RandomNumberGenerator):
	var chair_size := Vector3(rng.randf_range(0.6, 1.0), 0.9, rng.randf_range(0.8, 1.2))
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.35, 0.42)
	
	var mesh := BoxMesh.new()
	mesh.material = mat
	
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = Vector3(
		rng.randf_range(-chair_size.x/2 + 0.3, chair_size.x/2 - 0.3),
		chair_size.y / 2.0,
		rng.randf_range(-chair_size.z/2 + 0.3, chair_size.z/2 - 0.3)
	)
	
	parent.add_child(inst)

func add_plant(parent: Node3D, rng: RandomNumberGenerator):
	var plant_size := Vector3(rng.randf_range(0.8, 1.5), 1.4, rng.randf_range(0.6, 1.0))
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.72, 0.42)
	
	var mesh := BoxMesh.new()
	mesh.material = mat
	
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = Vector3(
		rng.randf_range(-plant_size.x/2 + 0.3, plant_size.x/2 - 0.3),
		plant_size.y / 2.0,
		rng.randf_range(-plant_size.z/2 + 0.3, plant_size.z/2 - 0.3)
	)
	
	parent.add_child(inst)

func create_vertical_access(from_floor: Node3D, to_floor: Node3D, rng: RandomNumberGenerator):
	var access_node := Node3D.new()
	access_node.name = "StairsOrLadder"
	from_floor.add_child(access_node)
	
	# 70% stairs (solid), 30% ladder (for variety)
	if rng.randf() < 0.7:
		create_staircase(access_node, to_floor.position.y - from_floor.position.y, rng)
	else:
		create_ladder(access_node, to_floor.position.y - from_floor.position.y, rng)

func create_staircase(parent: Node3D, total_height: float, rng: RandomNumberGenerator):
	var num_steps := int(total_height / 0.25) + 1
	
	for i in range(num_steps):
		var step_y := float(i) * 0.25
		
		var step_mesh := BoxMesh.new()
		step_mesh.size = Vector3(2.0, 0.25, rng.randf_range(1.8, 2.5))
		
		var step_mat := StandardMaterial3D.new()
		step_mat.albedo_color = Color(0.4, 0.35, 0.3)
		step_mesh.material = step_mat
		
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = step_mesh
		mesh_inst.position = Vector3(rng.randf_range(-1, 1), step_y, rng.randf_range(-1, 1))
		
		parent.add_child(mesh_inst)

func create_ladder(parent: Node3D, total_height: float, rng: RandomNumberGenerator):
	var num_rungs := int(total_height / 0.35) + 2
	
	for i in range(num_rungs):
		var rung_y := float(i) * 0.35
		
		var rung_mesh := BoxMesh.new()
		rung_mesh.size = Vector3(0.6, 0.1, rng.randf_range(2.8, 3.2))
		
		var rung_mat := StandardMaterial3D.new()
		rung_mat.albedo_color = Color(0.25, 0.25, 0.28)
		rung_mesh.material = rung_mat
		
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = rung_mesh
		mesh_inst.position = Vector3(rng.randf_range(-1, 1), rung_y, rng.randf_range(-1, 1))
		
		parent.add_child(mesh_inst)

func add_doors_and_windows(rng: RandomNumberGenerator):
	for room in get_children():
		if room.get_name().startswith("Office") or room.get_name() == "LobbySpace":
			var pos := Vector2(0.0, 0.0) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			
			if rng.randf() < 0.5:
				create_doorway(room, pos, rng)

func create_doorway(parent_node: Node3D, offset: Vector2, rng: RandomNumberGenerator):
	var door_height := 2.5
	var door_width := rng.randf_range(1.2, 1.8)
	
	for side in range(4):
		var pos_offset := Vector2(0.0, door_height / 2.0) if side == 1 else \
			Vector2(door_width/2.0, door_height/2.0) if side == 2 else \
			-Vector2(door_width/2.0, door_height/2.0) if side == 3 else \
			-Vector2(0.0, door_height/2.0)
		
		var wall_node := Node3D.new()
		wall_node.name = "DoorWall" + str(side)
		wall_node.position = pos_offset
		
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(door_width if side != 1 else door_height / 2.0, 
			door_height - (door_height * 0.4), 
			door_width/2.0 if side != 1 else door_height/2.0)
		
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = wall_mesh
		
		parent_node.add_child(wall_node)
		parent_node.add_child(mesh_inst)

func select_parent_node(rng: RandomNumberGenerator):
	var candidates := []
	for child in get_children():
		if child.get_name().startswith("Lobby") or \
		   child.get_name().startswith("Office") or \
		   child.get_name() == "Corridor" or \
		   child.get_child_count() > 0:
			candidates.append(child)
	
	if candidates.is_empty():
		return null
	
	return candidates[rng.randi_range(0, candidates.size()-1)]

func calculate_room_offset(parent_node: Node3D, rng: RandomNumberGenerator):
	var base_distance := rng.randf_range(corridor_width * 2.5, corridor_width * 4.5)
	var angle := rng.randf() * 0.5
	
	return Vector2(
		base_distance * cos(angle), 
		base_distance * sin(angle)
	)
