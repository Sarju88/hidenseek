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
signal connection_status_changed(message: String)
var last_status := ""
var session_host_id := 0
var bind_address := "*"
var _connecting := false
var _connection_deadline := 0
var _last_address := ""
var _create_game := false

# Game mode settings (used by main menu and shooter scripts)
@export var shooter_mode: int = 0  # 0=team deathmatch, 1=free for all, 2=capture the flag
@export var practice_bots: int = 3  # Number of AI bots in practice mode


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			var value := argument.trim_prefix("--port=")
			if value.is_valid_int() and int(value) > 0 and int(value) <= 65535: server_port = int(value)
		elif argument.begins_with("--bind="):
			bind_address = argument.trim_prefix("--bind=")
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)


func start_host(nickname: String, skin_color_str: String, address: String = "") -> Error:
	if OS.has_feature("web"):
		# A browser cannot listen on a TCP port. Ask the addressed server to
		# start a game, using exactly the same address field as Join.
		return join_game(nickname, skin_color_str, address, true)
	var endpoint := parse_server_address(address)
	if endpoint.is_empty():
		_set_status("Enter a server address such as 127.0.0.1:8080.")
		return ERR_INVALID_PARAMETER
	if endpoint.scheme != "ws":
		_set_status("Local Host uses a plain server port. Use a secure proxy for a public server.")
		return ERR_INVALID_PARAMETER
	var peer := _new_peer()
	var error := peer.create_server(int(endpoint.port), bind_address)
	if error != OK:
		_set_status("Cannot host on port %s. Another server may already be using it." % endpoint.port)
		return error
	server_port = int(endpoint.port)
	multiplayer.multiplayer_peer = peer
	_session_active = true
	_connecting = false
	player_info["nick"] = sanitize_nickname(nickname, "Host")
	player_info["skin"] = skin_str_to_e(skin_color_str)
	session_host_id = 0 if DisplayServer.get_name() == "headless" else 1
	if session_host_id == 1:
		players[1] = player_info.duplicate()
		player_connected.emit(1, players[1])
	_set_status("Hosting on port %s. Other players can join this computer's address." % server_port)
	return OK


func join_game(nickname: String, skin_color_str: String, address: String = SERVER_ADDRESS, create_game: bool = false) -> Error:
	var endpoint := parse_server_address(address)
	if endpoint.is_empty():
		_set_status("Enter a server address such as 127.0.0.1:8080.")
		return ERR_INVALID_PARAMETER
	var peer := _new_peer()
	var error := peer.create_client(endpoint.url)
	if error != OK:
		_set_status("Could not open that server address.")
		return error
	player_info["nick"] = sanitize_nickname(nickname, "Player")
	player_info["skin"] = skin_str_to_e(skin_color_str)
	_create_game = create_game
	_last_address = endpoint.url
	multiplayer.multiplayer_peer = peer
	_session_active = true
	_connecting = true
	_connection_deadline = Time.get_ticks_msec() + 12000
	_set_status("Connecting to %s…" % address_for_display(endpoint.url))
	return OK


func _new_peer() -> WebSocketMultiplayerPeer:
	var peer := WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = 1048576
	peer.outbound_buffer_size = 1048576
	peer.max_queued_packets = 4096
	peer.handshake_timeout = 10.0
	return peer


func is_connecting() -> bool:
	return _connecting


func _set_status(message: String) -> void:
	last_status = message
	connection_status_changed.emit(message)


func address_for_display(address: String) -> String:
	return address.trim_prefix("ws://").trim_prefix("wss://").trim_suffix("/")


func parse_server_address(address: String) -> Dictionary:
	var clean := address.strip_edges()
	if clean.is_empty(): clean = SERVER_ADDRESS + ":" + str(server_port)
	if clean.length() > MAX_ADDRESS_LENGTH or clean.contains("@") or clean.contains("\\") or clean.contains("#") or clean.contains("?"): return {}
	for i in range(clean.length()):
		if clean.unicode_at(i) <= 32: return {}
	var scheme := ""
	if clean.begins_with("ws://"):
		scheme = "ws"
		clean = clean.trim_prefix("ws://")
	elif clean.begins_with("wss://"):
		scheme = "wss"
		clean = clean.trim_prefix("wss://")
	elif clean.contains("://"): return {}
	var path := ""
	var slash := clean.find("/")
	if slash >= 0:
		path = clean.substr(slash)
		clean = clean.substr(0, slash)
	var host := clean
	var port := server_port
	var explicit_port := false
	if clean.begins_with("["):
		var closing := clean.find("]")
		if closing < 0: return {}
		host = clean.substr(1, closing - 1)
		if not host.is_valid_ip_address(): return {}
		var rest := clean.substr(closing + 1)
		if not rest.is_empty():
			if not rest.begins_with(":") or not rest.substr(1).is_valid_int(): return {}
			port = int(rest.substr(1))
			explicit_port = true
	elif clean.contains(":"):
		if clean.count(":") != 1: return {}
		host = clean.get_slice(":", 0)
		var value := clean.get_slice(":", 1)
		if not value.is_valid_int(): return {}
		port = int(value)
		explicit_port = true
	if host.is_empty() or port < 1 or port > 65535: return {}
	if not host.contains(":"):
		for character in host:
			if not (character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789-."): return {}
	var loopback := host.to_lower() == "localhost" or (host.is_valid_ip_address() and host.begins_with("127.")) or host == "::1"
	var secure_page: bool = OS.has_feature("web") and bool(JavaScriptBridge.eval("location.protocol === 'https:'"))
	if scheme.is_empty():
		scheme = "wss" if secure_page and not loopback else "ws"
	elif secure_page and scheme == "ws" and not loopback:
		# The published HTTPS site needs a secure public game endpoint.
		return {}
	if not explicit_port and scheme == "wss": port = 443
	var authority := "[" + host + "]" if host.contains(":") else host
	if explicit_port or scheme == "ws": authority += ":" + str(port)
	return {"url": scheme + "://" + authority + path, "host": host, "port": port, "scheme": scheme}


func _on_connected_ok():
	_connecting = false
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info.duplicate()
	player_connected.emit(peer_id, player_info)
	_register_player.rpc_id(1, player_info, _create_game)


func _on_player_connected(id):
	if not multiplayer.is_server():
		return
	for peer_id in players:
		_sync_registered_player.rpc_id(id, peer_id, players[peer_id])


@rpc("any_peer", "reliable")
func _register_player(new_player_info, create_game: bool = false):
	if not multiplayer.is_server():
		return
	if not (new_player_info is Dictionary):
		return
	var new_player_id = multiplayer.get_remote_sender_id()
	if new_player_id == 0:
		return
	if players.has(new_player_id):
		return
	if players.size() >= MAX_PLAYERS:
		_reject_connection.rpc_id(new_player_id, "This server is full.")
		_drop_rejected_peer(new_player_id)
		return
	if create_game and session_host_id != 0:
		_reject_connection.rpc_id(new_player_id, "A game is already running at this address. Select Join instead.")
		_drop_rejected_peer(new_player_id)
		return
	if session_host_id == 0: session_host_id = new_player_id
	var sanitized_info = sanitize_player_info(new_player_info, "Player_" + str(new_player_id))
	players[new_player_id] = sanitized_info
	player_connected.emit(new_player_id, sanitized_info)
	_sync_registered_player.rpc(new_player_id, sanitized_info)
	_session_accepted.rpc_id(new_player_id, session_host_id)


func _on_player_disconnected(id):
	players.erase(id)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and session_host_id == id:
		session_host_id = int(players.keys()[0]) if not players.is_empty() else 0


func _on_connection_failed():
	_finish_session()
	_set_status("Could not connect to %s. Start Desktop Host or the game server at that address." % address_for_display(_last_address))


func _on_server_disconnected():
	_finish_session()
	_set_status("The server disconnected. You can join again from here.")


func leave_game() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer:
		peer.close()
	_finish_session()


func _finish_session() -> void:
	var had_session := _session_active or multiplayer.multiplayer_peer != null or not players.is_empty()
	_session_active = false
	_connecting = false
	_connection_deadline = 0
	session_host_id = 0
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
	if _connecting and Time.get_ticks_msec() > _connection_deadline:
		leave_game()
		_set_status("Could not connect to %s. Check that the game server is running." % address_for_display(_last_address))
		return
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


@rpc("authority", "reliable")
func _session_accepted(host_id: int) -> void:
	session_host_id = host_id
	_set_status("Connected to %s." % address_for_display(_last_address))


@rpc("authority", "reliable")
func _reject_connection(message: String) -> void:
	leave_game()
	_set_status(message)


func _drop_rejected_peer(peer_id: int) -> void:
	await get_tree().create_timer(0.3).timeout
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer is WebSocketMultiplayerPeer:
		var peer := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
		if multiplayer.get_peers().has(peer_id): peer.get_peer(peer_id).close(1000, "Session not accepted")
