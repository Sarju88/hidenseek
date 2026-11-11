extends Node3D
## Positional effects and surface-aware steps for every visible network player.
## Reliable interaction events are sent separately from persistent hiding snapshots.
const PATH := "res://assets/audio/"
const CUES := {
 "closet_open": ["impactWood_medium", -10.0],
 "closet_close": ["impactWood_light", -12.0],
 "cabinet_open": ["impactWood_light", -10.0],
 "cabinet_close": ["impactWood_light", -14.0],
 "box_open": ["impactPlank_medium", -13.0],
 "box_close": ["impactSoft_medium", -12.0],
 "tree_open": ["footstep_grass", -6.0],
 "tree_close": ["footstep_grass", -10.0],
 "desk_open": ["impactSoft_medium", -17.0],
 "desk_close": ["impactSoft_medium", -19.0],
 "found": ["impactBell_heavy", -14.0],
 "caught": ["impactSoft_heavy", -10.0],
 "empty": ["impactGeneric_light", -17.0],
 "ui": ["impactGeneric_light", -19.0],
 "blocked": ["impactSoft_medium", -19.0],
 "footstep_concrete": ["footstep_concrete", -11.0],
 "footstep_carpet": ["footstep_carpet", -7.0],
 "footstep_grass": ["footstep_grass", -10.0],
 "land": ["impactSoft_heavy", -15.0]
}
var enabled := DisplayServer.get_name() != "headless"
var _streams: Dictionary = {}
var _variants: Dictionary = {}
var _spatial: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _spatial_index := 0
var _ui_index := 0
var _walkers: Dictionary = {}

func _ready() -> void:
 add_to_group("game_audio")
 if enabled: _create_players()
 Network.server_disconnected.connect(_reset)
 for button in get_parent().find_children("*", "BaseButton", true, false):
  button.pressed.connect(func(): play_ui("ui"))

func _create_players() -> void:
 if not _spatial.is_empty(): return
 for i in range(20):
  var voice := AudioStreamPlayer3D.new()
  voice.name = "WorldEffect" + str(i)
  voice.unit_size = 4.0
  voice.max_distance = 22.0
  voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
  add_child(voice)
  _spatial.append(voice)
 for i in range(4):
  var voice := AudioStreamPlayer.new()
  voice.name = "LocalEffect" + str(i)
  add_child(voice)
  _ui.append(voice)

func _stream(cue: String) -> AudioStream:
 if not CUES.has(cue): return null
 var variant := int(_variants.get(cue, -1)) + 1
 variant %= 5
 _variants[cue] = variant
 var path: String = PATH + str(CUES[cue][0]) + "_%03d.ogg" % variant
 if not _streams.has(path): _streams[path] = load(path) as AudioStream
 return _streams[path]

func play_at(cue: String, point: Vector3) -> void:
 if not enabled or not CUES.has(cue): return
 _create_players()
 var voice := _spatial[_spatial_index % _spatial.size()]
 _spatial_index += 1
 voice.stop()
 voice.stream = _stream(cue)
 voice.global_position = point
 voice.volume_db = float(CUES[cue][1])
 voice.pitch_scale = randf_range(0.94, 1.06)
 voice.play()

func play_ui(cue: String) -> void:
 if not enabled or not CUES.has(cue): return
 _create_players()
 var voice := _ui[_ui_index % _ui.size()]
 _ui_index += 1
 voice.stop()
 voice.stream = _stream(cue)
 voice.volume_db = float(CUES[cue][1])
 voice.pitch_scale = 1.35 if cue == "found" else 1.0
 voice.play()

func surface_at(point: Vector3) -> String:
 var courtyard := absf(point.x) < 6 and point.z > -16 and point.z < 2
 if courtyard:
  var bed := absf(point.x) > 2.45 and absf(point.x) < 5.15
  if bed and ((point.z > -14.1 and point.z < -10.9) or (point.z > -3 and point.z < 0.2)): return "grass"
 if absf(point.x) < 1.7 and point.z > 6: return "carpet"
 if absf(absf(point.x) - 8) < 0.75 and point.z > -20 and point.z < 6: return "carpet"
 return "concrete"

func _physics_process(delta: float) -> void:
 if not enabled or not multiplayer.has_multiplayer_peer(): return
 var container := get_parent().get_node_or_null("PlayersContainer")
 if not container: return
 var active := {}
 for actor in container.get_children():
  if not actor is Character: continue
  var id := str(actor.name)
  active[id] = true
  var point: Vector3 = actor.global_position
  if not _walkers.has(id):
   _walkers[id] = {"position": point, "distance": 0.0, "grounded": true, "fall_speed": 0.0}
   continue
  var state: Dictionary = _walkers[id]
  var displacement: Vector3 = point - state.position
  state.position = point
  if not actor.hidden_spot_id.is_empty() or actor.hiding_busy or displacement.length() > 1.5:
   state.distance = 0.0
   state.grounded = true
   continue
  var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point - Vector3.UP * 0.14, 2)
  query.exclude = [actor.get_rid()]
  var grounded: bool = not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
  if grounded and not state.grounded and float(state.fall_speed) < -1.5: play_at("land", point)
  state.fall_speed = displacement.y / maxf(delta, 0.001)
  state.grounded = grounded
  if not grounded: continue
  displacement.y = 0
  state.distance += displacement.length()
  if float(state.distance) >= 1.5:
   state.distance = fmod(float(state.distance), 1.5)
   play_at("footstep_" + surface_at(point), point)
 for id in _walkers.keys():
  if not active.has(id): _walkers.erase(id)

func _reset() -> void:
 _walkers.clear()
 for voice in _spatial: voice.stop()
 for voice in _ui: voice.stop()
