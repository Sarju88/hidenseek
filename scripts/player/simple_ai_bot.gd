class_name SimpleAIBot extends CharacterBody3D

signal behavior_updated(mode: String)

@export_group("AI Settings")
@export var role: HideSeekGameManager.PlayerRole = HideSeekGameManager.PlayerRole.HIDER as int
@export var is_seeker_bot := false as bool
@export var aggressiveness: float = 0.7 as float # 0.0 to 1.0
@export var wander_radius: float = 8.0 as float

# Runtime state
var current_mode: String = "idle"
var target_position: Vector3 = Vector3.ZERO
var last_noise_time: float = 0.0
var noise_timer: float = 0.0
var is_fleeing := false
var flee_target: Vector3 = Vector3.ZERO

func _ready():
	# Set peer ID for network sync (1 = seeker by default)
	set_peer_id(1) if is_seeker_bot else set_peer_id(randi_range(2, 6))
	
	# Initialize patrol points if none set
	if not is_seeker_bot and role == HideSeekGameManager.PlayerRole.SEEKER:
		var patrol_points := [
			Vector3(-20, 5, -20),
			Vector3(20, 5, -20),
			Vector3(0, 5, -40),
			Vector3(0, 5, 40)
		]
		add_to_group("seeker_patrol_points")

func _physics_process(delta: float):
	if not is_seeker_bot and role == HideSeekGameManager.PlayerRole.HIDER:
		_handle_hider_ai(delta)
	else:
		_handle_seeker_ai(delta)

func _handle_hider_ai(delta: float):
	"""AI behavior for hiders - hide, flee, or wander."""
	
	var seeker_pos := get_seeker_position() if is_seeker_bot else Vector3.ZERO
	
	if not is_fleeing and (seeker_pos.distance_to(global_position) < 8.0):
		current_mode = "hiding"
		speed *= 0.5
		
	elif is_fleeing:
		current_mode = "fleeing"
		target_position = flee_target
	else:
		current_mode = "wandering"
		if randf() < 0.02:
			target_position = global_position + Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius)).normalized() * wander_radius
	
	move_towards_target(delta)

func _handle_seeker_ai(delta: float):
	"""AI behavior for seekers - search and hunt."""
	
	var closest_hider := get_closest_hider()
	var distance_to_hider := closest_hider.distance_to(global_position) if closest_hider else INF
	
	if distance_to_hider < 15.0:
		current_mode = "hunting"
		target_position = closest_hider.global_position
	else:
		current_mode = "patrolling"
		if not is_fleeing and randf() < 0.01:
			var patrol_points := get_tree().get_nodes_in_group("seeker_patrol_points")
			if not patrol_points.is_empty():
				target_position = patrol_points[randi_range(0, max(1, patrol_points.size()) - 1)].global_position

	move_towards_target(delta)

func move_towards_target(_delta: float):
	"""Move towards current target position."""
	if target_position == Vector3.ZERO:
		return
	
	var direction := (target_position - global_position).normalized()
	
	var effective_speed := 4.0 if current_mode == "hunting" else speed
	
	velocity.x = direction.x * effective_speed
	velocity.z = direction.z * effective_speed

func get_seeker_position() -> Vector3:
	if is_seeker_bot and has_node("SeekerBot"):
		return get_node("SeekerBot").global_position
	elif role == HideSeekGameManager.PlayerRole.SEEKER:
		return global_position
	else:
		return Vector3.ZERO

func get_closest_hider() -> CharacterBody3D:
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
	noise_timer += 1.0
	
	if noise_timer >= randf_range(1.0, 3.0):
		noise_timer = 0.0
		print("[AI Bot %s] Made noise!" % get("nick", "Unknown"))

func check_noise_detection(seeker_pos: Vector3) -> bool:
	var distance := (seeker_pos - global_position).length()
	return distance <= 12.0

func start_fleeing(target: Vector3 = Vector3.ZERO):
	is_fleeing = true
	flee_target = target if target != Vector3.ZERO else global_position + Vector3(1, 0, 1).normalized() * wander_radius
	speed = 7.0

func stop_fleeing():
	is_fleeing = false
	flee_target = Vector3.ZERO
	speed *= 1.0

func get_ai_status() -> Dictionary:
	return {
		mode = current_mode,
		target_position = target_position,
		is_fleeing = is_fleeing,
		distance_to_seeker = (get_seeker_position() - global_position).length(),
		speed_ratio = speed / 6.0
	}
