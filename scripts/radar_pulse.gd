extends Node3D
class_name RadarPulse

signal pulse_active(player, distance)

@export var detection_radius: float = 25.0 as float
@export var cooldown_seconds: float = 3.0 as float

var is_cooldown: bool = false
var last_pulse_time: float = -cooldown_seconds

func _process(delta):
	if not is_cooldown and Input.is_action_pressed("radar"):
		last_pulse_time = Time.get_ticks_msec() / 1000.0
		is_cooldown = true
		
		for body in get_overlapping_bodies():
			var player = body.get_node_or_null("Character") as Character
			if not player: continue
			
			var distance = body.global_position.distance_to(global_position)
			
			if distance <= detection_radius and distance > 1.0:
				pulse_active.emit(player, distance)

func reset_cooldown() -> void:
	is_cooldown = false
	last_pulse_time = -cooldown_seconds