class_name SpringArmCharacter
extends Node3D

signal perspective_changed(first_person: bool)

const MOUSE_SENSIBILITY: float = 0.005

@export_category("Objects")
@export var _spring_arm: SpringArm3D = null
@export var _first_person_anchor: Node3D = null

@export_category("Camera Perspective")
@export_range(0.0, 10.0, 0.05) var third_person_distance := 3.2
@export_range(0.0, 1.0, 0.05) var first_person_distance := 0.0
@export_range(0.0, 3.0, 0.05) var third_person_height := 1.65
@export_range(1.0, 179.0, 1.0) var third_person_fov := 75.0
@export_range(1.0, 179.0, 1.0) var first_person_fov := 90.0

var is_first_person := false
var _yaw := 0.0
var _pitch := 0.0

@onready var _camera: Camera3D = _spring_arm.get_node_or_null("Camera3D") as Camera3D


func _ready() -> void:
	_yaw = rotation.y
	_pitch = -0.16
	_apply_axis_lock()
	_apply_perspective()
	if _spring_arm:
		# Camera collides with the building and furniture, excluding its owner.
		_spring_arm.collision_mask = 2
		var probe := SphereShape3D.new()
		probe.radius = 0.18
		_spring_arm.shape = probe
		_spring_arm.margin = 0.08


func _process(_delta: float) -> void:
	_apply_axis_lock()
	if is_first_person and _spring_arm and _first_person_anchor:
		_spring_arm.global_position = _first_person_anchor.global_position


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	var current_scene := get_tree().get_current_scene()
	if current_scene and current_scene.has_method("is_camera_input_blocked"):
		if current_scene.is_camera_input_blocked():
			return


	if not (event is InputEventMouseMotion):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	_yaw = wrapf(_yaw - event.relative.x * MOUSE_SENSIBILITY, -PI, PI)
	_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSIBILITY, -PI / 2.1, PI / 2.1)
	_apply_axis_lock()


func _apply_axis_lock() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	if _spring_arm:
		_spring_arm.rotation = Vector3(_pitch, 0.0, 0.0)
	if _camera:
		_camera.rotation = Vector3.ZERO


func _apply_perspective() -> void:
	if not _spring_arm:
		return
	if is_first_person:
		_spring_arm.spring_length = first_person_distance
		if _first_person_anchor:
			_spring_arm.global_position = _first_person_anchor.global_position
		if _camera:
			_camera.fov = first_person_fov
	else:
		_spring_arm.spring_length = third_person_distance
		_spring_arm.position = Vector3(0.45, third_person_height, 0.0)
		if _camera:
			_camera.fov = third_person_fov
