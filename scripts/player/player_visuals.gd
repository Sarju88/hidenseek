class_name PlayerVisuals extends Node3D

signal visual_effect_triggered(effect_type: String)

@export_group("Appearance")
@export var base_color := Color.WHITE as Color
@export var found_color := Color.RED as Color
@export var crouch_scale: float = 0.6 as float

# Runtime state
var is_found: bool = false as bool
var material_override: StandardMaterial3D = null
var flash_timer: float = 0.0 as float

func _ready():
	_setup_material()

func _setup_material():
	if not has_node("MeshInstance3D"):
		return
	
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh or mesh.get_surface_count() == 0:
		return
	
	material_override = StandardMaterial3D.new()
	mesh.set_surface_material(0, material_override)

func set_found_state(found: bool) -> void:
	is_found = found
	
	if is_found and material_override:
		material_override.albedo_color = found_color
	else:
		material_override.albedo_color = base_color

func flash_red(duration: float = 1.0):
	if not material_override:
		return
	
	var original_color := material_override.albedo_color.duplicate()
	material_override.albedo_color = Color.RED
	
	await get_tree().create_timer(duration).timeout
	
	material_override.albedo_color = original_color

func set_crouch_scale(scale: float) -> void:
	if not has_node("MeshInstance3D"):
		return
	
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh or mesh.get_surface_count() == 0:
		return
	
	mesh.scale.y = scale

func is_visible_to_seeker() -> bool:
	return not is_found
