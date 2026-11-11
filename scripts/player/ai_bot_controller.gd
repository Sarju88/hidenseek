class_name AIBotController extends CharacterBody3D

signal behavior_updated(mode: String)

@export_group("AI Settings")
@export var role: HideSeekGameManager.PlayerRole = HideSeekGameManager.PlayerRole.HIDER as int
@export var is_seeker_bot := false as bool
@export var aggressiveness: float = 0.7 as float # 0.0 to 1.0
@export var wander_radius: float = 8.0 as float

@export_group("Seeker AI")
@export var seeker_detection_range: float = 15.0 as float
@export var seeker_search_speed: float = 4.0 as float
@export var seeker_patrol_points: Array[Vector3] = [] # Override for custom patrol

@export_group("Hider AI")
@export var hider_noise_chance: float = 0.15 as float # Chance to make noise per second
@export var hider_hide_threshold: float = 8.0 as float # Distance from seeker to hide
@export var hider_escape_speed: float = 7.0 as float

# Runtime state
var current_mode: String = "idle"
var target_position: Vector3 = Vector3.ZERO
var last_noise_time: float = 0.0
var noise_timer: float = 0.0
var is_fleeing := false
var flee_target: Vector3 = Vector3.ZERO

func _ready():
	# Set peer ID for network sync
	set_peer_id(1) # Default to seeker for bots
	
	# Initialize patrol points if none set
	if seeker_patrol_points.is_empty():
		seeker_patrol_points = [
			Vector3(-20, 5, -20),
			Vector3(20, 5, -20),
			Vector3(0, 5, -40),
			Vector3(0, 5, 40)
		]

func _physics_process(delta: float) -> void:
	if not is_seeker_bot and role == HideSeekGameManager.PlayerRole.HIDER:
		_handle_hider_ai(delta)
	else:
		_handle_seeker_ai(delta)

func _handle_hider_ai(delta: float):
	"""AI behavior for hiders - hide, flee, or wander."""
	
	var seeker_pos := get_seeker_position() if is_seeker_bot else Vector3.ZERO
	
	if not is_fleeing and (seeker_pos.distance_to(global_position) < hider_hide_threshold):
		current_mode = "hiding"
		# Slow down when hiding
		speed *= 0.5
		
	elif is_fleeing:
		current_mode = "fleeing"
		# Sprint away from seeker
		target_position = flee_target
	else:
		current_mode = "wandering"
		# Wander randomly
		if randf() < 0.02: # Change direction occasionally
			target_position = global_position + Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius)).normalized() * wander_radius
	
	move_towards_target(delta)

func _handle_seeker_ai(delta: float):
	"""AI behavior for seekers - search and hunt."""
	
	var closest_hider := get_closest_hider()
	var distance_to_hider := closest_hider.distance_to(global_position) if closest_hider else INF
	
	if distance_to_hider < seeker_detection_range:
		current_mode = "hunting"
		# Move towards hider
		target_position = closest_hider.global_position
	else:
		current_mode = "patrolling"
		# Patrol or wander when no targets nearby
		if not is_fleeing and (seeker_patrol_points.is_empty() or randf() < 0.01):
			target_position = seeker_patrol_points[randi_range(0, max(1, seeker_patrol_points.size()) - 1)]

	move_towards_target(delta)

func move_towards_target(_delta: float):
	"""Move towards current target position."""
	if target_position == Vector3.ZERO:
		return
	
	var direction := (target_position - global_position).normalized()
	
	# Seeker moves faster when hunting
	var effective_speed := seeker_search_speed if current_mode == "hunting" else speed
	
	velocity.x = direction.x * effective_speed
	velocity.z = direction.z * effective_speed

func get_seeker_position() -> Vector3:
	"""Get the seeker's position for AI calculations."""
	if is_seeker_bot and has_node("SeekerBot"):
		return get_node("SeekerBot").global_position
	elif role == HideSeekGameManager.PlayerRole.SEEKER:
		return global_position
	else:
		return Vector3.ZERO

func get_closest_hider() -> CharacterBody3D:
	"""Find the closest hider to this bot."""
	if not is_seeker_bot and role != HideSeekGameManager.PlayerRole.SEEKER:
		return null
	
	var closest := null
	var min_distance := INF
	
	for child in get_tree().get_root().get_children():
		if child is CharacterBody3D and child.role == HideSeekGameManager.PlayerRole.HIDER:
			var dist := (child.global_position - global_position).length()
			if dist < min_distance:
				min_distance = dist
				closest = child
	
	return closest

func make_noise() -> void:
	"""Create noise that can be detected by the seeker."""
	noise_timer += 1.0 # Accumulate time for periodic noise
	current_mode = "noising"
	
	if noise_timer >= randf_range(1.0, 3.0):
		noise_timer = 0.0
		print("[AI Bot %s] Made noise!" % get("nick", "Unknown"))

func check_noise_detection(seeker_pos: Vector3) -> bool:
	"""Check if this hider's noise can be detected."""
	var distance := (seeker_pos - global_position).length()
	return distance <= seeker_detection_range * 0.8 # Slightly smaller than visual range

func start_fleeing(target: Vector3 = Vector3.ZERO) -> void:
	"""Start fleeing from the seeker."""
	is_fleeing = true
	flee_target = target if target != Vector3.ZERO else global_position + Vector3(1, 0, 1).normalized() * wander_radius
	
	# Boost speed when fleeing
	speed = hider_escape_speed

func stop_fleeing() -> void:
	"""Stop fleeing and return to normal behavior."""
	is_fleeing = false
	flee_target = Vector3.ZERO
	speed *= 1.0 # Reset speed multiplier

func get_ai_status() -> Dictionary:
	"""Return current AI status for debugging/UI."""
	return {
		mode = current_mode,
		target_position = target_position,
		is_fleeing = is_fleeing,
		distance_to_seeker = (get_seeker_position() - global_position).length(),
		speed_ratio = speed / 6.0 # Normalize to base speed
	}

# Utility functions for debugging and testing
func debug_draw_target_indicator():
	"""Draw a visual indicator of the AI's target."""
	if not has_node("DebugIndicator"):
		var indicator := Marker3D.new()
		indicator.name = "DebugIndicator"
		add_child(indicator)
	
	return get_node_or_null("DebugIndicator")

func debug_draw_patrol_points():
	"""Draw patrol points for debugging."""
	for i in range(seeker_patrol_points.size()):
		var point := Marker3D.new()
		point.position = seeker_patrol_points[i]
		point.set_debug_overlay_color(Color.GREEN)
		add_child(point)
