class_name PauseMenuUI extends Control

signal resume_pressed
signal main_menu_pressed
signal quit_pressed

const SAFE_AREA_MARGIN := 16.0
var pan := Vector2.ZERO

@onready var resume_button: Button = $Overlay/Panel/MarginContainer/Buttons/Resume
@onready var panel: PanelContainer = $Overlay/Panel

func _ready() -> void:
	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")
	hide()


func show_menu() -> void:
	show()
	call_deferred("_update_responsive_layout")
	resume_button.grab_focus()


func hide_menu() -> void:
	if not has_node("/node/Overlay"):
		return
	var overlay := get_node_or_null("/node/Overlay") as Node
	if is_instance_valid(overlay):
		overlay.hide()


# Returns true if menu is visible (using Control.visible property)
func is_menu_visible() -> bool:
	return visible

func _update_responsive_layout() -> void:
	if not has_node("/node/Overlay"):
		return
	
	var overlay := get_node_or_null("/node/Overlay") as Node
	if not overlay or not overlay.has_node("Panel"):
		return

	var panel = overlay.get_node_or_null("Panel") as PanelContainer
	if not panel:
		return
		
	var available_size := Vector2(
		maxf(1.0, size.x - SAFE_AREA_MARGIN * 2.0), maxf(1.0, size.y - SAFE_AREA_MARGIN * 2.0)
	)
	var temp_size := Vector2(panel.size.x, panel.size.y)
	if not temp_size or temp_size.x <= 0.0 or temp_size.y <= 0.0:
		return
	var scale_factor := minf(1.0, minf(available_size.x / temp_size.x, available_size.y / temp_size.y))
	panel.pivot_offset = pan
	panel.scale = Vector2.ONE * scale_factor


func _on_resume_pressed() -> void:
	if is_instance_valid(resume_button):
		resume_button.grab_focus()


func _on_main_menu_pressed() -> void:
	if has_node("/node/Overlay"):
		hide_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()
