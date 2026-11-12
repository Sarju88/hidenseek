extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _ready() -> void:
 call_deferred("run")
func run() -> void:
 Network.server_port = 18082
 var level = load("res://scenes/level/level.tscn").instantiate()
 get_tree().root.add_child(level)
 get_tree().current_scene = level
 Network.leave_game()
 multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 Network.players = {1: {"nick":"Host","skin":0}, 2: {"nick":"Guest","skin":0}, 3: {"nick":"Third","skin":0}}
 Network.session_host_id = 1
 var system = level.get_node("HidingSystem")
 for id in Network.players:
  var actor = load("res://scenes/level/player.tscn").instantiate()
  actor.name = str(id)
  level.get_node("PlayersContainer").add_child(actor)
  actor.set_multiplayer_authority(1)
 system._refresh_members()
 for id in Network.players:
  var actor = system.player(id)
  var anchor: Vector3 = actor.global_position
  actor.global_position += Vector3(10, 0, 10)
  actor.velocity = Vector3.ONE * 10
  actor._physics_process(0.1)
  check(actor.global_position == anchor and actor.velocity == Vector3.ZERO, "Lobby movement is locked")
 var local_actor = system.player(1)
 var view = local_actor.get_node("SpringArmOffset/SpringArm3D/Camera3D")
 var normal_mask = view.cull_mask
 local_actor.apply_round_lock(true, local_actor.global_position, true)
 check(view.cull_mask == 0 and view.environment.background_color == Color.BLACK, "Blackout hides world even without HUD")
 local_actor.apply_round_lock(true, local_actor.global_position, false)
 check(view.cull_mask == normal_mask, "Blackout restores normal camera")
 check(not system.start_round(2), "Guest cannot start round")
 check(not system.can_interact(1), "Lobby interactions disabled")
 check(system.hiding_seconds == 60.0, "Default countdown is 60 seconds")
 system.hiding_seconds = 0.3
 check(system.start_round(1), "Host can start")
 var seekers := 0
 var seeker := 0
 for id in system.roles:
  if system.role(id) == system.SEEKER:
   seekers += 1
   seeker = id
   check(system.is_blind(id) and system.player(id).round_locked, "Seeker blind and frozen")
  else:
   check(not system.player(id).round_locked and system.can_interact(id), "Hiders may move and hide")
 check(seekers == 1, "Exactly one random seeker")
 check(not system.can_interact(seeker), "Seeker cannot check during hiding")
 Network.players[4] = {"nick":"Late","skin":0}
 system._refresh_members()
 check(system.is_movement_locked(4) and not system.can_interact(4), "Late join waits for next round")
 while Time.get_ticks_msec() < system._hide_deadline + 100:
  await get_tree().create_timer(0.05).timeout
 check(system.phase == system.SEEKING, "Server ends countdown")
 check(not system.is_blind(seeker) and not system.player(seeker).round_locked, "Seeker released after countdown")
 Network.players.erase(seeker)
 system._refresh_members()
 check(system.phase == system.LOBBY, "Seeker disconnect ends round")
 for id in Network.players: check(system.is_movement_locked(id), "Everyone frozen between rounds")
 print("[Round test] failures=", failures)
 get_tree().quit(1 if failures else 0)
