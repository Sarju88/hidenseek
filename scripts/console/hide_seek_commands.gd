class_name HideSeekCommands extends Node

func _ready():
	Input.add_event_filter(_on_input_event)

func _on_input_event(p_event: InputEvent, p_callable):
	if not p_event is InputEventKey or not p_event.pressed:
		return
	
	var key := p_event.keycode
	var event_type := p_event.event_type
	
	if event_type != InputEvent.KEYPressed:
		return
	
	match key:
		Key.R:
			# Restart current round
			if has_node("GameManager"):
				get_node("GameManager").start_new_round()
		
		Key.T:
			# Toggle test mode (for debugging)
			print("[HideSeek] Test mode toggled")

func _get_command_info():
	return """
Hide & Seek Console Commands:
  R - Restart current round
  T - Toggle debug/test mode
  
For AI testing, use the SimpleAIBot controller or run test_hide_seek.gd scene.
"""
