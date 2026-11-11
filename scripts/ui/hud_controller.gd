class_name HUDController extends CanvasLayer

signal round_timer_updated(time_remaining: float)
signal game_state_changed(state: String)

@export_group("Timer Settings")
@export var default_round_time: float = 60.0 as float
@export var show_seconds := true as bool
@export var color_when_low: Color = Color.RED as Color

# Runtime state
var time_remaining: float = default_round_time as float
var is_seeker_active: bool = false as bool
var current_state: String = "WAITING" as String

@onready var _timer_label: Label = $UI/HUD/TimerLabel if has_node("UI") and has_node("HUD") else null
@onready var _state_label: Label = $UI/HUD/StateLabel if has_node("UI") and has_node("HUD") else null
@onready var _round_label: Label = $UI/HUD/RoundLabel if has_node("UI") and has_node("HUD") else null

func _ready():
	_setup_hud()
	_update_display()
	
	# Listen for GameManager signals (using prefixed names to avoid conflicts)
	HideSeekGameManager.gm_game_started_event.connect(_on_round_started)
	HideSeekGameManager.round_complete_event.connect(_on_round_ended)

func _setup_hud():
	if not has_node("UI"):
		var ui := PanelContainer.new()
		ui.name = "UI"
		add_child(ui)
		
		var hud := PanelContainer.new()
		hud.name = "HUD"
		hud.custom_minimum_size = Vector2(0, 50)
		ui.add_child(hud)

	if not has_node("UI/HUD/TimerLabel"):
		var timer_label := Label.new()
		timer_label.name = "TimerLabel"
		timer_label.text = "Time: %.1fs" % default_round_time
		timer_label.position = Vector2(10, 10)
		hud.add_child(timer_label)

	if not has_node("UI/HUD/StateLabel"):
		var state_label := Label.new()
		state_label.name = "StateLabel"
		state_label.text = "WAITING FOR PLAYERS..."
		state_label.position = Vector2(10, 45)
		hud.add_child(state_label)

	if not has_node("UI/HUD/RoundLabel"):
		var round_label := Label.new()
		round_label.name = "RoundLabel"
		round_label.text = "Round 0 / 5"
		round_label.position = Vector2(10, 70)
		hud.add_child(round_label)

func _update_display():
	if not has_node("UI") or not has_node("UI/HUD"):
		return
	
	var ui := get_node_or_null("UI") as PanelContainer
	if not ui:
		return
	
	var timer_label := ui.get_node_or_null("TimerLabel") as Label
	var state_label := ui.get_node_or_null("StateLabel") as Label
	var round_label := ui.get_node_or_null("RoundLabel") as Label
	
	if timer_label:
		timer_label.text = "Time: %.1fs" % time_remaining
		
		# Change color when time is running low (< 10 seconds)
		if time_remaining < 10.0 and time_remaining > 0:
			timer_label.modulate = color_when_low
		else:
			timer_label.modulate = Color.WHITE

	if state_label:
		state_label.text = _get_state_text()

func update_time(new_time: float) -> void:
	time_remaining = max(0.0, new_time)
	_update_display()

func set_seeker_active(active: bool) -> void:
	is_seeker_active = active
	
	if not has_node("UI") or not has_node("UI/HUD"):
		return
	
	var ui := get_node_or_null("UI") as PanelContainer
	if not ui:
		return
	
	var state_label := ui.get_node_or_null("StateLabel") as Label
	if state_label:
		state_label.text = _get_state_text()

func set_round(round_number: int) -> void:
	if round_label:
		round_label.text = "Round %d / 5" % round_number

func set_game_state(state: String) -> void:
	current_state = state
	_update_display()

func _get_state_text() -> String:
	match current_state:
		"WAITING": return "WAITING FOR PLAYERS..."
		"HIDERS_HIDING": return "HIDERS - FIND A PLACE TO HIDE!"
		"SEEKER_SEARCHING": return "SEEKER - FIND ALL HIDERS!"
		"ROUND_ENDING": return "ROUND ENDING..."
		_: return current_state

# Network integration functions
func on_round_started(round_number: int) -> void:
	time_remaining = default_round_time
	current_state = "HIDERS_HIDING"
	set_round(round_number)
	_update_display()

func on_seeker_phase_started() -> void:
	is_seeker_active = true
	current_state = "SEEKER_SEARCHING"
	if _state_label:
		_state_label.text = "SEEKER - FIND ALL HIDERS!"

func on_round_ended(seeker_won: bool, time_left: float) -> void:
	time_remaining = time_left
	current_state = "ROUND_ENDING"
	
	if _timer_label:
		_timer_label.modulate = Color.YELLOW
	
	print("[HUD] Round ended! Seeker won: %s" % ["Yes" if seeker_won else "No"])

func on_game_paused() -> void:
	current_state = "PAUSED"
	if _state_label:
		_state_label.text = "GAME PAUSED - Press R to resume"

func on_game_resumed() -> void:
	current_state = "WAITING"
	if _state_label:
		_state_label.text = "WAITING FOR PLAYERS..."

# GameManager signal handlers
func _on_round_started(round_number: int):
	time_remaining = default_round_time
	current_state = "HIDERS_HIDING"
	set_round(round_number)
	_update_display()

func _on_round_ended(seeker_won: bool, time_left: float):
	time_remaining = time_left
	current_state = "ROUND_ENDING"
	
	if _timer_label:
		_timer_label.modulate = Color.YELLOW
	
	print("[HUD] Round ended! Seeker won: %s" % ["Yes" if seeker_won else "No"])

func _on_game_paused():
	current_state = "PAUSED"
	if _state_label:
		_state_label.text = "GAME PAUSED - Press R to resume"

func _on_game_resumed():
	current_state = "WAITING"
	if _state_label:
		_state_label.text = "WAITING FOR PLAYERS..."

# Utility functions for debugging and inspection
func get_current_time() -> float:
	return time_remaining

func is_seeker_active_ui() -> bool:
	return is_seeker_active
