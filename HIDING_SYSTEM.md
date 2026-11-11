# Office hiding

The office has 17 interactable hiding spots: 3 closets, 4 courtyard trees,
5 desks, 3 large storage boxes, and 2 low cabinets. The small decorative
boxes and upper kitchen cupboards are not hiding spots.

Look at an object within 3.2 metres. The white outline, hand icon, and cream
E keycap show that it is interactable. E takes priority over item pickup
when a hiding spot is targeted; otherwise existing E pickup behavior remains.

- Hiders: E enters; E again exits. Movement, pickup and attacks are disabled
  while hidden. Mouse movement lets you peek. Closets/cabinets/boxes have
  a narrow view; desks have a low view; trees provide an elevated view.
- Seekers: E checks for 0.9 seconds. Doors open, lids lift, trees shake, and
  desk inspections crouch. Empty and occupied spots have identical prompts
  and check timing. A successful check reveals the hider, returns them to
  the lobby, and adds one to the seeker's found count.
- One hider per spot. The server validates range, line of sight, roles,
  occupancy, and check cooldowns. Exits try the entry position and nearby
  clear positions before falling back to the lobby. Disconnects free spots.
- Solo hosting starts as a hider. F6 switches between hider and seeker for
  practicing the mechanics. Multiplayer assigns one seeker; later arrivals
  are hiders. The current seeker stays assigned until they leave.

## Verification

Run from this project directory:

```
godot --headless --path . res://tests/hiding_test.tscn
godot --headless --path . res://tests/office_layout_test.tscn
```

For the real multiplayer test, start these in three terminals:

```
godot --headless --path . res://tests/hiding_network_test.tscn -- --net-server
godot --headless --path . res://tests/hiding_network_test.tscn -- --join=127.0.0.1
godot --headless --path . res://tests/hiding_network_test.tscn -- --join=127.0.0.1
```

The network test verifies remote requests, roles, occupancy snapshots, concealed
bodies, timed discovery, restored collisions, and owner-side lobby relocation.

## Camera and sound

Normal play starts in third person with a 3.2 metre shoulder camera. A sphere
probe retracts the camera against office walls/furniture. Hiding still uses the
restricted peek cameras; exiting restores the third-person camera. The center
dot aims interactions, which still validate the player's 3.2 metre reach.

Kenney Impact Sounds, imported from Downloads, provide surface footsteps,
landings, menu clicks, wood/cabinet/lid checks, tree rustling, and find/empty
feedback. Nearby interaction effects play in 3D on every client; personal
feedback plays only for the affected player. Snapshots do not replay old audio.
Dedicated servers stay silent. Original CC0 license is in assets/audio/.

Audio and camera verification:

```
godot --headless --path . res://tests/audio_camera_test.tscn
```

The test decodes the effects, verifies playback with Godot's dummy audio mixer,
checks footsteps, third-person visibility, camera wall collision, and targeting.
The multiplayer test also verifies world effects and private feedback on both
clients. Tests use separate ports 18080–18082; normal hosting remains on 8080.
