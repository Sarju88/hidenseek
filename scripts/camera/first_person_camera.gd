extends Camera3D
class_name FirstPersonCamera

@export var mouse_sensitivity: float = 0.0025
@export var look_deadzone: float = 0.1
var is_locked := true
var rotation_offset := Vector2.ZERO

func _input(event):
	if not is_locked:
		return
	
	match event.kind:
		InputEvent.MOUSE_MOTION:
			var dx := -event.relative.x * mouse_sensitivity
			var dy := event.relative.y * mouse_sensitivity
			
			if abs(dx) > look_deadzone or abs(dy) > look_deadzone:
				rotation_offset.x += dx
				rotation_offset.y += dy

func _process(_delta):
	# Clamp vertical rotation for comfort
	rotation_offset.y = clamp(rotation_offset.y, -1.5708, 1.5708)  # ±90 degrees
