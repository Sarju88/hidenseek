class_name PauseMenuUI extends Control

signal resume_pressed
signal main_menu_pressed
signal quit_pressed

const SAFE_AREA_MARGIN := 16.0
var pan := Vector2.ZERO

@onready var resume_button: Button = $Overlay/Panel/MarginContainer/Buttons/Resume
@onready var panel: PanelContainer = $Overlay/Panel

func _ready() -> void:
	if OS.has_feature("web"):
		$Overlay/Panel/MarginContainer/Buttons/Quit.hide()
	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")
	hide()

func show_menu() -> void:
	show()
	call_deferred("_update_responsive_layout")
	resume_button.grab_focus()

func hide_menu() -> void:
	hide()

func is_menu_visible() -> bool:
	return visible

func _update_responsive_layout() -> void:
	if not panel: return
	var available := Vector2(maxf(1.0, size.x - SAFE_AREA_MARGIN * 2), maxf(1.0, size.y - SAFE_AREA_MARGIN * 2))
	var needed := panel.get_combined_minimum_size()
	if needed.x <= 0 or needed.y <= 0: return
	var factor := minf(1.0, minf(available.x / needed.x, available.y / needed.y))
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * factor

func _on_resume_pressed() -> void:
	resume_pressed.emit()

func _on_main_menu_pressed() -> void:
	main_menu_pressed.emit()

func _on_quit_pressed() -> void:
	if OS.has_feature("web"):
		main_menu_pressed.emit()
		return
	quit_pressed.emit()
