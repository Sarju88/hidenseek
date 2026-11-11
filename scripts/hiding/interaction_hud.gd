extends Control
## Reference-inspired hand, cream E keycap, and a depth-tested object outline.
var target_screen := Vector2.ZERO
var action_text := ""
var role_text := ""
var message := ""
var hidden_kind := ""
var prompt_visible := false
var check_progress := -1.0
var message_until := 0
var hand := preload("res://assets/ui/interact_hand.svg")
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func notify(text: String) -> void:
 message = text
 message_until = Time.get_ticks_msec() + 2600

func _process(_delta: float) -> void:
 queue_redraw()

func _text(text: String, at: Vector2, font_size: int, color: Color = Color.WHITE) -> void:
 draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color("202421"))
 draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center_text(text: String, y: float, font_size: int, color: Color = Color.WHITE) -> void:
 _text(text, Vector2((size.x - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) / 2, y), font_size, color)

func _draw() -> void:
 var cream := Color("fff4d9")
 if hidden_kind in ["closet", "cabinet", "box"]:
  # A limited slit view lets the hider peek without seeing through solid walls.
  var slit := 0.33 if hidden_kind != "box" else 0.2
  var h := size.y * (1.0 - slit) / 2
  draw_rect(Rect2(0, 0, size.x, h), Color("111915"))
  draw_rect(Rect2(0, size.y - h, size.x, h), Color("111915"))
 elif hidden_kind == "tree":
  draw_circle(Vector2(-70, size.y * 0.55), size.y * 0.38, Color(0.08, 0.2, 0.11, 0.65))
  draw_circle(Vector2(size.x + 65, size.y * 0.38), size.y * 0.4, Color(0.08, 0.2, 0.11, 0.65))
 if hidden_kind.is_empty() and check_progress < 0:
  draw_circle(size / 2, 2.0, cream)
 if not role_text.is_empty():
  draw_style_box(_panel(), Rect2(20, 20, 480, 66))
  _text(role_text, Vector2(36, 47), 20, cream)
  _text("E  interact / exit    ·    R  switch role in solo play", Vector2(36, 71), 14)
 if prompt_visible:
  var p := target_screen
  draw_texture_rect(hand, Rect2(p - Vector2(24, 28), Vector2(48, 48)), false)
  var key := StyleBoxFlat.new()
  key.bg_color = cream
  key.corner_radius_top_left = 4
  key.corner_radius_top_right = 4
  key.corner_radius_bottom_left = 4
  key.corner_radius_bottom_right = 4
  draw_style_box(key, Rect2(p + Vector2(-14, 24), Vector2(28, 30)))
  draw_string(font, p + Vector2(-7, 47), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("342d24"))
  var width := font.get_string_size(action_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
  _text(action_text, p + Vector2(-width / 2, 79), 18, cream)
 if not hidden_kind.is_empty():
  _center_text("HIDDEN  ·  Move the mouse to peek  ·  E to exit", size.y - 48, 21, cream)
 if check_progress >= 0:
  var center := size / 2
  draw_arc(center, 32, -PI / 2, -PI / 2 + TAU * clampf(check_progress, 0.001, 1), 40, cream, 3, true)
  _center_text("Checking…", center.y + 64, 20, cream)
 if Time.get_ticks_msec() < message_until:
  _center_text(message, size.y * 0.76, 24, cream)

func _panel() -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.03, 0.07, 0.06, 0.8)
 style.corner_radius_top_left = 6
 style.corner_radius_top_right = 6
 style.corner_radius_bottom_left = 6
 style.corner_radius_bottom_right = 6
 return style
