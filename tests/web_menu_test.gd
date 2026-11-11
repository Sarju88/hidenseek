extends Node
var failed := false
func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  push_error(message)
func _ready() -> void:
 var endpoint := Network.parse_server_address("127.0.0.1:8080")
 check(endpoint.get("url") == "ws://127.0.0.1:8080", "IP:port works without a protocol prefix")
 check(Network.parse_server_address("localhost:9001").get("port") == 9001, "Custom port is respected")
 check(Network.parse_server_address("127.0.0.1").get("port") == Network.server_port, "Host without a port uses default")
 check(Network.parse_server_address("wss://game.example.com/play").get("url") == "wss://game.example.com/play", "Secure public server with proxy path is supported")
 check(Network.parse_server_address("[::1]:8080").get("url") == "ws://[::1]:8080", "IPv6 loopback is supported")
 for bad in ["http://localhost:8080", "127.0.0.1:0", "127.0.0.1:65536", "localhost:nope", "ws://user:password@host", "bad host:8080", "host:8080#fragment"]:
  check(Network.parse_server_address(bad).is_empty(), "Invalid server address rejected: " + bad)
 var pause: Control = load("res://scenes/ui/pause_menu_ui.tscn").instantiate()
 add_child(pause)
 var events := []
 pause.resume_pressed.connect(func(): events.append("resume"))
 pause.main_menu_pressed.connect(func(): events.append("menu"))
 pause.show_menu()
 pause._on_resume_pressed()
 check(events == ["resume"], "Resume signals the level")
 pause.hide_menu()
 check(not pause.visible, "Pause menu actually hides")
 pause._on_main_menu_pressed()
 check(events == ["resume", "menu"], "Main Menu signals the level")
 print("[Address/menu test] failed=", failed)
 get_tree().quit(1 if failed else 0)
