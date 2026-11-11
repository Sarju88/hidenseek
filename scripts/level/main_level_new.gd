extends Node3D
class_name MainLevel

signal players_spawned(player_count: int)

@onready var building_generator := $BuildingGenerator as BuildingGenerator
@onready var player_container := $PlayersContainer as Node3D

func _ready():
	print("[MainLevel] Script loaded and _ready() called")
	# Initialize building generator (runs procedural generation on first load)
	if not Engine.is_editor_hint():
		var rng_seed = Time.get_ticks_msec()  # Use real time for different layout each session
		building_generator.seed = rng_seed
		print("[MainLevel] Building seed:", rng_seed, " - Office layout will be unique this session")

func spawn_player(role: int, position: Vector3 = Vector3.ZERO) -> CharacterBody3D:
	"""
	Spawn a player at the given position (or building default if not specified).
	Returns the spawned CharacterBody3D node.
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

func get_building_bounds() -> Vector3:
	"""
	Returns approximate building bounds for gameplay constraints.
	"""
	# Office building is roughly 60m x 60m with 3 floors up to ~20m height
	return Vector3(65.0, 25.0, 65.0)
