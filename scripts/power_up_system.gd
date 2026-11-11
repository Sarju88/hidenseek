extends Node3D
class_name PowerUpSystem

signal powerup_collected(player, powerup_type)

enum PowerUpType {
	CAMOUFLAGE,    # Makes hider harder to see (changes color/texture)
	SPEED_BOOST,   # Temporary speed increase for hiders
	INVISIBILITY,  # Brief invisibility cloak
	FLASHBANG      # Stuns seeker temporarily when nearby
}

@export var camouflage_duration: float = 5.0 as float
@export var speed_boost_duration: float = 8.0 as float
@export var invisibility_duration: float = 4.0 as float
@export var flashbang_radius: float = 12.0 as float

var active_powerups: Dictionary = {}  # peer_id -> (powerup_type, expiry_time)
var powerup_spawns: Array[Node3D] = []

func _ready():
	add_to_group("power_ups")
	spawn_powerup_nodes()

func spawn_powerup_nodes(count: int = 5):
	for i in range(count):
		var position = Vector3(
			(randf_range(-40.0, 40.0)),
			2.0,
			(randf_range(-40.0, 40.0))
		)
		
		var powerup_node := PackedScene.new().instance() as Node3D
		if not powerup_node: continue
		
		powerup_node.position = position
		powerup_node.name = "PowerUp_%d" % i
		
		# Create a simple visual indicator (could be replaced with actual models)
		var mesh := SphereMesh.new()
		mesh.radius = 0.8
		var material := StandardMaterial3D.new()
		material.shading_mode = StandardMaterial3D.SHADING_MODE_UNLIT
		material.albedo_color = Color(0, 1, 1)
		
		powerup_node.add_child(mesh)
		powerup_node.add_child(material)
		
		powerup_spawns.append(powerup_node)

func activate_powerup(peer_id: int, powerup_type: PowerUpType) -> void:
	if active_powerups.has(peer_id): return
	
	var expiry = Time.get_ticks_msec() / 1000.0 + get_duration_for_type(powerup_type)
	active_powerups[peer_id] = (powerup_type, expiry)
	
	# Notify player and other peers via RPC if available
	if multiplayer.is_server():
		request_activate_powerup.rpc_id(1, peer_id, powerup_type)
	else:
		request_activate_powerup.rpc_id(multiplayer.get_remote_sender_id(), peer_id, powerup_type)

func get_duration_for_type(powerup_type: PowerUpType) -> float:
	match powerup_type:
		PowerUpType.CAMOUFLAGE: return camouflage_duration
		PowerUpType.SPEED_BOOST: return speed_boost_duration
		PowerUpType.INVISIBILITY: return invisibility_duration
		PowerUpType.FLASHBANG: return 3.0  # Short duration for flashbang effect
	return 5.0

func check_powerup_expiry():
	var now = Time.get_ticks_msec() / 1000.0
	
	for peer_id in active_powerups.keys():
		if active_powerups[peer_id][1] < now:
			active_powerups.erase(peer_id)
			if multiplayer.has_multiplayer_peer():
				request_deactivate_powerup.rpc_id(1, peer_id)

func get_active_powerup_info(peer_id: int):
	return active_powerups.get(peer_id)

# RPC for server to client communication
@rpc("any_peer", "call_local", "reliable")
func request_activate_powerup(peer_id: int, powerup_type: PowerUpType) -> void:
	if not multiplayer.is_server(): return
	
	var info = active_powerups.get(peer_id)
	if not info or info[0] != powerup_type: return
	
	# Apply effect to the target player's character body3D
	for child in get_tree().get_root().get_children():
		if child is CharacterBody3D and child.has_node_or_null("peer_id"):
			var pid = child.get_node_or_null("peer_id").get_int()
			if pid == peer_id:
				child.apply_powerup_effect(powerup_type)

@rpc("any_peer", "reliable")
func request_deactivate_powerup(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	
	var info = active_powerups.get(peer_id)
	if not info: return
	
	# Notify all peers about powerup deactivation
	for child in get_tree().get_root().get_children():
		if child is CharacterBody3D and child.has_node_or_null("peer_id"):
			var pid = child.get_node_or_null("peer_id").get_int()
			if pid == peer_id:
				child.remove_powerup_effect(powerup_type)

func spawn_flashbang(position: Vector3, target_peer_id: int):
	# Create a temporary flashbang effect at position
	for body in get_overlapping_bodies():
		var player = body.get_node_or_null("Character") as Character
		if not player or multiplayer.is_server() == false: continue
		
		var distance = body.global_position.distance_to(position)
		if distance <= flashbang_radius and body.has_node_or_null("peer_id"):
			var pid = body.get_node_or_null("peer_id").get_int()
			if pid != target_peer_id:  # Don't affect the thrower
				player.stun_player(2.0, "Flashbang from powerup")