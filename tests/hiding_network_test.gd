extends Node
var failed := false
var system: Node
var level: Node3D
var is_server := false
var reports := {}

func check(ok: bool, message: String) -> void:
 if not ok:
  push_error(message)
  failed = true

func _ready() -> void:
 call_deferred("run")

func wait_for(condition: Callable, timeout: float = 6.0) -> bool:
 var until := Time.get_ticks_msec() + int(timeout * 1000)
 while not condition.call() and Time.get_ticks_msec() < until:
  await get_tree().create_timer(0.05).timeout
 return condition.call()

func run() -> void:
 Network.server_port = 18081
 is_server = "--net-server" in OS.get_cmdline_user_args()
 level = load("res://scenes/level/level.tscn").instantiate()
 get_tree().root.add_child(level)
 get_tree().current_scene = level
 system = level.get_node("HidingSystem")
 if not is_server:
  level.get_node("GameAudio").enabled = true
  await get_tree().create_timer(14).timeout
  print("[Hiding net client] timeout")
  get_tree().quit(1)
  return
 check(await wait_for(func(): return Network.players.size() == 2 and system.roles.size() == 2), "Two real clients must connect")
 if failed:
  get_tree().quit(1)
  return
 var hider := 0
 var seeker := 0
 for id in system.roles:
  if system.role(id) == 0: seeker = int(id)
  else: hider = int(id)
 check(hider != 0 and seeker != 0, "Server assigns distinct roles")
 var spot: OfficeHidingSpot
 for candidate in system.spots().values():
  if candidate.kind == "closet" and candidate.position.x == -5: spot = candidate
 prepare.rpc_id(hider, Vector3(-5, 0.05, 17.2))
 prepare.rpc_id(seeker, Vector3(-4, 0.05, 17.2))
 check(await wait_for(func(): return system.player(hider).global_position.distance_to(Vector3(-5, 0.05, 17.2)) < 0.2), "Client movement reaches server")
 attempt.rpc_id(hider, spot.spot_id)
 check(await wait_for(func(): return system.hidden.has(hider)), "Remote hider request enters spot on server")
 check(spot.occupant == hider, "Server reserves spot for its owner")
 inspect.rpc("hidden", hider, spot.spot_id)
 check(await wait_for(func(): return reports.size() == 2), "Both clients confirm concealed player and occupancy")
 reports.clear()
 # Requesting a fresh snapshot must preserve existing occupancy and roles.
 resync.rpc()
 await get_tree().create_timer(0.3).timeout
 inspect.rpc("hidden", hider, spot.spot_id)
 check(await wait_for(func(): return reports.size() == 2), "Snapshots restore hidden state on both clients")
 reports.clear()
 attempt.rpc_id(seeker, spot.spot_id)
 check(await wait_for(func(): return not system.checks.is_empty()), "Remote seeker starts authoritative check")
 check(await wait_for(func(): return not system.hidden.has(hider)), "Remote check finds and releases hider")
 check(system.found_counts.get(seeker, 0) == 1, "Server awards one catch")
 inspect.rpc("released", hider, spot.spot_id)
 check(await wait_for(func(): return reports.size() == 2), "Both clients restore body visibility and collision")
 await get_tree().create_timer(0.2).timeout
 check(system.player(hider).global_position.distance_to(level.get_spawn_point(hider)) < 0.3, "Owner accepts server lobby relocation")
 finish.rpc(not failed)
 print("[Hiding net server] failed=", failed)
 await get_tree().create_timer(0.05).timeout
 get_tree().quit(1 if failed else 0)

@rpc("authority", "reliable")
func prepare(pos: Vector3) -> void:
 var actor: Character = system.player(multiplayer.get_unique_id())
 actor.global_position = pos
 actor.set_physics_process(false)

@rpc("authority", "reliable")
func attempt(spot_id: String) -> void:
 system.request_interaction.rpc_id(1, spot_id)

@rpc("authority", "reliable")
func resync() -> void:
 system.request_snapshot.rpc_id(1)

@rpc("authority", "reliable")
func inspect(stage: String, peer: int, spot_id: String) -> void:
 await get_tree().create_timer(0.1).timeout
 var actor: Character = system.player(peer)
 var spot: OfficeHidingSpot = system.spots().get(spot_id)
 var ok := actor != null and spot != null
 if ok and stage == "hidden": ok = actor.hidden_spot_id == spot_id and actor.collision_layer == 0 and not actor._body.visible and spot.occupant == peer
 if ok and stage == "released": ok = actor.hidden_spot_id.is_empty() and actor.collision_layer == 1 and spot.occupant == 0
 var audio: Node3D = level.get_node("GameAudio")
 if stage == "hidden": ok = ok and audio._spatial_index > 0
 if stage == "released": ok = ok and audio._ui_index > 0
 report.rpc_id(1, ok)

@rpc("any_peer", "reliable")
func report(ok: bool) -> void:
 if not multiplayer.is_server(): return
 reports[multiplayer.get_remote_sender_id()] = ok
 check(ok, "Remote client state agrees with server")

@rpc("authority", "reliable")
func finish(ok: bool) -> void:
 print("[Hiding net client] synchronized=", ok)
 level.get_node("GameAudio")._reset()
 await get_tree().create_timer(0.15).timeout
 get_tree().quit(0 if ok else 1)
