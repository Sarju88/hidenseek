extends Node
## Browser-only fixture. Included only by build_web.py --browser-test.
var _callback: JavaScriptObject
var _level: Node3D

func _ready() -> void:
 call_deferred("_start")

func _start() -> void:
 _level = load("res://scenes/level/level.tscn").instantiate()
 get_tree().root.add_child(_level)
 get_tree().current_scene = _level
 _callback = JavaScriptBridge.create_callback(_command)
 JavaScriptBridge.get_interface("window").hnsCommand = _callback
 _snapshot()

func _command(args: Array) -> void:
 var command := str(args[0])
 var value := str(args[1]) if args.size() > 1 else ""
 match command:
  "host": _level._on_host_pressed("Host", "blue")
  "join": _level._on_join_pressed("Guest", "green", value)
  "accept": Network.web_lobby.accept_reply(value)
  "invite": Network.web_lobby.create_invite()
  "pause": _level._show_pause_menu()
  "resume": _level.pause_menu._on_resume_pressed()
  "menu": _level.pause_menu._on_main_menu_pressed()
  "approach", "hide", "check":
   var id := multiplayer.get_unique_id()
   var actor: Character = _level.get_node_or_null("PlayersContainer/" + str(id))
   if actor:
    if command == "approach":
     actor.global_position = Vector3(-5, 0.05, 17)
     actor.set_physics_process(false)
     _snapshot()
     return
    var system := _level.get_node("HidingSystem")
    for spot in system.spots().values():
     if spot.kind == "closet" and spot.position.x == -5:
      if multiplayer.is_server(): system.interact(id, spot.spot_id)
      else: system.request_interaction.rpc_id(1, spot.spot_id)
  "quit_guard": _level._on_pause_quit_pressed()
 _snapshot()

func _snapshot() -> void:
 # Inactive embedded browser panes throttle RAF. Poll the actual Godot network
 # and check timers explicitly so two background peers can be tested together.
 if multiplayer.has_multiplayer_peer(): multiplayer.poll()
 Network.web_lobby._process(0.0)
 var hiding := _level.get_node("HidingSystem")
 if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and hiding.roles.size() != Network.players.size(): hiding._refresh_members()
 hiding._process(0.0)
 var bodies := {}
 var positions := {}
 var hidden := {}
 for actor in _level.get_node("PlayersContainer").get_children():
  bodies[str(actor.name)] = actor._body.visible
  positions[str(actor.name)] = [actor.global_position.x, actor.global_position.y, actor.global_position.z]
  hidden[str(actor.name)] = actor.hidden_spot_id
 var system := _level.get_node("HidingSystem")
 var state := {"peer": multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0,
  "players": Network.players.keys(), "code": Network.web_lobby.code,
  "status": Network.web_lobby.status, "lobby_open": _level.get_node("WebLobbyUI").is_open,
  "main_menu": _level.main_menu.visible, "paused": _level.pause_menu.visible,
  "quit_visible": _level.pause_menu.get_node("Overlay/Panel/MarginContainer/Buttons/Quit").visible,
  "main_quit_visible": _level.main_menu.get_node("MainContainer/MainMenu/Option4").visible,
  "roles": system.roles, "bodies": bodies, "positions": positions, "hidden": hidden, "found": system.found_counts,
  "connection": Network.web_lobby._connection.get_connection_state() if Network.web_lobby._connection else -1,
  "gathering": Network.web_lobby._connection.get_gathering_state() if Network.web_lobby._connection else -1,
  "process_frames": Engine.get_process_frames(), "paused_tree": get_tree().paused, "tick": Time.get_ticks_msec(), "gather_started": Network.web_lobby._gather_started, "candidate_count": Network.web_lobby._candidates.size(), "description_length": Network.web_lobby._description.length()}
 JavaScriptBridge.get_interface("window").hnsState = JSON.stringify(state)
