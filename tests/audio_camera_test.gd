extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _ready() -> void: call_deferred("run")
func run() -> void:
 Network.server_port = 18082
 var level: Node3D = load("res://scenes/level/level.tscn").instantiate()
 get_tree().root.add_child(level)
 get_tree().current_scene = level
 Network.leave_game()
 multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 Network.players = {1: {"nick": "Tester", "skin": 0}}
 var actor: Character = load("res://scenes/level/player.tscn").instantiate()
 actor.name = "1"
 actor.position = Vector3(0, 0.05, 18.5)
 level.get_node("PlayersContainer").add_child(actor)
 var audio: Node3D = level.get_node("GameAudio")
 # Dummy audio still runs Godot's decoder/mixer, without requiring speakers.
 audio.enabled = true
 for cue in audio.CUES:
  for i in range(5):
   var stream: AudioStream = audio._stream(cue)
   check(stream != null and stream.get_length() > 0, "Audio cue must decode: " + cue)
 audio.play_at("closet_open", actor.position)
 check(audio._spatial[0].playing, "World interaction sound must play")
 audio.play_ui("found")
 check(audio._ui[0].playing, "Local feedback sound must play")
 check(audio.surface_at(Vector3(0, 0, 17)) == "carpet", "Lobby runner uses carpet steps")
 check(audio.surface_at(Vector3(-3.8, 0.24, -12.5)) == "grass", "Courtyard beds use grass steps")
 check(audio.surface_at(Vector3(-15, 0, 0)) == "concrete", "Office floor uses hard steps")
 await get_tree().physics_frame
 await get_tree().physics_frame
 var boom: SpringArm3D = actor.get_node("SpringArmOffset/SpringArm3D")
 check(not actor._spring_arm_offset.is_first_person and actor._body.visible, "Normal play starts in third person with visible character")
 check(boom.collision_mask == 2 and boom.shape is SphereShape3D, "Camera collision probes the world")
 for i in range(6): await get_tree().physics_frame
 check(boom.get_hit_length() < boom.spring_length, "Camera retracts before passing through the lobby wall")
 # Third-person aiming extends past the camera boom, while actor-based range still applies.
 actor.global_position = Vector3(-5, 0.05, 17.5)
 level.main_menu.hide()
 for i in range(6): await get_tree().physics_frame
 var system: Node = level.get_node("HidingSystem")
 system._update_focus(actor)
 check(system._focus != null and system._focus.kind == "closet", "E still targets a nearby closet from third person")
 # Walking must generate a real footstep, while standing and teleporting stay silent.
 actor.set_physics_process(false)
 audio._walkers.clear()
 audio._physics_process(1.0 / 60)
 var before: int = audio._spatial_index
 for i in range(20):
  actor.global_position.x += 0.1
  audio._physics_process(1.0 / 60)
 check(audio._spatial_index > before, "Walking produces surface footsteps")
 before = audio._spatial_index
 for i in range(10): audio._physics_process(1.0 / 60)
 check(audio._spatial_index == before, "Standing still does not produce footsteps")
 actor.global_position += Vector3(10, 0, 0)
 audio._physics_process(1.0 / 60)
 check(audio._spatial_index == before, "Teleporting does not produce footsteps")
 audio._reset()
 check(not audio._spatial[0].playing and not audio._ui[0].playing, "Session reset stops old sounds")
 await get_tree().create_timer(0.15).timeout
 print("[Audio/camera test] failures=", failures)
 get_tree().quit(1 if failures else 0)
