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
		var invite := Button.new()
		invite.text = "INVITE PLAYER"
		invite.add_theme_font_size_override("font_size", 28)
		invite.pressed.connect(func():
			if Network.web_lobby and Network.web_lobby.hosting:
				hide_menu()
				var lobby := get_tree().current_scene.get_node_or_null("WebLobbyUI")
				if lobby:
					if Network.web_lobby.code.is_empty(): Network.web_lobby.create_invite()
					lobby.show_panel())
		$Overlay/Panel/MarginContainer/Buttons.add_child(invite)
	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")
	hide()

func show_menu() -> void:
	show()
	var invite := $Overlay/Panel/MarginContainer/Buttons.get_child(-1) as Button
	if OS.has_feature("web") and invite: invite.visible = Network.web_lobby != null and Network.web_lobby.hosting
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
