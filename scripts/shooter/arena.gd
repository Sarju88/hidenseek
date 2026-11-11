extends Node3D
## Deterministic office layout shared by graphical clients and dedicated servers.
## Model collisions are baked with the same transforms as the visible Kenney pieces.
const BUILDING := "res://assets/building_kit/"
const FURNITURE := "res://assets/furniture/"
const EXISTING := "res://assets/models/GLB format/"
const WALL_HEIGHT := 4.8
const LOBBY_SPAWNS := [Vector3(0, 0.15, 17), Vector3(-2, 0.15, 17), Vector3(2, 0.15, 17), Vector3(-4, 0.15, 17), Vector3(4, 0.15, 17), Vector3(-2, 0.15, 15), Vector3(2, 0.15, 15), Vector3(-4, 0.15, 15), Vector3(4, 0.15, 15), Vector3(0, 0.15, 15)]
const HidingSpot = preload("res://scripts/hiding/hiding_spot.gd")
var _spot_count := 0
var navigation: NavigationRegion3D
var _models: Dictionary = {}
var _bounds: Dictionary = {}
var asset_usage: Dictionary = {}

func _ready() -> void:
 add_to_group("office_building")
 navigation = NavigationRegion3D.new()
 navigation.name = "Navigation"
 navigation.navigation_mesh = NavigationMesh.new()
 navigation.navigation_mesh.agent_radius = 0.5
 navigation.navigation_mesh.agent_height = 2.0
 navigation.navigation_mesh.agent_max_climb = 0.25
 navigation.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
 add_child(navigation)
 _structure()
 _lobby()
 _offices()
 _courtyard()
 _lighting()
 _extra_hiding_furniture()
 call_deferred("_bake_navigation")
 print("[Office] Built lobby, four office suites and courtyard using ", asset_usage.size(), " Kenney model types.")

func get_lobby_spawn(peer_id: int) -> Vector3:
 return LOBBY_SPAWNS[posmod(peer_id - 1, LOBBY_SPAWNS.size())]

func _bake_navigation() -> void:
 navigation.bake_navigation_mesh(false)

func _structure() -> void:
 # Four-metre modules: tiled floors and a full ceiling except over the courtyard.
 for x in range(-18, 20, 4):
  for z in range(-18, 20, 4):
   var outside: bool = abs(x) <= 6 and z >= -14 and z <= 2
   if not outside:
    var tint := Color("d9d4c5") if z >= 6 else Color("91a4a0")
    if abs(x) >= 10 and z < 6: tint = Color("647d86") if x < 0 else Color("c8b69a")
    piece(BUILDING + "floor.glb", Vector3(x, -0.2, z), Vector3(4, 0.2, 4), 0, true, tint)
    piece(BUILDING + "floor.glb", Vector3(x, WALL_HEIGHT, z), Vector3(4, 0.12, 4), 0, true, Color("ece9df"))
 # Half-width modules align the tiled grid with the courtyard's six-metre edges.
 for x in [-7, 7]:
  piece(BUILDING + "floor.glb", Vector3(x, -0.2, -6), Vector3(2, 0.2, 20), 0, true, Color("91a4a0"))
  piece(BUILDING + "floor.glb", Vector3(x, WALL_HEIGHT, -6), Vector3(2, 0.12, 20), 0, true, Color("ece9df"))
 piece(BUILDING + "floor.glb", Vector3(0, -0.2, 3), Vector3(12, 0.2, 2), 0, true, Color("91a4a0"))
 piece(BUILDING + "floor.glb", Vector3(0, WALL_HEIGHT, 3), Vector3(12, 0.12, 2), 0, true, Color("ece9df"))
 # Exterior: solid structural bays alternate with the existing wide-window models.
 for axis in [-1, 1]:
  for c in range(-18, 20, 4):
   wall(Vector3(axis * 20, 0, c), 0, "wall-window-wide-square-detailed" if c % 8 == 2 else "wall")
   wall(Vector3(c, 0, axis * 20), PI / 2, "wall-window-wide-square-detailed" if c % 8 == 2 else "wall")
 # Interior office wings. Doors are mesh openings, never invisible collision boxes.
 for side in [-1, 1]:
  for z in range(-18, 6, 4):
   wall(Vector3(side * 10, 0, z), 0, "wall-doorway-wide-square" if z in [-14, 2] else "wall-window-wide-square")
  for x in [12, 16, 18]:
   var length := 4.0 if x != 18 else 0.0
   if length > 0:
    wall(Vector3(side * x, 0, -6), PI / 2, "wall-doorway-wide-square" if x == 12 else "wall")
    wall(Vector3(side * x, 0, 6), PI / 2, "wall-doorway-wide-square" if x == 12 else "wall")
  # Last two metres close each cross-wall without overlapping a doorway.
  piece(BUILDING + "wall.glb", Vector3(side * 19, 0, -6), Vector3(0.2, WALL_HEIGHT, 2), PI / 2, true, Color("e4e1d5"))
  piece(BUILDING + "wall.glb", Vector3(side * 19, 0, 6), Vector3(0.2, WALL_HEIGHT, 2), PI / 2, true, Color("e4e1d5"))
 # Courtyard glazing and access on all four sides make a complete circulation loop.
 for side in [-1, 1]:
  for z in [-14, -10, -6, -2]:
   wall(Vector3(side * 6, 0, z), 0, "wall-doorway-wide-square" if z == -6 else "wall-window-wide-square")
 for z in [-16, 2]:
  for x in [-4, 0, 4]:
   wall(Vector3(x, 0, z), PI / 2, "wall-doorway-wide-square" if x == 0 else "wall-window-wide-square")
 for x in [-8, 8]:
  for z in [6, 18]:
   piece(BUILDING + "column-wide.glb", Vector3(x, 0, z), Vector3(0.7, WALL_HEIGHT, 0.7), 0, true)
   piece(BUILDING + "plating-detailed-wide.glb", Vector3(x, 0.02, z), Vector3(1, 0.06, 1), 0, false)
 # Teal wayfinding carpet runs from spawn to the garden doors.
 solid(Vector3(0, 0.012, 13), Vector3(3.4, 0.025, 14), Color("305a61"), false)
 for x in [-8, 8]:
  solid(Vector3(x, 0.012, -7), Vector3(1.5, 0.025, 26), Color("305a61"), false)

func _lobby() -> void:
 # Reception counter and a clear arrival aisle on each side.
 prop("kitchenBar", Vector3(-1.1, 0, 10.6), 1.15, PI)
 prop("kitchenBar", Vector3(0, 0, 10.6), 1.15, PI)
 prop("kitchenBarEnd", Vector3(1.1, 0, 10.6), 1.15, PI)
 prop("computerScreen", Vector3(0, 1.15, 10.5), 0.42, PI, false)
 prop("computerKeyboard", Vector3(0, 1.15, 10.9), 0.035, PI, false)
 prop("chairDesk", Vector3(0, 0, 9), 1.1)
 prop("coatRackStanding", Vector3(5.5, 0, 18), 1.9)
 prop("rugDoormat", Vector3(0, 0.03, 18.8), 0.025, 0, false)
 for side in [-1, 1]:
  prop("loungeSofaLong", Vector3(side * 12, 0, 16.7), 1.05, PI if side < 0 else 0)
  prop("loungeChair", Vector3(side * 16, 0, 14.5), 1.05, -side * PI / 2)
  prop("tableCoffeeGlass", Vector3(side * 12, 0, 14), 0.48)
  prop("books", Vector3(side * 12, 0.5, 14), 0.14, 0, false)
  prop("rugRounded", Vector3(side * 12, 0.025, 15), 0.018, 0, false)
  prop("lampRoundFloor", Vector3(side * 17.7, 0, 17.5), 1.85)
  prop("pottedPlant", Vector3(side * 5, 0, 10), 1.8)
  prop("trashcan", Vector3(side * 7, 0, 18.2), 0.75)
  prop("sideTableDrawers", Vector3(side * 17.5, 0, 11), 0.85)
  prop("plantSmall1", Vector3(side * 17.5, 0.85, 11), 0.4, 0, false)
 office_sign("NORTHLINE  /  OFFICES", Vector3(0, 3.5, 10), 0, 66)
 office_sign("RECEPTION", Vector3(0, 1.7, 11), 0, 30)
 office_sign("01  WORKSPACE     /     COURTYARD     /     02  MEETING", Vector3(0, 3.2, 4), 0, 28)
 office_sign("WELCOME", Vector3(0, 3.3, 19.75), PI, 48)

func _workstation(pos: Vector3, angle: float = 0.0) -> void:
 prop("desk", pos, 0.83, angle)
 var facing := Basis(Vector3.UP, angle)
 prop("computerScreen", pos + facing * Vector3(0, 0.83, -0.12), 0.45, angle, false)
 prop("computerKeyboard", pos + facing * Vector3(0, 0.84, 0.17), 0.035, angle, false)
 prop("computerMouse", pos + facing * Vector3(0.6, 0.84, 0.17), 0.04, angle, false)
 prop("chairDesk", pos + facing * Vector3(0, 0, 1), 1.12, angle)

func _offices() -> void:
 # West south: a furnished workspace with staggered desk rows and shelving cover.
 for x in [-17.5, -13]:
  for z in [-2.8, 2.3]:
   _workstation(Vector3(x, 0, z), PI / 2 if x == -17.5 else -PI / 2)
 for z in [-3, 0, 3]:
  prop("bookcaseOpen", Vector3(-19.3, 0, z), 2.1, PI / 2)
 prop("pottedPlant", Vector3(-11.3, 0, -4.7), 1.7)
 prop("coatRack", Vector3(-16, 0, 5.6), 1.7)
 office_sign("01 / DESIGN STUDIO", Vector3(-10.25, 3.3, 1.8), -PI / 2, 29)
 # West north: archives, cabinets and box stacks form hiding alcoves.
 for x in [-18.5, -15, -11.8]:
  for z in [-17.6, -10]:
   prop("bookcaseClosedWide" if z < -12 else "bookcaseOpen", Vector3(x, 0, z), 2.2)
 for z in [-18, -15, -12]:
  prop("cardboardBoxClosed", Vector3(-19, 0, z), 0.65)
  prop("cardboardBoxOpen", Vector3(-18.9, 0.65, z), 0.45)
 _workstation(Vector3(-13, 0, -7.6), PI)
 prop("lampSquareFloor", Vector3(-11.3, 0, -18.5), 1.8)
 prop("trashcan", Vector3(-17, 0, -7.3), 0.7)
 office_sign("03 / RECORDS & ARCHIVE", Vector3(-10.25, 3.3, -14), -PI / 2, 27)
 # East south: conference room, chairs and a presentation wall.
 prop("table", Vector3(15, 0, 0), 0.82)
 prop("table", Vector3(15, 0, 1.9), 0.82)
 for z in [-0.4, 1.1, 2.6]:
  prop("chairModernCushion", Vector3(13.5, 0, z), 1.1, -PI / 2)
  prop("chairModernCushion", Vector3(16.5, 0, z), 1.1, PI / 2)
 prop("laptop", Vector3(15, 0.83, 0), 0.33, PI, false)
 prop("televisionModern", Vector3(18.9, 1.3, 0), 1.1, PI / 2, false)
 prop("cabinetTelevisionDoors", Vector3(18.8, 0, 0), 0.85, PI / 2)
 prop("speaker", Vector3(18.8, 0.86, -1.7), 0.45, PI / 2, false)
 prop("speakerSmall", Vector3(18.8, 0.86, 1.7), 0.35, PI / 2, false)
 prop("pottedPlant", Vector3(18.5, 0, 4.5), 1.9)
 prop("bookcaseClosedDoors", Vector3(13, 0, -4.9), 1.8)
 office_sign("02 / MEETING ROOM", Vector3(10.25, 3.3, 1.8), PI / 2, 28)
 # East north: a break room with a complete kitchenette and reading nook.
 for z in [-17.8, -16.3, -14.8]:
  prop("kitchenCabinetDrawer", Vector3(18.8, 0, z), 0.9, PI / 2)
  prop("kitchenCabinetUpperDouble", Vector3(18.8, 2.0, z), 0.65, PI / 2)
 prop("kitchenSink", Vector3(18.8, 0, -13.3), 0.9, PI / 2)
 prop("kitchenFridge", Vector3(18.5, 0, -10), 2.0, PI / 2)
 prop("kitchenCoffeeMachine", Vector3(18.7, 0.92, -17.8), 0.48, PI / 2, false)
 prop("kitchenMicrowave", Vector3(18.7, 0.92, -16.3), 0.4, PI / 2, false)
 prop("toaster", Vector3(18.7, 0.92, -14.8), 0.25, PI / 2, false)
 prop("tableRound", Vector3(13.3, 0, -16.8), 0.8)
 for v in [Vector3(0, 0, 1.4), Vector3(0, 0, -1.4), Vector3(-1.4, 0, 0)]:
  prop("chairRounded", Vector3(13.3, 0, -16.8) + v, 1.0)
 prop("loungeDesignSofa", Vector3(14, 0, -8.3), 1.05, PI)
 prop("tableCoffeeSquare", Vector3(14, 0, -10), 0.5)
 prop("radio", Vector3(14, 0.52, -10), 0.25, 0, false)
 prop("plantSmall2", Vector3(15, 0.52, -10), 0.32, 0, false)
 prop("trashcan", Vector3(17, 0, -7.2), 0.8)
 office_sign("04 / KITCHEN & LOUNGE", Vector3(10.25, 3.3, -14), PI / 2, 27)

func _courtyard() -> void:
 solid(Vector3(0, -0.16, -7), Vector3(12, 0.32, 18), Color("bdc7b6"))
 # Clear central path and east/west route; planting stays away from every doorway.
 solid(Vector3(0, 0.015, -7), Vector3(3, 0.03, 18), Color("d8ceaf"), false)
 solid(Vector3(0, 0.018, -6), Vector3(12, 0.03, 2.4), Color("d8ceaf"), false)
 for side in [-1, 1]:
  for z in [-12.5, -1.4]:
   solid(Vector3(side * 3.8, 0.12, z), Vector3(2.7, 0.24, 3.2), Color("6b7e66"))
   # Trees use their mesh for trunk collisions so the canopy is not a solid box.
   piece(EXISTING + ("tree-high.glb" if z < -5 else "tree.glb"), Vector3(side * 3.8, 0.24, z), Vector3(2.8, 5.8 if z < -5 else 4.5, 2.8), 0, true)
  prop("benchCushionLow", Vector3(side * 4.4, 0, -9), 0.8, -side * PI / 2)
  piece(EXISTING + "plant.glb", Vector3(side * 4.8, 0.25, -14.5), Vector3(0.7, 0.9, 0.7), 0, false)
  piece(EXISTING + "lantern.glb", Vector3(side * 2.5, 0, -15), Vector3(0.4, 0.8, 0.4), 0, false)
  prop("plantSmall3", Vector3(side * 4.8, 0.24, -2.3), 0.65, 0, false)
 office_sign("THE COURTYARD", Vector3(0, 3.4, 1.75), 0, 42)
 office_sign("RECEPTION  /  LOBBY", Vector3(0, 3.1, -15.75), PI, 32)

func _lighting() -> void:
 for x in [-15, -8, 8, 15]:
  for z in [-14, 0, 13]:
   prop("lampSquareCeiling", Vector3(x, 4.3, z), 0.35, 0, false)
   var lamp := OmniLight3D.new()
   lamp.position = Vector3(x, 3.8, z)
   lamp.light_color = Color("fff0d5")
   lamp.light_energy = 1.3
   lamp.omni_range = 11.0
   add_child(lamp)
 # Bright reception lighting helps the player see the destination on arrival.
 var lobby_light := OmniLight3D.new()
 lobby_light.position = Vector3(0, 3.9, 13)
 lobby_light.omni_range = 13
 lobby_light.light_energy = 1.8
 lobby_light.light_color = Color("fff2df")
 add_child(lobby_light)

func wall(pos: Vector3, angle: float, asset: String) -> void:
 piece(BUILDING + asset + ".glb", pos, Vector3(0.24, WALL_HEIGHT, 4), angle, true, Color("e4e1d5") if asset == "wall" else Color.TRANSPARENT)

# Bounds include every child mesh and its imported transform. This also handles
# furniture with off-centre pivots and the original kit's centimetre-scale pieces.
func _mesh_bounds(node: Node, transform_so_far: Transform3D = Transform3D.IDENTITY) -> AABB:
 var result := AABB()
 var current := transform_so_far
 if node is Node3D: current = transform_so_far * node.transform
 if node is MeshInstance3D and node.mesh:
  result = current * node.mesh.get_aabb()
 for child in node.get_children():
  var child_box := _mesh_bounds(child, current)
  if child_box.size.length_squared() > 0:
   result = child_box if result.size.length_squared() == 0 else result.merge(child_box)
 return result

func _model(path: String) -> Node3D:
 if not _models.has(path):
  _models[path] = load(path) as PackedScene
 var model: Node3D = _models[path].instantiate()
 if not _bounds.has(path): _bounds[path] = _mesh_bounds(model)
 asset_usage[path] = int(asset_usage.get(path, 0)) + 1
 return model

func _tint(node: Node, color: Color) -> void:
 if node is MeshInstance3D:
  var material := StandardMaterial3D.new()
  material.albedo_color = color
  material.roughness = 0.85
  node.material_override = material
 for child in node.get_children(): _tint(child, color)

func _mesh_collision(node: Node) -> void:
 if node is MeshInstance3D and node.mesh:
  node.create_trimesh_collision()
  for child in node.get_children():
   if child is StaticBody3D: child.collision_layer = 2
 for child in node.get_children():
  if not child is StaticBody3D: _mesh_collision(child)

func piece(path: String, pos: Vector3, dimensions: Vector3, angle: float = 0, collide: bool = true, tint: Color = Color.TRANSPARENT) -> Node3D:
 var model := _model(path)
 var bounds: AABB = _bounds[path]
 var wrapper := Node3D.new()
 wrapper.name = path.get_file().get_basename().to_pascal_case()
 wrapper.position = pos
 wrapper.rotation.y = angle
 wrapper.scale = dimensions / bounds.size
 navigation.add_child(wrapper)
 wrapper.add_child(model)
 model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
 if tint.a > 0: _tint(model, tint)
 if collide: _mesh_collision(model)
 if path.get_file() in ["tree.glb", "tree-high.glb"]:
  _register_hiding_spot(wrapper, "tree", dimensions, -signf(pos.x) * PI / 2)
 return wrapper

func prop(asset: String, pos: Vector3, height: float, angle: float = 0, collide: bool = true) -> Node3D:
 var path := FURNITURE + asset + ".glb"
 var model := _model(path)
 var bounds: AABB = _bounds[path]
 var scale_factor := height / bounds.size.y
 var wrapper := Node3D.new()
 wrapper.name = asset.to_pascal_case()
 wrapper.position = pos
 wrapper.rotation.y = angle
 navigation.add_child(wrapper)
 wrapper.add_child(model)
 model.scale *= scale_factor
 model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_factor
 if collide and asset == "desk":
  _mesh_collision(model)
 elif collide:
  var body := StaticBody3D.new()
  body.collision_layer = 2
  wrapper.add_child(body)
  var collision := CollisionShape3D.new()
  var shape := BoxShape3D.new()
  shape.size = bounds.size * scale_factor
  collision.shape = shape
  collision.position.y = height / 2
  body.add_child(collision)
 if asset == "desk": _register_hiding_spot(wrapper, "desk", bounds.size * scale_factor, angle)
 elif asset == "bookcaseClosedDoors": _register_hiding_spot(wrapper, "closet", bounds.size * scale_factor, angle)
 elif asset == "kitchenCabinet": _register_hiding_spot(wrapper, "cabinet", bounds.size * scale_factor, angle)
 return wrapper

func solid(pos: Vector3, dimensions: Vector3, color: Color, collide: bool = true) -> void:
 var body := StaticBody3D.new()
 body.position = pos
 body.collision_layer = 2
 navigation.add_child(body)
 var mesh := MeshInstance3D.new()
 var cube := BoxMesh.new()
 cube.size = dimensions
 mesh.mesh = cube
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.roughness = 0.95
 mesh.material_override = material
 body.add_child(mesh)
 if collide:
  var collision := CollisionShape3D.new()
  var shape := BoxShape3D.new()
  shape.size = dimensions
  collision.shape = shape
  body.add_child(collision)

func office_sign(text: String, pos: Vector3, angle: float, font_size: int) -> void:
 var node := Label3D.new()
 node.text = text
 node.position = pos
 node.rotation.y = angle
 node.modulate = Color("123b46")
 node.font_size = font_size
 node.pixel_size = 0.005
 node.outline_size = 2
 node.outline_modulate = Color("f4eddd")
 add_child(node)


func _register_hiding_spot(visual: Node3D, kind: String, dimensions: Vector3, angle: float) -> void:
 var spot := HidingSpot.new()
 spot.name = "HidingSpot_%02d" % _spot_count
 spot.position = visual.position
 spot.rotation.y = angle
 add_child(spot)
 spot.setup("spot_%02d" % _spot_count, kind, visual, dimensions)
 _spot_count += 1

func _extra_hiding_furniture() -> void:
 # Lobby closets make the mechanic discoverable immediately after arrival.
 prop("bookcaseClosedDoors", Vector3(-5, 0, 15), 2.3)
 prop("bookcaseClosedDoors", Vector3(6, 0, 12), 2.3, -PI / 2)
 prop("kitchenCabinet", Vector3(17.8, 0, -18.5), 1.15, PI / 2)
 prop("kitchenCabinet", Vector3(-17, 0, -8), 1.15)
 for pos in [Vector3(-16.8, 0, -13), Vector3(-6, 0, 9), Vector3(17, 0, 8.5)]:
  var visual := prop("cardboardBoxOpen", pos, 1.25)
  var bounds: AABB = _bounds[FURNITURE + "cardboardBoxOpen.glb"]
  var dimensions := bounds.size * (1.25 / bounds.size.y)
  var hinge := Node3D.new()
  hinge.name = "LidHinge"
  hinge.position = Vector3(0, 1.25, -dimensions.z / 2)
  visual.add_child(hinge)
  var lid := MeshInstance3D.new()
  var mesh := BoxMesh.new()
  mesh.size = Vector3(dimensions.x, 0.07, dimensions.z)
  lid.mesh = mesh
  lid.position.z = dimensions.z / 2
  var material := StandardMaterial3D.new()
  material.albedo_color = Color("ba946b")
  lid.material_override = material
  hinge.add_child(lid)
  _register_hiding_spot(visual, "box", dimensions, 0)
