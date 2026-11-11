class_name DetectionRing extends Node3D

signal updated()

@export var detection_range: float = 8.0 as float
@export var ring_color: Color = Color.RED.as_rgb() * 0.6 as Color
@export var ring_thickness: float = 0.2 as float
@export var update_speed: float = 15.0 as float

var _mesh_instance: MeshInstance3D = null
var _plane_mesh: PlaneMesh = null
var _material: StandardMaterial3D = null
var _is_active: bool = false

func _ready() -> void:
	_create_ring()
	
	# Connect to player position updates (will be wired in main level)
	get_tree().get_first_node_in_group("PlayerController").player_moved.connect(_on_player_moved)

func _create_ring() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	
	_plane_mesh = PlaneMesh.new()
	_plane_mesh.radius = detection_range
	_plane_mesh.height = ring_thickness * 2
	
	var surface_material := StandardMaterial3D.new()
	surface_material.albedo_color = ring_color
	surface_material.render_mode = Material.RENDER_MODE_UNSHADED
	
	_mesh_instance.mesh = _plane_mesh
	_mesh_instance.material_override = surface_material

func activate(player: CharacterBody3D) -> void:
	_is_active = true
	player.get_tree().get_first_node_in_group("PlayerController").detection_ring = self
	updated.emit()

func deactivate() -> void:
	_is_active = false
	if has_node("PlayerController"):
		get_node_or_null("PlayerController").detection_ring = null
	updated.emit()

func _on_player_moved(position: Vector3) -> void:
	if not _is_active or not _mesh_instance:
		return
	
	# Smoothly interpolate ring position to player
	var target_position := position + Vector3.UP * 1.5
	_mesh_instance.global_position = _mesh_instance.global_position.lerp(target_position, 0.2)

func get_detection_range() -> float:
	return detection_range
