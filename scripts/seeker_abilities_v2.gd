extends CharacterBody3D
class_name SeekerAbilities

signal thermal_vision_active()
signal enhanced_hearing_active(player, distance)

@export var radar_pulse_cooldown: float = 3.0 as float
@export var thermal_vision_duration: float = 5.0 as float

var is_seeker: bool = false
var last_radar_time: float = -radar_pulse_cooldown
var is_thermal_active: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0
var stun_reason: String = ""

func _ready():
	add_to_group("seeker_abilities")

func set_seeker_role(active: bool) -> void:
	is_seeker = active
	
	if active:
		enable_seeker_powers()
	else:
		disable_seeker_powers()

func enable_seeker_powers() -> void:
	add_to_group("seekers")
	
	# Connect to radar pulse detector if exists in parent scene
	var radar_node = get_parent().get_node_or_null("RadarPulse") as RadarPulse
	if radar_node and is_inside_tree():
		radar_node.pulse_active.connect(_on_radar_pulse)

func disable_seeker_powers() -> void:
	remove_from_group("seekers")

func _process(delta):
	if not is_seeker or is_stunned: return
	
	var now = Time.get_ticks_msec() / 1000.0
	
	# Radar Pulse (active ability) - auto-trigger when held
	if Input.is_action_pressed("radar"):
		if now - last_radar_time >= radar_pulse_cooldown:
			last_radar_time = now
			
			for body in get_overlapping_bodies():
				var player = body.get_node_or_null("Character") as Character
				if not player or player.is_multiplayer_authority() == false: continue
				
				var distance = body.global_position.distance_to(global_position)
				
				if distance <= 25.0 and distance > 1.0:
					enhanced_hearing_active.emit(player, distance)

	# Thermal Vision (passive when radar held)
	if Input.is_action_pressed("radar"):
		if not is_thermal_active:
			is_thermal_active = true
			thermal_vision_active.emit()
	else:
		if is_thermal_active:
			is_thermal_active = false

func activate_radar_pulse() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	
	if now - last_radar_time >= radar_pulse_cooldown:
		last_radar_time = now
		
		for body in get_overlapping_bodies():
			var player = body.get_node_or_null("Character") as Character
			if not player or player.is_multiplayer_authority() == false: continue
			
			var distance = body.global_position.distance_to(global_position)
			
			if distance <= 25.0 and distance > 1.0:
				enhanced_hearing_active.emit(player, distance)

func _on_radar_pulse(player, distance):
	"""Handle radar pulse detection from RadarPulse node."""
	if not is_seeker or player.is_multiplayer_authority() == false: return
	
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_radar_time >= radar_pulse_cooldown:
		last_radar_time = now
		enhanced_hearing_active.emit(player, distance)

func stun_player(duration: float, reason: String = "") -> void:
	is_stunned = true
	stun_timer = duration
	stun_reason = reason
	
	_request_animation(&"Idle", true)  # Reset to idle during stun
	
	print("[Seeker] Stunned for %.1fs - %s" % [duration, reason])

func is_seeker_stunned() -> bool:
	return is_stunned and stun_timer > 0

EOF