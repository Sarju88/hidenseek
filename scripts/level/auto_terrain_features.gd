class_name AutoTerrainFeatures extends Node3D

signal features_added()

@export_group("Feature Settings")
@export var add_stairs := true as bool
@export var add_ladders := true as bool
@export var stairs_per_building := 1 as int
@export var ladders_per_building := 0 as int

# Reference to terrain generator for access to generated structures
var terrain_generator: BSPTerrainGenerator = null

func _ready():
	# Connect to terrain generation signal if available
	if terrain_generator:
		terrain_generator.terrain_generated.connect(_on_terrain_ready)

func set_terrain_generator(gen: BSPTerrainGenerator):
	"""Set the terrain generator reference."""
	terrain_generator = gen

func _on_terrain_ready():
	"""Add stairs and ladders to all generated buildings."""
	if not terrain_generator or terrain_generator.generated_structures.is_empty():
		return
	
	var features_added := 0
	
	for building in terrain_generator.generated_structures:
		if not is_instance_valid(building):
			continue
		
		# Add stairs if enabled
		if add_stairs and features_added < stairs_per_building:
			_add_feature_to_building(building, "stairs")
			features_added += 1
		
		# Add ladders if enabled
		if add_ladders and features_added >= stairs_per_building and features_added < stairs_per_building + ladders_per_building:
			_add_feature_to_building(building, "ladder")
	
	emit_signal("features_added")

func _add_feature_to_building(building: Node3D, feature_type: String) -> void:
	"""Add a stair or ladder to the specified building."""
	var feature_scene := preload("res://scenes/terrain/stairs.tscn") as PackedScene
	
	if not feature_scene:
		push_warning("AutoTerrainFeatures: Stairs scene not found")
		return
	
	var feature_instance := feature_scene.instantiate() as Node3D
	feature_instance.name = "StairFeature"
	
	# Position at building edge
	var offset := Vector3(
		randf_range(-building.size.x/2, building.size.x/2),
		building.position.y + 4.0, # Above ground level
		randf_range(-building.size.z/2, building.size.z/2)
	)
	
	feature_instance.position = offset
	
	# Random rotation for variety
	feature_instance.rotation.y = randf_range(0, PI * 2)
	
	building.add_child(feature_instance)
