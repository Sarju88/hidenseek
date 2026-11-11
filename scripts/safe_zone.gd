extends Area3D
class_name SafeZone

signal player_entered(player: Character)
signal player_exited(player: Character)

@export var cloaking_duration: float = 5.0 as float
@export var auto_activate_for_hiders: bool = true as bool

var active_players: Dictionary = {}
var is_active: bool = false
var safe_zone_active_count: int = 0

func _ready():
	add_to_group("safe_zones")

func _physics_process(delta):
	for body in get_overlapping_bodies():
		var player = body.get_node_or_null("Character") as Character
		if not player or active_players.has(player): continue
		
		if is_player_in_zone(player):
			active_players[player] = Time.get_ticks_msec()
			player_entered.emit(player)
			
			if auto_activate_for_hiders and not is_active:
				is_active = true
				
		else:
			if active_players.has(player):
				var entry_time = active_players[player]
				var duration = Time.get_ticks_msec() - entry_time
				if duration > cloaking_duration * 1000:
					active_players.erase(player)
					player_exited.emit(player)

func is_player_in_zone(player: Character) -> bool:
	return player.global_position.distance_to(global_position) < 4.0


# Notify GameManager about safe zone status changes
func notify_game_manager(player: CharacterBody3D):
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

