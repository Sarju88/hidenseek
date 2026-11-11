extends Node
var failed := false
func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  push_error(message)
func _ready() -> void:
 var codec = load("res://scripts/network/web_lobby.gd")
 var offer := {"v": 1, "kind": "offer", "peer": 1234, "nonce": "0123456789abcdef0123456789abcdef", "sdp": "v=0\r\na=test\r\n", "ice": [{"m": "0", "i": 0, "c": "candidate:test"}]}
 var encoded: String = codec.encode_code(offer)
 check(codec.decode_code(encoded, "offer").get("peer") == 1234, "Invite round trip preserves assigned peer")
 check(codec.decode_code(" \n" + encoded + "\n", "offer").get("nonce") == offer.nonce, "Pasted whitespace is accepted")
 check(codec.decode_code(encoded, "answer").is_empty(), "Invite cannot be used as a reply")
 check(codec.decode_code("not-an-invite", "offer").is_empty(), "Malformed invite rejected")
 check(codec.decode_code("HNS1." + "A".repeat(33000), "offer").is_empty(), "Oversized invite rejected")
 var invalid := offer.duplicate(true)
 invalid.peer = 1
 check(codec.decode_code(codec.encode_code(invalid), "offer").is_empty(), "Host's reserved peer ID cannot be claimed")
 invalid = offer.duplicate(true)
 invalid.ice = [{"m": "0", "i": -1, "c": "candidate:test"}]
 check(codec.decode_code(codec.encode_code(invalid), "offer").is_empty(), "Invalid ICE candidate rejected")
 var pause: Control = load("res://scenes/ui/pause_menu_ui.tscn").instantiate()
 add_child(pause)
 var events := []
 pause.resume_pressed.connect(func(): events.append("resume"))
 pause.main_menu_pressed.connect(func(): events.append("menu"))
 pause.show_menu()
 pause._on_resume_pressed()
 check(events == ["resume"], "Resume sends the signal consumed by the level")
 pause.hide_menu()
 check(not pause.visible, "Resume can hide the actual pause menu")
 pause._on_main_menu_pressed()
 check(events == ["resume", "menu"], "Main Menu sends the leave-session signal")
 print("[Web protocol/menu test] failed=", failed)
 get_tree().quit(1 if failed else 0)
