extends Node3D
class_name SoundDetector

signal sound_detected(player: Character, distance: float)

@export var detection_radius: float = 15.0 as float
@export var audio_volume_scale: float = 1.0 as float

var last_sound_time: float = 0.0

func _ready():
	add_to_group("sound_detectors")

func _process(delta):
	var now = Time.get_ticks_msec() / 1000.0
	
	# Only check every half second to avoid spamming signals
	if now - last_sound_time < 0.5: return
	
	last_sound_time = now
	
	for body in get_overlapping_bodies():
		var player = body.get_node_or_null("Character") as Character
		if not player or player.is_multiplayer_authority() == false: continue
		
		var distance = body.global_position.distance_to(global_position)
		
		if distance <= detection_radius and distance > 1.0:
			var volume = (1.0 - distance / detection_radius) * audio_volume_scale
			sound_detected.emit(player, distance)
