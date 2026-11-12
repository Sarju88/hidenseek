extends Node
## Server owns roles, reservations, searching, releases, and catches.
signal hider_found(seeker_id: int, hider_id: int)
const Spot = preload("res://scripts/hiding/hiding_spot.gd")
const HUD = preload("res://scripts/hiding/interaction_hud.gd")
const SEEKER := 0
const HIDER := 1
const RANGE := 3.2
const CHECK_SECONDS := 0.9
var roles: Dictionary = {}
var hidden: Dictionary = {} # peer -> {spot, entry}
var checks: Dictionary = {} # spot -> {peer, finish}
var cooldowns: Dictionary = {}
var found_counts: Dictionary = {}
const LOBBY := "lobby"
const HIDING := "hiding"
const SEEKING := "seeking"
@export var hiding_seconds := 60.0
var phase := LOBBY
var round_number := 0
var announcement := "Waiting for the host to start."
var caught: Dictionary = {}
var _anchors: Dictionary = {}
var _hide_deadline := 0
var _client_deadline := 0
var _last_countdown := -1
var _focus: OfficeHidingSpot
var _hud: Control
var _peek_camera: Camera3D
var _peek_yaw := 0.0
var _peek_pitch := 0.0
var _consumed_until := 0
var _local_check_started := 0
var _last_hidden := ""

func _ready() -> void:
 Network.player_connected.connect(_player_connected)
 Network.server_disconnected.connect(_reset)
 multiplayer.peer_disconnected.connect(_peer_left)
 if DisplayServer.get_name() != "headless":
  var canvas := CanvasLayer.new()
  canvas.layer = 20
  add_child(canvas)
  _hud = HUD.new()
  _hud.name = "InteractionHUD"
  canvas.add_child(_hud)
  _hud.start_requested.connect(_start_clicked)
  _peek_camera = Camera3D.new()
  _peek_camera.name = "HidingCamera"
  _peek_camera.fov = 78
  add_child(_peek_camera)

func spots() -> Dictionary:
 var result := {}
 for spot in get_tree().get_nodes_in_group("hiding_spots"):
  if get_parent().is_ancestor_of(spot): result[spot.spot_id] = spot
 return result

func player(peer: int) -> Character:
 return get_parent().get_node_or_null("PlayersContainer/" + str(peer)) as Character

func role(peer: int) -> int:
 return int(roles.get(peer, HIDER))

func _player_connected(_peer: int, _info: Dictionary) -> void:
 call_deferred("_refresh_members")

func _refresh_members() -> void:
 if not multiplayer.has_multiplayer_peer(): return
 if not multiplayer.is_server():
  request_snapshot.rpc_id(1)
  return
 var ids := Network.players.keys()
 for id in _anchors.keys():
  if not ids.has(id): _anchors.erase(id)
 for id in ids: _ensure_anchor(int(id))
 if phase != LOBBY:
  var seeker_present := false
  var hider_present := false
  for id in roles.keys():
   if not ids.has(id):
    roles.erase(id)
    caught.erase(id)
   elif roles[id] == SEEKER: seeker_present = true
   elif not caught.has(id): hider_present = true
  if not seeker_present or not hider_present:
   _return_to_lobby("Round ended. The host can start again.")
 _publish()

func _ensure_anchor(peer: int) -> void:
 if _anchors.has(peer): return
 for slot in range(1, Network.MAX_PLAYERS + 1):
  var point: Vector3 = get_parent().get_spawn_point(slot)
  if not _anchors.values().has(point):
   _anchors[peer] = point
   return
 _anchors[peer] = get_parent().get_spawn_point(peer)

func is_movement_locked(peer: int) -> bool:
 return phase == LOBBY or not roles.has(peer) or caught.has(peer) or (phase == HIDING and role(peer) == SEEKER)

func is_blind(peer: int) -> bool:
 return phase == HIDING and roles.has(peer) and role(peer) == SEEKER

func can_interact(peer: int) -> bool:
 return phase != LOBBY and roles.has(peer) and not is_movement_locked(peer)

func seconds_left() -> int:
 var deadline := _hide_deadline if multiplayer.is_server() else _client_deadline
 return maxi(0, int(ceil((deadline - Time.get_ticks_msec()) / 1000.0))) if phase == HIDING else 0

func _start_clicked() -> void:
 if not multiplayer.has_multiplayer_peer(): return
 if multiplayer.is_server(): start_round(multiplayer.get_unique_id())
 else: request_start_round.rpc_id(1)

@rpc("any_peer", "reliable")
func request_start_round() -> void:
 if multiplayer.is_server(): start_round(multiplayer.get_remote_sender_id())

func start_round(requester: int) -> bool:
 if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server(): return false
 if phase != LOBBY or requester != Network.session_host_id or not Network.players.has(requester): return false
 var ids := Network.players.keys()
 if ids.size() < 2: return false
 for id in hidden.keys(): _release(id)
 checks.clear()
 caught.clear()
 found_counts.clear()
 roles.clear()
 _anchors.clear()
 ids.shuffle()
 for i in range(ids.size()):
  var id: int = ids[i]
  roles[id] = SEEKER if i == 0 else HIDER
  _ensure_anchor(id)
  var actor := player(id)
  if actor:
   relocate_player(id, _anchors[id])
   if not multiplayer.get_peers().is_empty(): relocate_player.rpc(id, _anchors[id])
 round_number += 1
 phase = HIDING
 _hide_deadline = Time.get_ticks_msec() + int(hiding_seconds * 1000)
 _last_countdown = -1
 announcement = "Hiders: find a hiding spot!"
 _publish()
 return true

func _return_to_lobby(message: String) -> void:
 for id in hidden.keys(): _release(id)
 checks.clear()
 caught.clear()
 roles.clear()
 phase = LOBBY
 _hide_deadline = 0
 announcement = message
 _anchors.clear()
 for id in Network.players: _ensure_anchor(int(id))

func _tick_round() -> void:
 # Reassert server-owned frozen positions after processing client replication.
 for id in _anchors:
  var actor := player(int(id))
  if actor and is_movement_locked(int(id)):
   actor.global_position = _anchors[id]
   actor.velocity = Vector3.ZERO
 if phase == HIDING:
  if Time.get_ticks_msec() >= _hide_deadline:
   phase = SEEKING
   announcement = "Ready or not, here comes the seeker!"
   _publish()
  elif seconds_left() != _last_countdown:
   _last_countdown = seconds_left()
   _publish()

@rpc("any_peer", "reliable")
func request_snapshot() -> void:
 if not multiplayer.is_server(): return
 var sender := multiplayer.get_remote_sender_id()
 if not Network.players.has(sender): return
 receive_state.rpc_id(sender, _state())

func _state() -> Dictionary:
 var occupants := {}
 for id in hidden: occupants[id] = hidden[id].spot
 var checking := {}
 for id in checks: checking[id] = checks[id].peer
 var remaining := maxf(0.0, (_hide_deadline - Time.get_ticks_msec()) / 1000.0) if phase == HIDING else 0.0
 return {"roles": roles.duplicate(), "hidden": occupants, "checking": checking, "found": found_counts.duplicate(),
  "phase": phase, "remaining": remaining, "caught": caught.duplicate(), "anchors": _anchors.duplicate(),
  "host": Network.session_host_id, "round": round_number, "announcement": announcement}

func _publish() -> void:
 var state := _state()
 receive_state(state)
 if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty(): receive_state.rpc(state)

@rpc("authority", "reliable")
func receive_state(state: Dictionary) -> void:
 phase = state.phase
 caught = state.caught.duplicate()
 _anchors = state.anchors.duplicate()
 round_number = int(state.round)
 announcement = state.announcement
 Network.session_host_id = int(state.host)
 _client_deadline = Time.get_ticks_msec() + int(float(state.remaining) * 1000)
 roles = state.roles.duplicate()
 found_counts = state.found.duplicate()
 var all_spots := spots()
 for spot in all_spots.values():
  spot.occupant = 0
  spot.checking = state.checking.has(spot.spot_id)
 for id in state.hidden:
  if all_spots.has(state.hidden[id]): all_spots[state.hidden[id]].occupant = int(id)
 # Replicated characters can arrive a frame after their initial snapshot.
 for child in get_parent().get_node("PlayersContainer").get_children():
  if not child is Character: continue
  var id := str(child.name).to_int()
  var spot_id: String = state.hidden.get(id, "")
  var busy: bool = state.checking.values().has(id)
  var spot: OfficeHidingSpot = all_spots.get(spot_id)
  var check_kind := ""
  for checking_id in state.checking:
   if state.checking[checking_id] == id and all_spots.has(checking_id): check_kind = all_spots[checking_id].kind
  child.apply_hiding_state(spot_id, busy, spot.hide_position() if spot else Vector3.ZERO, check_kind)
  var anchor: Vector3 = _anchors.get(id, child.global_position)
  child.apply_round_lock(is_movement_locked(id), anchor, is_blind(id))
 if multiplayer.has_multiplayer_peer():
  var local_id := multiplayer.get_unique_id()
  get_node("/root/GameManager").set("current_role", role(local_id))
  var now_hidden: String = state.hidden.get(local_id, "")
  if now_hidden != _last_hidden:
   _last_hidden = now_hidden
   _peek_yaw = 0
   _peek_pitch = 0
  var is_checking: bool = state.checking.values().has(local_id)
  if is_checking and _local_check_started == 0: _local_check_started = Time.get_ticks_msec()
  if not is_checking: _local_check_started = 0
  get_parent()._update_mouse_mode()

func _peer_left(peer: int) -> void:
 if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server(): return
 _release(peer)
 for id in checks.keys():
  if checks[id].peer == peer: checks.erase(id)
 roles.erase(peer)
 cooldowns.erase(peer)
 found_counts.erase(peer)
 call_deferred("_refresh_members")

func _reset() -> void:
 if _focus: _focus.set_highlight(false)
 _focus = null
 hidden.clear()
 checks.clear()
 roles.clear()
 cooldowns.clear()
 found_counts.clear()
 _last_hidden = ""
 _local_check_started = 0
 phase = LOBBY
 caught.clear()
 _anchors.clear()
 _hide_deadline = 0
 _client_deadline = 0
 round_number = 0
 announcement = "Waiting for the host to start."
 for spot in spots().values():
  spot.occupant = 0
  spot.checking = false
 if _hud:
  _hud.visible = false
 if _peek_camera: _peek_camera.current = false

func should_consume_interaction() -> bool:
 return is_instance_valid(_focus) or Time.get_ticks_msec() < _consumed_until

func _unhandled_input(event: InputEvent) -> void:
 if not multiplayer.has_multiplayer_peer(): return
 var actor := player(multiplayer.get_unique_id())
 if not actor or _blocked(): return
 if event is InputEventMouseMotion and not actor.hidden_spot_id.is_empty():
  _peek_yaw = clampf(_peek_yaw - event.relative.x * 0.003, -0.6, 0.6)
  _peek_pitch = clampf(_peek_pitch - event.relative.y * 0.003, -0.3, 0.3)
 if event.is_action_pressed("pickup") and not event.is_echo():
  _update_focus(actor)
  if actor.hidden_spot_id.is_empty() and not is_instance_valid(_focus) and not actor.hiding_busy: return
  _consumed_until = Time.get_ticks_msec() + 250
  get_viewport().set_input_as_handled()
  if actor.hiding_busy: return
  var id := _focus.spot_id if is_instance_valid(_focus) else ""
  if multiplayer.is_server(): interact(multiplayer.get_unique_id(), id)
  else: request_interaction.rpc_id(1, id)

@rpc("any_peer", "reliable")
func request_interaction(spot_id: String) -> void:
 if multiplayer.is_server(): interact(multiplayer.get_remote_sender_id(), spot_id)

func _blocked() -> bool:
 var level := get_parent()
 return level.main_menu.is_menu_visible() or level.is_gameplay_input_blocked()

func _can_interact(actor: Character, spot: OfficeHidingSpot) -> bool:
 if not actor or not spot: return false
 var from := actor.global_position + Vector3.UP * 1.35
 var to := spot.prompt_point()
 if from.distance_to(to) > RANGE: return false
 var query := PhysicsRayQueryParameters3D.create(from, to, 2)
 query.exclude = [actor.get_rid()]
 var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty(): return true
 return hit.collider.get_meta("hiding_spot_id", "") == spot.spot_id

func interact(peer: int, spot_id: String) -> bool:
 if not multiplayer.is_server() or not Network.players.has(peer): return false
 var actor := player(peer)
 if not actor or not can_interact(peer): return false
 if hidden.has(peer):
  _release(peer)
  _publish()
  return true
 if actor.hiding_busy or Time.get_ticks_msec() < int(cooldowns.get(peer, 0)): return false
 var spot: OfficeHidingSpot = spots().get(spot_id)
 if not _can_interact(actor, spot): return false
 if checks.has(spot_id): return false
 if role(peer) == SEEKER:
  _play_world(spot.kind + "_open", spot.prompt_point())
  checks[spot_id] = {"peer": peer, "finish": Time.get_ticks_msec() + int(CHECK_SECONDS * 1000)}
  cooldowns[peer] = Time.get_ticks_msec() + 1200
 elif spot.occupant != 0:
  _tell(peer, "This hiding spot is already in use.")
  return false
 else:
  _play_world(spot.kind + "_open", spot.prompt_point())
  hidden[peer] = {"spot": spot_id, "entry": actor.global_position}
  cooldowns[peer] = Time.get_ticks_msec() + 250
 _publish()
 return true

func _release(peer: int, caught: bool = false) -> void:
 if not hidden.has(peer): return
 var entry: Vector3 = hidden[peer].entry
 var spot: OfficeHidingSpot = spots().get(hidden[peer].spot)
 if spot and not caught: _play_world(spot.kind + "_close", spot.prompt_point())
 hidden.erase(peer)
 var actor := player(peer)
 if not actor: return
 var exit_point: Vector3 = get_parent().get_spawn_point(peer) if caught else _safe_exit(actor, entry)
 relocate_player(peer, exit_point)
 if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty(): relocate_player.rpc(peer, exit_point)
 actor.apply_hiding_state("", false, Vector3.ZERO)

func _safe_exit(actor: Character, entry: Vector3) -> Vector3:
 var shape := CapsuleShape3D.new()
 shape.radius = 0.36
 shape.height = 1.7
 for offset in [Vector3.ZERO, Vector3(0.8, 0, 0), Vector3(-0.8, 0, 0), Vector3(0, 0, 0.8), Vector3(0, 0, -0.8)]:
  var point: Vector3 = entry + offset
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = shape
  query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.91)
  query.collision_mask = 3
  query.exclude = [actor.get_rid()]
  if actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return point
 return get_parent().get_spawn_point(str(actor.name).to_int())

@rpc("authority", "reliable")
func relocate_player(peer: int, point: Vector3) -> void:
 var actor := player(peer)
 if actor:
  actor.global_position = point
  actor.velocity = Vector3.ZERO

func _finish_checks() -> void:
 for id in checks.keys():
  var check_data: Dictionary = checks[id]
  if Time.get_ticks_msec() < check_data.finish: continue
  checks.erase(id)
  var spot: OfficeHidingSpot = spots().get(id)
  if spot: _play_world(spot.kind + "_close", spot.prompt_point())
  var seeker: int = check_data.peer
  if not _can_interact(player(seeker), spot):
   _publish()
   continue
  var occupant: int = spot.occupant
  if occupant != 0 and hidden.has(occupant):
   _release(occupant, true)
   caught[occupant] = true
   found_counts[seeker] = int(found_counts.get(seeker, 0)) + 1
   _tell(seeker, "Found a hider!", "found")
   _tell(occupant, "You were found! Back in the lobby.", "caught")
   hider_found.emit(seeker, occupant)
   var remaining_hiders := 0
   for member in roles:
    if roles[member] == HIDER and not caught.has(member): remaining_hiders += 1
   if remaining_hiders == 0: _return_to_lobby("All hiders found! The host can start the next round.")
  else: _tell(seeker, "Nobody here.", "empty")
  _publish()

func _tell(peer: int, message: String, cue: String = "blocked") -> void:
 if peer == multiplayer.get_unique_id(): feedback(message, cue)
 elif multiplayer.get_peers().has(peer): feedback.rpc_id(peer, message, cue)

@rpc("authority", "reliable")
func feedback(message: String, cue: String = "blocked") -> void:
 if _hud: _hud.notify(message)
 var audio := get_parent().get_node_or_null("GameAudio")
 if audio: audio.play_ui(cue)

func _play_world(cue: String, point: Vector3) -> void:
 play_world_sound(cue, point)
 if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty(): play_world_sound.rpc(cue, point)

@rpc("authority", "reliable")
func play_world_sound(cue: String, point: Vector3) -> void:
 var audio := get_parent().get_node_or_null("GameAudio")
 if audio: audio.play_at(cue, point)

func _update_focus(actor: Character) -> void:
 var next: OfficeHidingSpot
 if can_interact(str(actor.name).to_int()) and actor.hidden_spot_id.is_empty() and not actor.hiding_busy and not _blocked():
  var camera := get_viewport().get_camera_3d()
  if camera:
   var from := camera.global_position
   var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * (RANGE + from.distance_to(actor.global_position + Vector3.UP * 1.35)), 2 | 32)
   query.collide_with_areas = true
   query.exclude = [actor.get_rid()]
   var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
   if not hit.is_empty():
    var spot_id: String = hit.collider.spot_id if hit.collider is OfficeHidingSpot else hit.collider.get_meta("hiding_spot_id", "")
    next = spots().get(spot_id)
    if not _can_interact(actor, next): next = null
 if next != _focus:
  if is_instance_valid(_focus): _focus.set_highlight(false)
  _focus = next
  if _focus: _focus.set_highlight(true)

func _process(_delta: float) -> void:
 if not multiplayer.has_multiplayer_peer():
  if _hud: _hud.visible = false
  return
 if multiplayer.is_server():
  _tick_round()
  _finish_checks()
 if not _hud: return
 var peer := multiplayer.get_unique_id()
 var actor := player(peer)
 if not actor:
  _hud.visible = false
  return
 _hud.visible = not _blocked()
 if not _hud.visible:
  if is_instance_valid(_focus): _focus.set_highlight(false)
  _focus = null
  return
 _update_focus(actor)
 _hud.round_phase = phase
 _hud.seconds_remaining = seconds_left()
 _hud.blind = is_blind(peer)
 _hud.round_message = announcement
 _hud.start_button.visible = phase == LOBBY and peer == Network.session_host_id
 _hud.start_button.disabled = Network.players.size() < 2
 _hud.start_button.text = "START GAME" if round_number == 0 else "START NEXT ROUND"
 _hud.start_button.tooltip_text = "At least two players are needed" if Network.players.size() < 2 else "Randomly choose a seeker and begin hiding time"
 _hud.waiting = not roles.has(peer) or caught.has(peer)
 _hud.role_text = ("SEEKER  ·  Found: " + str(found_counts.get(peer, 0))) if role(peer) == SEEKER else "HIDER  ·  Find a hiding spot"
 if phase == LOBBY: _hud.role_text = "LOBBY  ·  %s players" % Network.players.size()
 elif _hud.waiting: _hud.role_text = "WAITING FOR NEXT ROUND"
 _hud.hidden_kind = ""
 if not actor.hidden_spot_id.is_empty():
  var spot: OfficeHidingSpot = spots().get(actor.hidden_spot_id)
  if spot and _peek_camera:
   _peek_camera.global_position = spot.view_position()
   _peek_camera.global_rotation = Vector3(_peek_pitch, spot.global_rotation.y + PI + _peek_yaw, 0)
   _peek_camera.current = true
   _hud.hidden_kind = spot.kind
 elif _peek_camera and _peek_camera.current:
  _peek_camera.current = false
  actor.get_node("SpringArmOffset/SpringArm3D/Camera3D").current = true
 _hud.prompt_visible = is_instance_valid(_focus)
 if _focus:
  var camera := get_viewport().get_camera_3d()
  var projected := camera.unproject_position(_focus.prompt_point())
  var size := get_viewport().get_visible_rect().size
  _hud.target_screen = Vector2(clampf(projected.x, 90, size.x - 90), clampf(projected.y, 100, size.y - 150))
  _hud.action_text = ("Shake " if _focus.kind == "tree" else "Check ") + _focus.display_name() if role(peer) == SEEKER else ("Hide under " if _focus.kind == "desk" else "Hide in ") + _focus.display_name()
 _hud.check_progress = clampf((Time.get_ticks_msec() - _local_check_started) / (CHECK_SECONDS * 1000), 0, 1) if actor.hiding_busy else -1.0
