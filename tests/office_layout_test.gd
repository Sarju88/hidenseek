extends Node3D
## Run: godot --headless --path . res://tests/office_layout_test.tscn
var failures := 0

func check(condition: bool, message: String) -> void:
 if not condition:
  failures += 1
  push_error(message)

func _ready() -> void:
 call_deferred("run")

func run() -> void:
 var office: Node3D = load("res://scenes/level/shooter_arena.tscn").instantiate()
 add_child(office)
 await get_tree().physics_frame
 await get_tree().physics_frame
 var nav: NavigationRegion3D = office.navigation
 var map := nav.get_navigation_map()
 # NavigationServer publishes the freshly baked region asynchronously.
 for i in range(40):
  if NavigationServer3D.map_get_closest_point_owner(map, office.get_lobby_spawn(1)).is_valid(): break
  await get_tree().create_timer(0.1).timeout
 check(nav.navigation_mesh.get_polygon_count() > 0, "Office navigation must contain walkable surfaces")
 var origin: Vector3 = office.get_lobby_spawn(1)
 for target in [Vector3(0, 0, -6), Vector3(-8, 0, -18), Vector3(8, 0, -18), Vector3(-12, 0, 2), Vector3(12, 0, 2), Vector3(-12, 0, -14), Vector3(12, 0, -14)]:
  var start := NavigationServer3D.map_get_closest_point(map, origin)
  var end := NavigationServer3D.map_get_closest_point(map, target)
  var path := NavigationServer3D.map_get_path(map, start, end, true)
  check(not path.is_empty() and path[-1].distance_to(end) < 0.2, "Lobby must connect to " + str(target))
 # Every playable entrance must remain clear at standing head height.
 for x in [-10, 10, -6, 6]:
  var z := 2.0 if abs(x) == 10 else -6.0
  check(clear(Vector3(x - 0.7, 1.5, z), Vector3(x + 0.7, 1.5, z)), "Doorway blocked at " + str(Vector2(x, z)))
 check(clear(Vector3(0, 1.5, 1), Vector3(0, 1.5, 3)), "Lobby courtyard doorway must be open")
 # Courtyard has open sky; lobby has a roof; both have solid ground.
 check(clear(Vector3(0, 1.5, -6), Vector3(0, 15, -6)), "Courtyard must be open to the sky")
 check(not clear(Vector3(0, 1.5, 17), Vector3(0, 8, 17)), "Lobby must have a ceiling")
 for i in range(1, 11):
  var spawn: Vector3 = office.get_lobby_spawn(i)
  check(not clear(spawn + Vector3.UP, spawn + Vector3.DOWN), "Every lobby spawn needs ground")
 check(not clear(Vector3(1, 1.5, 19), Vector3(1, 1.5, 22)), "Exterior walls must contain players")
 for side in [-1, 1]:
  for c in [-14, -6, 2, 10, 18]:
   check(not clear(Vector3(c, 1.5, side * 19), Vector3(c, 1.5, side * 22)), "Exterior window must contain players")
   check(not clear(Vector3(side * 19, 1.5, c), Vector3(side * 22, 1.5, c)), "Exterior side window must contain players")
 print("[Office test] failures=", failures)
 get_tree().quit(1 if failures else 0)

func clear(from: Vector3, to: Vector3) -> bool:
 var query := PhysicsRayQueryParameters3D.create(from, to, 2)
 return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
