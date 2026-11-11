extends Node
class_name GameManager

signal game_started_event()
signal round_complete_event(winner_type: PlayerRole)
signal seeker_phase_started_event()
signal hider_phase_started_event()

enum PlayerRole { SEEKER, HIDER }

@export_group("Game Settings")
@export var round_duration: float = 60.0 as float
@export var total_rounds: int = 5 as int

# Multiplayer Setup
@export var seeker_player_scene: PackedScene
@export var hider_player_scene: PackedScene

var current_role: PlayerRole = PlayerRole.HIDER
var is_seeker_phase_active: bool = false
var game_started_flag := false

var total_seeker_wins: int = 0
var total_hider_wins: int = 0

# Safe Zone Tracking
var safe_zone_active_count: int = 0

func _ready():
	add_to_group("game_manager")

	# Set up input for fog toggle on local player
	if Input.is_action_just_pressed("fog"):
		toggle_fog()


func start_game() -> void:
	game_started_flag = true
	current_role = PlayerRole.HIDER  # First round defaults to hider
	is_seeker_phase_active = false
	game_started_event.emit()

	# Spawn seeker (player 1) and hiders (players 2+)
	for i in range(4):
		var player_scene: PackedScene
		if i == 0:
			player_scene = seeker_player_scene
		else:
			player_scene = hider_player_scene
		
		if player_scene:
			var player := player_scene.instantiate() as CharacterBody3D
			get_tree().current_scene.add_child(player)
			player.name = "Player_%d" % i
			player.set_multiplayer_authority(i + 1)


func toggle_fog():
	is_seeker_phase_active = not is_seeker_phase_active

	if is_seeker_phase_active:
		seeker_phase_started_event.emit()
	else:
		hider_phase_started_event.emit()


func register_player_for_round(player_id: int, role: PlayerRole):
	current_role = role
	print("[GameManager] Player %d assigned as %s" % [player_id, _role_name(role)])

	if role == PlayerRole.SEEKER:
		is_seeker_phase_active = true
	
	# Activate seeker powers if in seeker phase
	if is_seeker_phase_active and player_id == 1:
		player_activated_radar()


func award_round_win(winner_type: PlayerRole):
	if winner_type == PlayerRole.SEEKER:
		total_seeker_wins += 1
	else:
		total_hider_wins += 1
	
	print("[GameManager] Round complete - %s wins! Seeker: %d, Hider: %d" % [
		_role_name(winner_type), total_seeker_wins, total_hider_wins
	])

	round_complete_event.emit(winner_type)


func get_score_display() -> String:
	return "%d - %d (Seeker - Hider)" % [total_seeker_wins, total_hider_wins]


func update_safe_zone_status(player: CharacterBody3D):
	if player is Character and player.safe_zone_active:
		safe_zone_active_count += 1
	else:
		safe_zone_active_count -= 1
	
	if multiplayer.is_server():
			request_update_safe_zone_status.rpc_id(1, safe_zone_active_count)


@rpc("any_peer", "call_local", "reliable")
func request_update_safe_zone_status(count: int) -> void:
	if not multiplayer.is_server(): return
	safe_zone_active_count = count


# Radar Pulse System for Seekers
var is_radar_active: bool = false

func player_activated_radar() -> void:
	is_radar_active = true
	
	# Auto-trigger radar pulse every 0.5s when held
	if Input.is_action_pressed("radar"):
		for body in get_overlapping_bodies():
			var player = body.get_node_or_null("Character") as Character
			if not player or player.is_multiplayer_authority() == false: continue
			
			var distance = body.global_position.distance_to(body.global_position)
			
			if distance <= 25.0 and distance > 1.0:
				# Emit radar detection signal for seekers to react to
				pass


func _on_sound_detected(sound_distance: float):
	print("[GameManager] Sound detected from seeker at %.2fm" % sound_distance)
