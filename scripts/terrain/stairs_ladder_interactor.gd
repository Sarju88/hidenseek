class_name StairsLadderInteractor extends Area3D

signal climb_started()
signal climb_ended()

@export_group("Visuals")
@export var stairs_model: PackedScene = preload("res://assets/models/stairs.tscn") as PackedScene
@export var ladder_model: PackedScene = preload("res://assets/models/ladder.tscn") as PackedScene

# Runtime state
var is_climbable := true
var climb_speed_multiplier := 2.0
var current_height_offset := 0.0

func _ready():
	_setup_visuals()
	
	# Connect to player for interaction detection
	var player_controller := get_tree().get_first_node_in_group("players") as PlayerController
	if player_controller:
		player_controller.climb_ladder.connect(_on_player_wants_climb)

func _setup_visuals():
	"""Load and position the Kenney stairs/ladder model."""
	var model_scene := stairs_model or ladder_model
	
	if not model_scene:
		push_warning("StairsLadderInteractor: No model scene assigned")
		return
	
	var model_instance := model_scene.instantiate() as Node3D
	model_instance.position = Vector3(0, 1.5, 0) # Offset from center
	add_child(model_instance)

func _on_player_wants_climb(player: PlayerController):
	"""Handle player attempting to climb."""
	if not is_inside_area(player.get_collider()):
		return
	
	climb_started.emit()
	
	# Apply climbing effect
	player.velocity.y += 0.5 * climb_speed_multiplier
	current_height_offset += 1.0

func _physics_process(delta: float) -> void:
	"""Handle continuous climbing while in contact."""
	if not is_climbable or current_height_offset <= 0:
		return
	
	var player := get_collider() as PlayerController
	if not player:
		climb_ended.emit()
		current_height_offset = 0
		return
	
	# Apply upward velocity for climbing
	player.velocity.y += 0.3 * climb_speed_multiplier
	
	# Limit height offset to prevent infinite climbing
	if current_height_offset > 10.0:
		current_height_offset = 10.0

func can_climb() -> bool:
	"""Check if this stairs/ladder is currently climbable."""
	return is_inside_area(get_collider()) and is_climbable

# Utility for debugging
func debug_draw_bounds():
	var wireframe := WireFrame.new()
	wireframe.line_color = Color.RED
	add_child(wireframe)
