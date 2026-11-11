class_name TerrainBase extends Node3D

signal terrain_ready()

@export_group("Terrain Settings")
@export var ground_height := 0.0 as float
@export var terrain_scale := 100.0 as float

# Generated mesh for the base terrain
var terrain_mesh: MeshInstance3D = null

func _ready():
	_generate_base_terrain()

func _generate_base_terrain():
	"""Generate a flat ground plane using BSP."""
	var root := BSPTree.new(self, terrain_scale)
	
	# Create main ground plane
	root.intersect_plane(Plane(Vector3.UP, 0.0))
	
	# Subdivide for detail
	for i in range(4):
		root.subdivide()
	
	# Generate mesh from BSP planes
	var vertices := []
	var faces := []
	var normals := []
	var materials := []
	
	# Add ground plane
	var ground_vertices := [
		Vector3(-terrain_scale, ground_height, -terrain_scale),
		Vector3(terrain_scale, ground_height, -terrain_scale),
		Vector3(terrain_scale, ground_height, terrain_scale),
		Vector3(-terrain_scale, ground_height, terrain_scale)
	]
	
	var ground_faces := [
		[0, 1, 2], [0, 2, 3] # Bottom face only (top is covered by buildings)
	]
	
	var ground_normals := [Vector3(0, -1, 0), Vector3(0, -1, 0)]
	
	vertices.append_array(ground_vertices)
	faces.append_array(ground_faces)
	normals.append_array(ground_normals)
	materials.append(TERRAIN_BASE_MATERIAL)
	
	# Create mesh instance
	var surface_mesh := ArrayMesh.new()
	surface_mesh.create_from_arrays(vertices, faces, normals, materials)
	
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = surface_mesh
	terrain_mesh.position = Vector3(0, ground_height, 0)
	add_child(terrain_mesh)
	
	emit_signal("terrain_ready")

# Material reference (set in editor or via code)
var TERRAIN_BASE_MATERIAL: StandardMaterial3D = null

func get_ground_height_at(position: Vector3) -> float:
	"""Get terrain height at a given position."""
	return ground_height # Simple flat terrain for now
