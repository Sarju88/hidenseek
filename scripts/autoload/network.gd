extends Node

signal player_connected(peer_id, player_info)
signal server_disconnected

const SERVER_ADDRESS: String = "127.0.0.1"
const SERVER_PORT: int = 8080
# Tests and dedicated deployments can select an isolated port before connecting.
var server_port: int = SERVER_PORT
const MAX_PLAYERS: int = 10
const MAX_NICK_LENGTH := 24
const MAX_ADDRESS_LENGTH := 253

var players = {}
var player_info = {"nick": "host", "skin": Character.SkinColor.BLUE}
var _session_active := false
var web_lobby: Node
const WebLobby = preload("res://scripts/network/web_lobby.gd")

# Game mode settings (used by main menu and shooter scripts)
@export var shooter_mode: int = 0  # 0=team deathmatch, 1=free for all, 2=capture the flag
@export var practice_bots: int = 3  # Number of AI bots in practice mode


func _ready() -> void:
	if OS.has_feature("web"):
		web_lobby = WebLobby.new()
		add_child(web_lobby)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)


func start_host(nickname: String, skin_color_str: String):
	if OS.has_feature("web"):
		var error: Error = web_lobby.host()
		if error != OK: return error
	else:
		var peer = ENetMultiplayerPeer.new()
		var error = peer.create_server(server_port, MAX_PLAYERS)
		if error:
			return error
		peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
		multiplayer.multiplayer_peer = peer
	_session_active = true

	player_info["nick"] = sanitize_nickname(nickname, "Host_" + str(multiplayer.get_unique_id()))
	player_info["skin"] = skin_str_to_e(skin_color_str)

	if DisplayServer.get_name() == "headless":
		return

	players[1] = player_info
	player_connected.emit(1, player_info)


func join_game(nickname: String, skin_color_str: String, address: String = SERVER_ADDRESS):
	if OS.has_feature("web"):
		player_info["nick"] = sanitize_nickname(nickname, "Player")
		player_info["skin"] = skin_str_to_e(skin_color_str)
		var error: Error = web_lobby.join_invite(address)
		_session_active = error == OK
		return error
	address = sanitize_address(address)
	if address.is_empty():
		return ERR_INVALID_PARAMETER

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, server_port)
	if error:
		return error

	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	_session_active = true

	player_info["nick"] = sanitize_nickname(nickname, "Player_" + str(multiplayer.get_unique_id()))
	player_info["skin"] = skin_str_to_e(skin_color_str)


func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)
	_register_player.rpc_id(1, player_info)


func _on_player_connected(id):
	if not multiplayer.is_server():
		return
	for peer_id in players:
		_sync_registered_player.rpc_id(id, peer_id, players[peer_id])


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	if not multiplayer.is_server():
		return
	if not (new_player_info is Dictionary):
		return
	var new_player_id = multiplayer.get_remote_sender_id()
	if new_player_id == 0:
		return
	if players.has(new_player_id):
		return
	var sanitized_info = sanitize_player_info(new_player_info, "Player_" + str(new_player_id))
	players[new_player_id] = sanitized_info
	player_connected.emit(new_player_id, sanitized_info)
	_sync_registered_player.rpc(new_player_id, sanitized_info)


func _on_player_disconnected(id):
	players.erase(id)


func _on_connection_failed():
	_finish_session()


func _on_server_disconnected():
	_finish_session()


func leave_game() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer:
		peer.close()
	_finish_session()


func _finish_session() -> void:
	if web_lobby: web_lobby.close()
	var had_session := _session_active or multiplayer.multiplayer_peer != null or not players.is_empty()
	_session_active = false
	multiplayer.multiplayer_peer = null
	players.clear()
	if had_session:
		server_disconnected.emit()


func skin_str_to_e(s):
	match str(s).strip_edges().to_lower():
		"blue":
			return Character.SkinColor.BLUE
		"yellow":
			return Character.SkinColor.YELLOW
		"green":
			return Character.SkinColor.GREEN
		"red":
			return Character.SkinColor.RED
		_:
			return Character.SkinColor.BLUE


@rpc("authority", "reliable")
func _sync_registered_player(peer_id: int, registered_player_info: Dictionary):
	if multiplayer.is_server():
		return
	if players.has(peer_id):
		return
	var sanitized_info = sanitize_player_info(registered_player_info, "Player_" + str(peer_id))
	players[peer_id] = sanitized_info
	player_connected.emit(peer_id, sanitized_info)


# Broadcast minimap updates at a fixed rate independent of rendering.
const MINIMAP_UPDATE_INTERVAL := 0.1
var _minimap_update_elapsed := 0.0


func _process(delta: float) -> void:
	if not _session_active or not multiplayer.is_server() or players.is_empty():
		_minimap_update_elapsed = 0.0
		return
	_minimap_update_elapsed += delta
	if _minimap_update_elapsed >= MINIMAP_UPDATE_INTERVAL:
		_minimap_update_elapsed = 0.0
		broadcast_player_positions()


func broadcast_player_positions() -> void:
	var positions := {}
	var container := get_tree().get_first_node_in_group("Players")
	if container:
		for child in container.get_children():
			if child is Character:
				positions[child.get_multiplayer_authority()] = child.global_position

	_broadcast_positions(positions)
	for peer_id in multiplayer.get_peers():
		if players.has(peer_id):
			_broadcast_positions.rpc_id(peer_id, positions)


@rpc("authority", "unreliable")
func _broadcast_positions(positions: Dictionary) -> void:

	# Update minimap controller if available (hiders only)
	var minimap := get_tree().get_first_node_in_group("MinimapController") as PanelContainer
	if minimap:
		minimap.update_all_positions(positions)


@rpc("any_peer", "reliable")
func on_seeker_detected_hider(hider_player: CharacterBody3D):
	"""RPC called when seeker detects a hider."""
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and multiplayer.is_server() and gm.has_method("mark_as_found"):
		gm.mark_as_found(hider_player)
		print("[Network] Hider found at %.2f, %.2f" % [hider_player.global_position.x, hider_player.global_position.z])


# Find player by peer_id for use in RPCs
func _find_player_by_peer_id(peer_id: int) -> CharacterBody3D:
	for player in get_tree().get_root().get_children():
		if player is CharacterBody3D and player.has_node_or_null("peer_id") != null and player.get_node_or_null("peer_id").get_int() == peer_id:
			return player
	return null


func sanitize_player_info(info: Dictionary, fallback_nick: String) -> Dictionary:
	return {
		"nick": sanitize_nickname(str(info.get("nick", "")), fallback_nick),
		"skin": sanitize_skin_value(info.get("skin", Character.SkinColor.BLUE))
	}


func sanitize_nickname(nickname: String, fallback: String) -> String:
	var clean := ""
	var last_was_space := false
	for i in range(nickname.length()):
		var codepoint := nickname.unicode_at(i)
		if codepoint <= 31 or codepoint == 127:
			if not last_was_space:
				clean += " "
				last_was_space = true
			continue

		var character := nickname.substr(i, 1)
		if character == " ":
			if last_was_space:
				continue
			last_was_space = true
		else:
			last_was_space = false
		clean += character

	clean = clean.strip_edges()
	if clean.is_empty():
		clean = fallback.strip_edges()
	if clean.length() > MAX_NICK_LENGTH:
		clean = clean.substr(0, MAX_NICK_LENGTH).strip_edges()
	if clean.is_empty():
		clean = "Player"
	return clean


func sanitize_address(address: String) -> String:
	var clean = address.strip_edges()
	if clean.is_empty():
		return SERVER_ADDRESS
	if clean.length() > MAX_ADDRESS_LENGTH:
		return ""
	if clean.contains("://") or clean.contains("/") or clean.contains("\\") or clean.contains(":"):
		return ""
	return clean


func sanitize_skin_value(value) -> Character.SkinColor:
	if value is int:
		match value:
			Character.SkinColor.BLUE, Character.SkinColor.YELLOW, Character.SkinColor.GREEN, Character.SkinColor.RED:
				return value
			_:
				return Character.SkinColor.BLUE
	return skin_str_to_e(str(value))
