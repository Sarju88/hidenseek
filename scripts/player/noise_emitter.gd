class_name NoiseEmitter extends Node3D

signal noise_detected(noise_level: float, emitter_position: Vector3)

@export var detection_range: float = 8.0 as float
@export var base_noise_threshold: float = 50.0 as float
@export var sprint_multiplier: float = 2.0 as float
@export var crouch_reduction: float = 0.5 as float

var _current_noise_level: float = 0.0
var _is_sprinting: bool = false
var _is_crouching: bool = false

func _ready() -> void:
	# Connect to player movement signals (will be wired in PlayerController)
	get_tree().get_first_node_in_group("PlayerController").player_moved.connect(_on_player_moved)
	get_tree().get_first_node_in_group("PlayerController").stealth_state_changed.connect(_on_stealth_state_changed)

func _process(delta: float) -> void:
	# Smoothly decay noise level when not moving aggressively
	if _current_noise_level > 0 and not _is_sprinting:
		_current_noise_level = max(0.0, _current_noise_level - delta * 15.0)

func set_sprinting(sprinting: bool) -> void:
	_is_sprinting = sprinting
	
	if sprinting:
		# Increase noise level when sprinting
		_current_noise_level = min(100.0, _current_noise_level + base_noise_threshold * sprint_multiplier)
	else:
		# Gradually reduce noise when stopping sprint
		_is_sprinting = false

func set_crouching(crouching: bool) -> void:
	_is_crouching = crouching
	
	if crouching:
		# Reduce noise level when crouching (stealth mode)
		_current_noise_level = max(0.0, _current_noise_level * crouch_reduction)

func get_noise_level() -> float:
	return _current_noise_level

func check_for_detection(seeker_position: Vector3) -> bool:
	"""Check if noise level would trigger seeker detection."""
	if not is_instance_valid(get_tree()):
		return false
	
	var distance := (global_position - seeker_position).length()
	
	if distance > detection_range * 1.2:
		# Too far to matter
		return false
	
	var effective_threshold := base_noise_threshold
	
	if _is_crouching:
		effective_threshold *= crouch_reduction
	
	# Check if noise exceeds threshold at this distance
	var normalized_distance := min(1.0, (detection_range - distance) / detection_range)
	var required_noise := effective_threshold * (1.0 - normalized_distance * 0.5)
	
	return _current_noise_level > required_noise

func reset_noise() -> void:
	_current_noise_level = 0.0

# Called when player moves to update noise based on movement type
func _on_player_moved(position: Vector3, velocity: Vector3):
	if not is_instance_valid(get_tree()):
		return
	
	var speed := velocity.length()
	
	# Sprinting detected (high speed)
	if speed > 12.0 and not _is_sprinting:
		set_sprinting(true)

func _on_stealth_state_changed(is_crouching: bool):
	set_crouching(is_crouching)
