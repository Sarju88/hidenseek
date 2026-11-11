extends Node
var failures := 0
var level: Node3D
var system: Node
var actors: Array[Character] = []

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func _ready() -> void:
 call_deferred("run")

func near(spot: OfficeHidingSpot, actor: Character) -> bool:
 for offset in [Vector3(0, 0, spot.dimensions.z / 2 + 0.65), Vector3(spot.dimensions.x / 2 + 0.65, 0, 0), Vector3(-spot.dimensions.x / 2 - 0.65, 0, 0), Vector3(0, 0, -spot.dimensions.z / 2 - 0.65)]:
  actor.global_position = spot.global_position + spot.global_basis * offset
  actor.global_position.y = 0.05
  if system._can_interact(actor, spot): return true
 return false

func run() -> void:
 Network.server_port = 18080
 level = load("res://scenes/level/level.tscn").instantiate()
 get_tree().root.add_child(level)
 get_tree().current_scene = level
 Network.leave_game()
 multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 Network.players = {1: {"nick": "Hider", "skin": 0}, 2: {"nick": "Other", "skin": 0}, 3: {"nick": "Seeker", "skin": 0}}
 system = level.get_node("HidingSystem")
 for id in range(1, 4):
  var actor: Character = load("res://scenes/level/player.tscn").instantiate()
  actor.name = str(id)
  level.get_node("PlayersContainer").add_child(actor)
  # All actors are local in this physics/role test. Network ownership is tested separately.
  actor.set_multiplayer_authority(1)
  actor.set_physics_process(false)
  actor.global_position = Vector3(0, 0.05, 17)
  actors.append(actor)
 await get_tree().physics_frame
 await get_tree().physics_frame
 system.roles = {1: 1, 2: 1, 3: 0}
 system._publish()
 var types := {}
 for spot in system.spots().values():
  if not types.has(spot.kind): types[spot.kind] = spot
 check(types.size() == 5, "All five types must exist in the playable map")
 for kind in types:
  var spot: OfficeHidingSpot = types[kind]
  system.cooldowns.clear()
  check(near(spot, actors[0]), kind + " must be reachable")
  var entry := actors[0].global_position
  check(system.interact(1, spot.spot_id), kind + " accepts a hider")
  check(actors[0].hidden_spot_id == spot.spot_id, kind + " applies hidden state")
  check(actors[0].collision_layer == 0 and not actors[0]._body.visible and not actors[0].nickname.visible, "Hidden body and nickname must be concealed")
  near(spot, actors[1])
  check(not system.interact(2, spot.spot_id), "A second hider cannot occupy " + kind)
  check(system.interact(1, ""), "Hider can leave " + kind)
  check(actors[0].hidden_spot_id.is_empty() and actors[0].collision_layer == 1, "Leaving restores player collision")
  check(actors[0].global_position.distance_to(entry) < 2, "Exit returns near entry")
  system.cooldowns.clear()
  near(spot, actors[0])
  check(system.interact(1, spot.spot_id), "Can re-enter " + kind)
  near(spot, actors[2])
  var before: int = system.found_counts.get(3, 0)
  check(system.interact(3, spot.spot_id), "Seeker can check " + kind)
  check(actors[2].hiding_busy and actors[2].hidden_spot_id.is_empty(), "Checking freezes seeker without hiding them")
  check(not system.interact(3, spot.spot_id), "Checking cannot be spammed")
  await get_tree().create_timer(1.3).timeout
  check(actors[0].hidden_spot_id.is_empty(), "Checking reveals hider in " + kind)
  check(system.found_counts.get(3, 0) == before + 1, "Successful check scores once")
  check(actors[0].global_position.distance_to(level.get_spawn_point(1)) < 0.2, "Found hider returns to lobby")
  check(not actors[2].hiding_busy, "Check animation releases seeker")
 # Empty spots take the same time and never award a catch.
 var empty: OfficeHidingSpot = types.closet
 system.cooldowns.clear()
 near(empty, actors[2])
 var before: int = system.found_counts.get(3, 0)
 check(system.interact(3, empty.spot_id), "Seeker checks empty spot")
 await get_tree().create_timer(1.3).timeout
 check(system.found_counts.get(3, 0) == before, "Empty checks do not score")
 check(not actors[2].hiding_busy, "Empty check completes")
 # Server rejects invalid, distant, and occluded requests.
 check(not system.interact(3, "made_up"), "Invalid spot rejected")
 actors[0].global_position = Vector3(0, 0.05, 17)
 system.cooldowns.clear()
 check(not system.interact(1, types.tree.spot_id), "Distant interaction rejected")
 var wall := StaticBody3D.new()
 wall.collision_layer = 2
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(4, 4, 0.2)
 shape.shape = box
 wall.add_child(shape)
 level.add_child(wall)
 near(empty, actors[0])
 wall.global_position = (actors[0].global_position + empty.prompt_point()) / 2 + Vector3.UP * 0.5
 await get_tree().physics_frame
 check(not system.interact(1, empty.spot_id), "Wall blocks interaction")
 wall.queue_free()
 await get_tree().physics_frame
 # Disconnecting an occupant frees the reservation.
 system.cooldowns.clear()
 near(empty, actors[0])
 system.interact(1, empty.spot_id)
 system._peer_left(1)
 check(not system.hidden.has(1), "Disconnect frees hiding spot")
 print("[Hiding test] failures=", failures)
 get_tree().quit(1 if failures else 0)
