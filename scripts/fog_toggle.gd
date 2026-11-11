extends CharacterBody3D
class_name FogToggle

signal fog_toggled(is_fogged: bool)

@export var fog_intensity: float = 0.8 as float
@export var fog_color: Color = Color(0.1, 0.1, 0.2)

var is_fogged: bool = false

func _ready():
	add_to_group("fog_toggle")

func toggle_fog() -> void:
	is_fogged = not is_fogged
	fog_toggled.emit(is_fogged)
