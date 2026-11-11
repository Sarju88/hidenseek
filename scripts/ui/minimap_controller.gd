class_name MinimapController extends CanvasLayer

signal minimap_updated()

@export_group("Minimap Settings")
@export var show_seeker: bool = true as bool
@export var show_teammates: bool = false as bool
@export var seeker_color := Color.RED as Color
@export var teammate_color := Color.BLUE as Color
@export var minimap_size: float = 128.0 as float

# Runtime state
var player_positions: Dictionary = {} # peer_id -> Vector3
var is_hider_role: bool = false as bool

@onready var _minimap_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(minimap_size, minimap_size)) if has_node("MinimapRect") else null
@onready var _seeker_dot: Control = $Minimap/SeekerDot if has_node("Minimap") and has_node("SeekerDot") else null
@onready var _teammate_dots: Array[Control] = [] as Array[Control]

func _ready():
	_setup_minimap()
	
	# Connect to server's position broadcast RPC (server-side only)
	if multiplayer.is_server():
		Network._broadcast_positions.connect(_on_position_broadcast)
	
	# Listen for seeker detection events
	multiplayer.seeker_found_hider.connect(_on_seeker_found_hider)

func _setup_minimap():
	if not has_node("Minimap"):
		var minimap := PanelContainer.new()
		minimap.name = "Minimap"
		minimap.custom_minimum_size = Vector2(minimap_size, minimap_size)
		add_child(minimap)
		
		if not has_node("Minimap/SeekerDot"):
			var seeker_dot := ColorRect.new()
			seeker_dot.name = "SeekerDot"
			seeker_dot.color = seeker_color
			seeker_dot.size = Vector2(6, 6)
			minimap.add_child(seeker_dot)

func _on_player_joined(peer_id: int, player_info: Dictionary):
	is_hider_role = (peer_id != 1) # Host is always seeker
	
	# Initialize teammate dots container if needed
	if not has_node("Minimap"):
		return

	var minimap := get_node_or_null("Minimap") as PanelContainer
	if not minimap or _teammate_dots.is_empty():
		_setup_teammate_dots(minimap)

func _on_player_left(peer_id: int):
	player_positions.erase(peer_id)
	minimap_updated.emit()

func update_all_positions(positions: Dictionary) -> void:
	player_positions = positions
	
	if not is_hider_role or not has_node("Minimap"):
		return
	
	var minimap := get_node_or_null("Minimap") as PanelContainer
	if not minimap or _teammate_dots.is_empty():
		return

	for peer_id in player_positions.keys():
		_update_player_dot(peer_id, positions.get(peer_id))

func _on_position_broadcast(positions: Dictionary):
	# Server-side only position update handler for all clients
	if multiplayer.is_server() and not is_hider_role:
		update_all_positions(positions)

func _update_player_dot(peer_id: int, pos: Vector3):
	var minimap := get_node_or_null("Minimap") as PanelContainer
	if not minimap or _minimap_rect == null:
		return
	
	# Calculate screen position relative to minimap rect
	var world_pos := global_position + _minimap_rect.size * 0.5 # Center of minimap
	var local_pos := (pos - world_pos) / _minimap_size
	
	# Clamp to minimap bounds
	local_pos.x = clamp(local_pos.x, -1.0, 1.0)
	local_pos.y = clamp(local_pos.y, -1.0, 1.0)
	
	var dot_position := Vector2(local_pos * minimap_size + _minimap_rect.size / 2)
	
	if peer_id == 1 and show_seeker: # Host is the seeker
		if _seeker_dot:
			_seeker_dot.position = dot_position
	elif peer_id > 1 and show_teammates: # Other hiders are teammates
		var existing := _teammate_dots.find(func(d): return d.peer_id == peer_id)
		if existing >= 0:
			_teammate_dots[existing].position = dot_position
		else:
			var teammate_dot := ColorRect.new()
			teammate_dot.name = "TeammateDot_%d" % peer_id
			teammate_dot.color = teammate_color
			teammate_dot.size = Vector2(4, 4)
			minimap.add_child(teammate_dot)
			_teammate_dots.append(teammate_dot)
			teammate_dot.position = dot_position

func update_seeker_position(seeker_pos: Vector3) -> void:
	if not is_hider_role or not has_node("Minimap") or _seeker_dot == null:
		return
	
	var minimap := get_node_or_null("Minimap") as PanelContainer
	if not minimap or _minimap_rect == null:
		return

	var world_pos := global_position + _minimap_rect.size * 0.5 # Center of minimap
	var local_pos := (seeker_pos - world_pos) / _minimap_size
	
	local_pos.x = clamp(local_pos.x, -1.0, 1.0)
	local_pos.y = clamp(local_pos.y, -1.0, 1.0)
	
	_seeker_dot.position = Vector2(local_pos * minimap_size + _minimap_rect.size / 2)

func _setup_teammate_dots(minimap: PanelContainer):
	for i in range(5): # Max 5 teammates expected
		var teammate_dot := ColorRect.new()
		teammate_dot.name = "TeammateDot_%d" % (1 + i)
		teammate_dot.color = teammate_color
		teammate_dot.size = Vector2(4, 4)
		minimap.add_child(teammate_dot)
		_teammate_dots.append(teammate_dot)

func _on_seeker_found_hider(hider_player: CharacterBody3D):
	if not is_hider_role or not has_node("Minimap"):
		return
	
	var minimap := get_node_or_null("Minimap") as PanelContainer
	if not minimap:
		return
	
	# Visual feedback when seeker finds a hider - flash red
	for dot in _teammate_dots:
		dot.modulate = Color.RED
		await get_tree().create_timer(0.5).timeout
		dot.modulate = teammate_color

func is_hider() -> bool:
	return is_hider_role
