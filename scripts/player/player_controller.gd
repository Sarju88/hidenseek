extends CharacterBody3D
class_name PlayerController

signal role_changed(role: int)

@export var move_speed: float = 6.0
@export var jump_velocity: float = 8.0
@export var gravity: float = -25.0
@export var sprint_multiplier: float = 1.5
@export var rotation_sensitivity: float = 0.003

# Camera reference (attached to player's container, orbits around)
var camera := Camera3D.null

func _ready():
	add_to_group("player")
	rotate_y(-90 * DEG_TO_RAD)  # Face forward initially

func _physics_process(delta):
	if is_instance_valid(camera):
		camera.update_orbit_target(delta, rotation_sensitivity)
	
	move_and_collide()

func move_and_collide():
	var input_dir := get_input_direction()
	var velocity := Vector3.ZERO
	
	# Apply horizontal movement based on camera view direction (WASD moves player through space)
	if input_dir != Vector2.ZERO:
		# Get the direction the player is facing from camera orientation  
		var forward := global_transform.basis.z.rotated(Vector3.UP, current_rotation.x)
		var right := forward.cross(Vector3.UP).normalized()
		
		velocity.x = (input_dir.x * right + input_dir.y * forward).x
		velocity.z = (input_dir.x * right + input_dir.y * forward).z
	
	# Apply gravity and vertical velocity
	velocity.y += gravity * delta
	
	# Jump on space/Up arrow if grounded
	if Input.is_action_just_pressed("jump") and is_on_ground():
		velocity.y = jump_velocity
	
	# Apply velocity to body
	.velocity = velocity
	
	move_and_slide()

func get_input_direction() -> Vector2:
	var direction := Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		direction.y += 1.0
	if Input.is_action_pressed("move_backward"):
		direction.y -= 1.0
	if Input.is_action_pressed("move_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right"):
		direction.x += 1.0
	
	return direction.normalized()

func get_current_rotation() -> float:
	return current_rotation.x

# Internal state (managed by camera script)
var current_rotation := 0.0 as float
