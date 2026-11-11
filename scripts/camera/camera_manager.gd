extends Node3D
class_name CameraManager

signal camera_rotated(player: CharacterBody3D, new_rotation: float)

@export var rotation_sensitivity := 0.002 as float

var current_rotation := Vector2.ZERO
var target_player := CharacterBody3D.null

func _ready():
	add_to_group("camera")

func set_target_player(player_node: CharacterBody3D):
	target_player = player_node

func _input(event):
	if not is_instance_valid(target_player):
		return
	
	match event.kind:
		InputEvent.MOUSE_MOVE:
			current_rotation += Vector2(event.relative.x * rotation_sensitivity, event.relative.y * rotation_sensitivity)
		
		InputEvent.KEY:
			if event.is_pressed() and event.keycode in [KEY_LEFT, KEY_RIGHT]:
				current_rotation.x += event.keycode == KEY_RIGHT ? rotation_sensitivity : -rotation_sensitivity

func update_player_camera(player_node: CharacterBody3D):
	"""
	Update camera orbit around the given player.
	Called from player controller's _physics_process.
	"""
	if not is_instance_valid(player_node) or target_player != player_node:
		return
	
	var global_pos := player_node.global_position
	var new_rotation_x := current_rotation.x - (player_node.get_current_rotation() if player_node.has_method("get_current_rotation") else 0.0)
	
	# Apply rotation to orbit position
	target_position.y = orbit_height_offset
	current_rotation.x = lerp(current_rotation.x, new_rotation_x * DEG_TO_RAD, 0.1)
