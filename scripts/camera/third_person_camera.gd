extends Camera3D
class_name ThirdPersonCamera

# Camera orbit controls
@export var orbit_radius: float = 7.0
@export var orbit_height_offset: float = 4.5
@export var min_orbit_radius: float = 4.0
@export var max_orbit_radius: float = 12.0
@export var smooth_damping: float = 0.1

# Mouse/Arrow key rotation sensitivity
@export var mouse_sensitivity: float = 0.003
@export var arrow_rotation_speed: float = 2.0

# Spring-arm elastic feel for cartoon style
@export var spring_strength: float = 5.0
@export var damping_factor: float = 0.85

var target_position := Vector3(0, orbit_height_offset, -orbit_radius)
var current_rotation := Vector2.ZERO
var player_target := Node3D.null

func _ready():
	add_to_group("camera")

func set_player(target_node: Node3D):
	"""Set the player node this camera should follow."""
	player_target = target_node

func _process(delta):
	if not player_target or is_instance_valid(player_target) == false:
		return
	
	var target_pos := player_target.global_position
	
	# Calculate ideal orbit position based on mouse/arrows
	update_orbit_target(delta, delta * arrow_rotation_speed)
	
	# Spring-arm elastic follow with damping for cartoon feel
	var desired_offset := target_pos + target_position.rotated(Vector3.UP, current_rotation.x)
	var lerp_factor := min(1.0, smooth_damping / delta)
	
	global_position = lerp(global_position, desired_offset, lerp_factor)

func update_orbit_target(delta: float, rotation_speed: float):
	"""Update orbit target based on mouse position or arrow keys."""
	# Default: no change (player controller will call this with actual delta)
	pass
