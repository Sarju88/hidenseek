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
  "host": _level._on_host_pressed("Host", "blue", value)
  "join": _level._on_join_pressed("Guest", "green", value)
  "start": _level.get_node("HidingSystem")._start_clicked()
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
 Network._process(0.0)
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
  "players": Network.players.keys(), "status": Network.last_status,
  "connecting": Network.is_connecting(), "main_menu": _level.main_menu.visible,
  "paused": _level.pause_menu.visible, "session_host": Network.session_host_id,
  "quit_visible": _level.pause_menu.get_node("Overlay/Panel/MarginContainer/Buttons/Quit").visible,
  "main_quit_visible": _level.main_menu.get_node("MainContainer/MainMenu/Option4").visible,
  "phase": system.phase, "remaining": system.seconds_left(), "locked": system.is_movement_locked(multiplayer.get_unique_id()), "blind": system.is_blind(multiplayer.get_unique_id()), "roles": system.roles, "bodies": bodies, "positions": positions, "hidden": hidden, "found": system.found_counts}
 JavaScriptBridge.get_interface("window").hnsState = JSON.stringify(state)
