class_name TestHideSeek extends Node3D

@export_group("Game Settings")
@export var round_duration: float = 60.0 as float
@export var max_rounds: int = 5 as int
@export var num_ai_hiders: int = 4 as int
@export var seeker_delay: float = 3.0 as float

# Runtime state
var current_round: int = 1 as int
var time_remaining: float = round_duration as float
var is_seeker_active: bool = false as bool
var hiders: Array[CharacterBody3D] = [] as Array[CharacterBody3D]
var seeker_player: CharacterBody3D = null as CharacterBody3D

func _ready():
	_setup_game()
	start_new_round()

func _setup_game():
	print("[TestHideSeek] Setting up game with %d AI hiders" % num_ai_hiders)
	
	# Spawn AI hiders at random positions near spawn
	for i in range(num_ai_hiders):
		var pos := Vector3(randf_range(-15, 15), 2, randf_range(-15, 15))
		pos.y += get_closest_ground_height(pos) - 2
		
		var hider_scene := preload("res://scenes/player.tscn")
		if not hider_scene:
			continue
			
		var hider := hider_scene.instantiate() as CharacterBody3D
		hider.position = pos
		hider.set_peer_id(randi_range(2, 6))
		hider.role = HideSeekGameManager.PlayerRole.HIDER
		
		add_child(hider)
		hiders.append(hider)

func get_closest_ground_height(position: Vector3) -> float:
	if not has_node("BSPTerrainGenerator"):
		return 5.0
	
	var gen := get_node_or_null("BSPTerrainGenerator") as BSPTerrainGenerator
	if not gen or not gen.has_method("get_terrain_height_at"):
		return 5.0
	
	return gen.get_terrain_height_at(position)

func start_new_round():
	time_remaining = round_duration
	is_seeker_active = false
	
	print("[TestHideSeek] Round %d starting! Hiders: %d" % [current_round, hiders.size()])
	
	# Assign roles
	for peer_id in players.keys():
		var role = HideSeekGameManager.PlayerRole.SEEKER if peer_id == 1 else HideSeekGameManager.PlayerRole.HIDER
		
		if role == HideSeekGameManager.PlayerRole.SEEKER and not seeker_player:
			seeker_player = _find_player_by_peer_id(peer_id)
		elif role == HideSeekGameManager.PlayerRole.HIDER:
			hiders.append(_find_player_by_peer_id(peer_id))

func start_seeker_phase():
	is_seeker_active = true
	
	print("[TestHideSeek] Seeker phase starting! Delay: %.1fs" % seeker_delay)
	
	await get_tree().create_timer(seeker_delay).timeout
	
	# Reveal hiders to seeker
	for hider in hiders:
		hider.make_visible_to_seeker(true)

func end_round(force_time_remaining: float = 0.0):
	time_remaining = force_time_remaining if force_time_remaining > 0 else time_remaining
	
	print("[TestHideSeek] Round ended! Time remaining: %.1fs" % time_remaining)
	
	if current_round < max_rounds:
		current_round += 1
		start_new_round()

func _find_player_by_peer_id(peer_id: int) -> CharacterBody3D:
	for child in get_tree().get_root().get_children():
		if child is CharacterBody3D and child.get("peer_id", -1) == peer_id:
			return child
	return null

# Seeker detection logic (called every frame by seeker player or AI)
func check_seeker_detection(seeker_pos: Vector3, detection_range: float = 12.0):
	if not is_seeker_active:
		return
	
	for hider in hiders.duplicate():
		var distance := (hider.global_position - seeker_pos).length()
		
		if distance <= detection_range and hider.is_visible_to_seeker():
			hider.make_found_state(true)
			print("[TestHideSeek] Seeker detected hider at %.1fm!" % distance)

func make_found_state(found: bool):
	is_found = found
	
	if is_found:
		flash_red()
	else:
		restore_color()

func flash_red():
	var current_color := material_override.albedo_color if material_override else Color.WHITE
	material_override.albedo_color = Color.RED
	await get_tree().create_timer(1.0).timeout
	material_override.albedo_color = current_color

func restore_color():
	if not material_override:
		return
	
	var original := base_color.duplicate()
	material_override.albedo_color = found_color
	await get_tree().create_timer(1.0).timeout
	material_override.albedo_color = original
