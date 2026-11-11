extends Node
class_name HideSeekGameManager

signal round_started(round_number: int)
signal round_ended(seeker_won: bool, time_left: float)

enum PlayerRole { SEEKER, HIDER }

@export_group("Game Settings")
@export var round_duration: float = 60.0 as float
@export var total_rounds: int = 5 as int

# Multiplayer Setup
@export var seeker_player_scene: PackedScene
@export var hider_player_scene: PackedScene

var current_role: PlayerRole = PlayerRole.HIDER
var is_seeker_phase_active: bool = false

var safe_zone_active_count: int = 0

func _ready():
	add_to_group("game_manager")


func start_game() -> void:
	current_role = PlayerRole.HIDER
	is_seeker_phase_active = false
	
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
		round_started.emit(1)
	else:
		round_ended.emit(false, round_duration)


func register_player_for_round(player_id: int, role: PlayerRole):
	current_role = role
	print("[GameManager] Player %d assigned as %s" % [player_id, _role_name(role)])

	if role == PlayerRole.SEEKER:
		is_seeker_phase_active = true
	
	# Activate seeker powers if in seeker phase
	if is_seeker_phase_active and player_id == 1:
		player_activated_radar()


func award_round_win(winner_type: PlayerRole):
	var seeker_won = (winner_type == PlayerRole.SEEKER)
	print("[GameManager] Round complete - %s wins!" % [_role_name(winner_type)])

	round_ended.emit(seeker_won, round_duration)


func _role_name(role: PlayerRole) -> String:
	if role == PlayerRole.SEEKER:
		return "SEEKER"
	return "HIDER"


# Radar Pulse System for Seekers
var is_radar_active: bool = false
var seeker_position: Vector3 = Vector3.ZERO

func player_activated_radar() -> void:
	is_radar_active = true
	
	# Auto-trigger radar pulse every 0.5s when held
	if Input.is_action_pressed("radar"):
		var scene := get_tree().current_scene
		if not scene:
			return
		# This singleton is a Node; find characters and filter by radar range.
		for body in scene.find_children("*", "CharacterBody3D", true, false):
			var player = body as Character
			if not player or player.is_multiplayer_authority() == false: continue
			
			# Calculate distance from seeker to detected hider
			var distance = seeker_position.distance_to(body.global_position)
			
			if distance <= 25.0 and distance > 1.0:
				# Emit radar detection signal for seekers to react to
				pass


func _on_sound_detected(sound_distance: float):
	print("[GameManager] Sound detected from seeker at %.2fm" % sound_distance)
