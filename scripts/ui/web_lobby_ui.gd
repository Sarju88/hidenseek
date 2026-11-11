extends CanvasLayer
var panel: PanelContainer
var title: Label
var description: Label
var output: TextEdit
var reply: TextEdit
var connect_button: Button
var copy_button: Button
var status_label: Label
var is_open := false
var _lobby: Node
var _fresh: Button

func _ready() -> void:
 layer = 30
 if not OS.has_feature("web"): return
 _lobby = Network.web_lobby
 var overlay := Control.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(overlay)
 var backdrop := ColorRect.new()
 backdrop.color = Color(0.02, 0.04, 0.04, 0.92)
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(backdrop)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 32)
 overlay.add_child(margin)
 panel = PanelContainer.new()
 margin.add_child(panel)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("18343a")
 style.content_margin_left = 28
 style.content_margin_right = 28
 style.content_margin_top = 24
 style.content_margin_bottom = 24
 panel.add_theme_stylebox_override("panel", style)
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 panel.add_child(scroll)
 var column := VBoxContainer.new()
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation", 12)
 scroll.add_child(column)
 title = Label.new()
 title.add_theme_font_size_override("font_size", 32)
 column.add_child(title)
 description = Label.new()
 description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 column.add_child(description)
 output = TextEdit.new()
 output.name = "InviteCode"
 output.editable = false
 output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 output.custom_minimum_size.y = 94
 column.add_child(output)
 copy_button = Button.new()
 copy_button.text = "COPY CODE"
 copy_button.pressed.connect(func():
  DisplayServer.clipboard_set(output.text)
  output.select_all()
  status_label.text = "Code copied. If clipboard access is blocked, select and copy the code above.")
 column.add_child(copy_button)
 reply = TextEdit.new()
 reply.name = "ReplyCode"
 reply.placeholder_text = "Paste your friend's reply code here"
 reply.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 reply.custom_minimum_size.y = 85
 column.add_child(reply)
 connect_button = Button.new()
 connect_button.text = "CONNECT FRIEND"
 connect_button.pressed.connect(func(): _lobby.accept_reply(reply.text))
 column.add_child(connect_button)
 status_label = Label.new()
 status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 column.add_child(status_label)
 var actions := HBoxContainer.new()
 column.add_child(actions)
 var fresh := Button.new()
 _fresh = fresh
 fresh.text = "NEW INVITE"
 fresh.pressed.connect(func():
  if _lobby.hosting:
   reply.text = ""
   _lobby.create_invite()
   _refresh())
 actions.add_child(fresh)
 fresh.name = "NewInvite"
 var back := Button.new()
 back.text = "BACK TO GAME"
 back.pressed.connect(func():
  if not _lobby.hosting and Network.players.is_empty(): Network.leave_game()
  else: hide_panel())
 actions.add_child(back)
 _lobby.code_ready.connect(func(_code: String): _refresh())
 _lobby.status_changed.connect(func(message: String): status_label.text = message)
 _lobby.player_linked.connect(hide_panel)
 hide()

func show_panel() -> void:
 if not _lobby: return
 if _lobby.hosting and _lobby.status == "Connected!": _lobby.create_invite()
 is_open = true
 show()
 _refresh()
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_panel() -> void:
 is_open = false
 hide()
 if get_parent().has_method("_update_mouse_mode"): get_parent()._update_mouse_mode()

func _refresh() -> void:
 if not _lobby: return
 title.text = "HOST — INVITE A FRIEND" if _lobby.hosting else "JOIN — SEND YOUR REPLY"
 description.text = "1. Copy the invite and send it to one friend.\n2. They paste it into Join and send their reply back.\n3. Paste that reply below and select Connect Friend. Create a new invite for each additional player." if _lobby.hosting else "Copy this reply and send it back to the host. They paste it into their invite panel and select Connect Friend. Keep both browser tabs open."
 output.text = _lobby.code
 copy_button.disabled = _lobby.code.is_empty()
 reply.visible = _lobby.hosting
 connect_button.visible = _lobby.hosting
 _fresh.visible = _lobby.hosting
 status_label.text = _lobby.status
