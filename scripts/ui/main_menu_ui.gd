class_name MainMenuUI
extends Control

signal host_pressed(nickname: String, skin: String, address: String)
signal cancel_requested
signal join_pressed(nickname: String, skin: String, address: String)
signal quit_pressed

const SKIN_OPTIONS: Array[String] = ["Blue", "Yellow", "Green", "Red"]
const SAFE_AREA_MARGIN := 24.0

@onready var skin_input: OptionButton = $MainContainer/MainMenu/Option2/SkinInput
@onready var nick_input: LineEdit = $MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $MainContainer/MainMenu/Option3/AddressInput
@onready var main_container: VBoxContainer = $MainContainer


func _ready() -> void:
	$MainContainer/MainMenu/Option3/Label.text = "Room code / server : "
	address_input.placeholder_text = "friends"
	address_input.max_length = 253
	address_input.custom_minimum_size.x = 250
	if OS.has_feature("web"):
		$MainContainer/MainMenu/Option4.hide()
	var help := Label.new()
	help.name = "ConnectionStatus"
	help.text = "Enter a room code. Host creates it; friends enter the same code and Join. The host must keep this tab open."
	help.add_theme_font_size_override("font_size", 18)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.custom_minimum_size.x = 620
	$MainContainer.add_child(help)
	var cancel := Button.new()
	cancel.name = "CancelConnection"
	cancel.text = "CANCEL"
	cancel.hide()
	cancel.pressed.connect(func(): cancel_requested.emit())
	$MainContainer/MainMenu/Buttons.add_child(cancel)
	skin_input.clear()
	for skin_name in SKIN_OPTIONS:
		skin_input.add_item(skin_name)
	skin_input.select(0)
	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")


func _on_host_pressed() -> void:
	var nickname = nick_input.text.strip_edges()
	var skin = get_skin()
	host_pressed.emit(nickname, skin, address_input.text.strip_edges())


func _on_join_pressed() -> void:
	var nickname = nick_input.text.strip_edges()
	var skin = get_skin()
	var address = address_input.text.strip_edges()
	join_pressed.emit(nickname, skin, address)


func _on_quit_pressed():
	quit_pressed.emit()


func show_menu():
	show()
	call_deferred("_update_responsive_layout")


func hide_menu():
	hide()


func is_menu_visible() -> bool:
	return visible


func _update_responsive_layout() -> void:
	if not main_container:
		return
	var available_size := Vector2(
		maxf(1.0, size.x - SAFE_AREA_MARGIN * 2.0), maxf(1.0, size.y - SAFE_AREA_MARGIN * 2.0)
	)
	var content_size := main_container.get_combined_minimum_size()
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		return
	var scale_factor := minf(1.0, minf(available_size.x / content_size.x, available_size.y / content_size.y))
	main_container.pivot_offset = main_container.size * 0.5
	main_container.scale = Vector2.ONE * scale_factor


func get_skin() -> String:
	return skin_input.get_item_text(skin_input.selected).to_lower()


func set_connection_status(message: String) -> void:
	var label := get_node_or_null("MainContainer/ConnectionStatus") as Label
	if label: label.text = message


func set_connecting(active: bool) -> void:
	$MainContainer/MainMenu/Buttons/Host.disabled = active
	$MainContainer/MainMenu/Buttons/Join.disabled = active
	$MainContainer/MainMenu/Buttons/CancelConnection.visible = active
	address_input.editable = not active
