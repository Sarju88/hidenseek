extends Node3D
class_name MainLevel

signal players_spawned(player_count: int)

@onready var building_generator := $BuildingGenerator as BuildingGenerator
@onready var player_container := $PlayersContainer as Node3D

# Player camera references (first-person view through character's eyes)
var player_cameras := {}  # player_node -> camera

func _ready():
	# Initialize building generator with unique seed each session
	if not Engine.is_editor_hint():
		var rng_seed = Time.get_ticks_msec()
		building_generator.seed = rng_seed
		print("[MainLevel] Building seed:", rng_seed, " - Layout will be unique this session")

func spawn_player(role: int, position: Vector3 = Vector3.ZERO) -> CharacterBody3D:
	"""
	Spawn a player with third-person camera.
	Camera orbits around character's back/side while WASD moves them through space.
	"""
	var player_scene := get_node_or_null("PlayersContainer").get_node_or_null("PlayerTemplate") as PackedScene
	if not player_scene or not player_scene.instantiate():
		print("[MainLevel] Failed to spawn player template!")
		return null
	
	var player := player_scene.instantiate() as CharacterBody3D
	player_container.add_child(player)
	
	# Set role and position
	player.set_role(role)  # Calls seeker_abilities.gd or default behavior
	if not is_zero_vector(position):
		player.global_position = position
	
	# Connect camera to controller for orbit functionality
	var player_controller := player.get_node_or_null("PlayerController") as PlayerController
	var camera_container := player.get_node_or_null("CameraContainer") as Node3D
	if player_controller and camera_container:
		camera_container.set_meta("_parent_controller", player_controller)
	
	# Emit signal for UI/game logic to update
	players_spawned.emit(1)
	
	return player

func spawn_all_players(seeker_pos: Vector3 = Vector3.ZERO, hider_positions: Array = []) -> int:
	"""
	Spawn all players for a new round.
	Returns total count of spawned players.
	"""
	var seeker := spawn_player(HideSeekGameManager.PlayerRole.SEEKER, seeker_pos)
	if not seeker: return 0
	
	var count = 1
	for pos in hider_positions:
		spawn_player(HideSeekGameManager.PlayerRole.HIDER, pos)
		count += 1
	
	return count

func get_arena_bounds() -> Vector3:
	"""
	Returns approximate building bounds for gameplay constraints.
	The enclosed rooms make this much smaller than the open arena.
	"""
	return Vector3(60.0, 24.0, 60.0)  # ~18m per floor, 3 floors

# Constants (can be exported in editor)
const base_size := 60.0 as float
