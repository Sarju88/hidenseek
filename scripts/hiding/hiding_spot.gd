class_name OfficeHidingSpot
extends Area3D

var spot_id := ""
var kind := "closet"
var visual: Node3D
var dimensions := Vector3.ONE
var occupant := 0
var checking := false
var _outlines: Array[MeshInstance3D] = []
var _doors: Array[Node3D] = []
var _lids: Array[Node3D] = []
var _door_rotations: Array[Vector3] = []
var _rest_rotation := Vector3.ZERO
var _elapsed := 0.0
var _was_checking := false

func setup(id: String, type: String, model: Node3D, size: Vector3) -> void:
 spot_id = id
 kind = type
 visual = model
 dimensions = size
 collision_layer = 32
 collision_mask = 0
 monitoring = false
 add_to_group("hiding_spots")
 var collision := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(0.85, 1.9, 0.85) if kind == "tree" else dimensions + Vector3(0.08, 0.08, 0.08)
 collision.shape = shape
 collision.position.y = shape.size.y / 2
 add_child(collision)
 _rest_rotation = visual.rotation
 _prepare_visual(visual)

func _prepare_visual(node: Node) -> void:
 # Gather first: outline children must never recursively generate more outlines.
 var children := node.get_children()
 if node is StaticBody3D: node.set_meta("hiding_spot_id", spot_id)
 if node is Node3D and node.name == "LidHinge": _lids.append(node)
 if node is Node3D and node.name.to_lower().begins_with("door"):
  _doors.append(node)
  _door_rotations.append(node.rotation)
 if node is MeshInstance3D and node.mesh:
  var outline := MeshInstance3D.new()
  outline.name = "InteractionOutline"
  outline.mesh = node.mesh
  var material := ShaderMaterial.new()
  material.shader = preload("res://assets/shaders/interaction_outline.gdshader")
  outline.material_override = material
  outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  outline.visible = false
  node.add_child(outline)
  _outlines.append(outline)
 for child in children: _prepare_visual(child)

func set_highlight(active: bool) -> void:
 for mesh in _outlines: mesh.visible = active

func prompt_point() -> Vector3:
 return global_position + Vector3.UP * (1.25 if kind == "tree" else minf(dimensions.y * 0.65, 1.45))

func hide_position() -> Vector3:
 match kind:
  "tree": return global_position + Vector3.UP * 2.8
  "desk": return global_position + Vector3.UP * 0.04
  _: return global_position + Vector3.UP * 0.12

func view_position() -> Vector3:
 var front := global_basis.z.normalized()
 match kind:
  "tree": return global_position + Vector3.UP * 3.5 + front * (dimensions.z / 2 + 0.2)
  "desk": return global_position + Vector3.UP * 0.58 + front * dimensions.z * 0.18
  "box": return global_position + Vector3.UP * dimensions.y * 0.83 + front * (dimensions.z / 2 + 0.04)
  _: return global_position + Vector3.UP * minf(1.5, dimensions.y * 0.7) + front * (dimensions.z / 2 + 0.04)

func display_name() -> String:
 match kind:
  "desk": return "desk"
  "box": return "storage box"
  "cabinet": return "cabinet"
  _: return kind

func _process(delta: float) -> void:
 if checking and not _was_checking: _elapsed = 0
 _was_checking = checking
 _elapsed += delta
 var open_amount := sin(minf(_elapsed / 0.9, 1.0) * PI) if checking else 0.0
 if kind == "tree":
  visual.rotation = _rest_rotation + Vector3(0, 0, sin(_elapsed * 40) * 0.045 * open_amount)
 elif not _doors.is_empty():
  for i in range(_doors.size()):
   _doors[i].rotation = _door_rotations[i] + Vector3(0, open_amount * 1.1 * (1 if i % 2 == 0 else -1), 0)
 elif kind == "box" and not _lids.is_empty():
  for lid in _lids: lid.rotation.x = -open_amount * 1.3
 elif kind == "box":
  visual.rotation = _rest_rotation + Vector3(sin(_elapsed * 30) * 0.035 * open_amount, 0, 0)
