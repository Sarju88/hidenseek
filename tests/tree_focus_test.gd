extends Node
var failures := 0
func check(ok: bool, message: String):
 if not ok:
  failures += 1
  push_error(message)
func _ready(): call_deferred("run")
func run():
 var level=load("res://scenes/level/level.tscn").instantiate()
 get_tree().root.add_child(level);get_tree().current_scene=level
 Network.leave_game();multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
 Network.players={1:{"nick":"Test","skin":0}}
 var actor=load("res://scenes/level/player.tscn").instantiate()
 actor.name="1";level.get_node("PlayersContainer").add_child(actor);actor.set_physics_process(false)
 var system=level.get_node("HidingSystem")
 system.phase=system.SEEKING;system.roles={1:1};system._publish()
 level.main_menu.hide_menu()
 var camera=Camera3D.new();level.add_child(camera);camera.make_current()
 await get_tree().physics_frame
 for spot in system.spots().values():
  if spot.kind!="tree":continue
  actor.global_position=spot.global_position+Vector3(0,0,2.5);actor.global_position.y=0.05
  camera.global_position=actor.global_position+Vector3(0.45,2.0,5)
  await get_tree().physics_frame
  for height in [1.25,2.8]:
   system.caught.clear()
   system.phase = system.SEEKING
   system.roles = {1:1}
   actor.global_position=spot.global_position+Vector3(0,0,2.5)
   actor.global_position.y=0.05
   camera.global_position=actor.global_position+Vector3(0.45,2.0,5)
   camera.look_at(spot.global_position+Vector3.UP*height)
   system._update_focus(actor)
   check(system._can_interact(actor,spot), "Tree must be reachable from player")
   check(system._focus == spot, "Camera wall behind player must not block " + spot.spot_id)
   if system._focus == spot:
    var event := InputEventKey.new()
    event.physical_keycode = KEY_E
    event.pressed = true
    system._unhandled_input(event)
    check(actor.hidden_spot_id == spot.spot_id, "E hides in the focused tree")
    system.interact(1, "")
    system.cooldowns.clear()
    camera.make_current()
 # A wall between the player and the tree must still prevent hiding.
 var tree: OfficeHidingSpot
 for spot in system.spots().values():
  if spot.kind == "tree":
   tree = spot
   break
 actor.global_position = tree.global_position + Vector3(0,0,2.5)
 actor.global_position.y = 0.05
 camera.global_position = actor.global_position + Vector3(0.45,2,5)
 camera.look_at(tree.prompt_point())
 var wall := StaticBody3D.new()
 wall.collision_layer = 2
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(4,4,0.2)
 shape.shape = box
 wall.add_child(shape)
 level.add_child(wall)
 wall.global_position = (actor.global_position + tree.global_position) / 2 + Vector3.UP
 await get_tree().physics_frame
 check(not system._can_interact(actor,tree), "Wall in front of player blocks hiding")
 system._update_focus(actor)
 check(system._focus == null, "Blocked tree has no prompt")
 print("TREE_FOCUS failures=",failures)
 get_tree().quit(1 if failures else 0)
