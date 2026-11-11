# Hide & Seek Arena - Setup Guide

## Quick Start (No External Dependencies Required!)

This project now includes a complete hide-and-seek game system with:

- **Seeker vs Hider roles** in timed rounds
- **Red detection ring** around the seeker (1.5m radius)
- **Minimap UI** for hiders showing seeker position
- **Stealth mechanics**: crouch to move quietly, sprint drains stamina
- **AI Bot support** for solo testing

## Installation Steps

### 1. Open Godot 4.x
No external tools needed! Everything is built into Godot.

### 2. Configure the Game Manager
Open `res://scripts/autoload/game_manager.gd` and verify settings:
```gdscript
@export var round_duration: float = 60.0 as float      # Time per round
@export var max_rounds: int = 5 as int                 # Total rounds
@export var seeker_start_delay: float = 3.0 as float   # Delay before seeker can see hiders
```

### 3. Set Up the Level Scene
Open `res://scenes/main_level.tscn` and ensure it has:
- A `GameManager` autoload (already configured)
- BSP terrain generator for procedural buildings
- Proper lighting setup

### 4. Player Controller Setup
Each player controller (`res://scenes/player.tscn`) should have:
- Movement bindings: WASD + Mouse
- Sprint: Shift key
- Crouch: Ctrl or Space (for stealth bonus)

## How to Play

### As Seeker:
1. You see a **red ring** around you (your detection range)
2. Hiders inside the ring are "found" and flash red
3. Find all hiders before time runs out!

### As Hider:
1. Hide behind walls, in rooms, or anywhere visible to seeker
2. Watch your minimap for the **red dot** (seeker)
3. Crouch to move slower but quieter
4. Don't sprint near the seeker - it drains stamina and makes noise!

## Testing Without Network

### Option 1: AI Bot Mode (Recommended)
Run the game with bots as both seekers and hiders:
```bash
godot --path /home/arjun/3d-multiplayer-template --quit
```

Then in Godot:
- Open `res://scripts/scenes/test_hide_seek.gd`
- Set `num_ai_hiders = 4` for a full game feel
- Run the scene to see AI hiders and seeker bots in action

### Option 2: Manual Testing
1. Press **R** to restart the round
2. Assign yourself as Seeker or Hider via console or inspector
3. Test detection mechanics by moving around

## Network Play (Multiplayer)

### Host a Game:
```bash
godot --path /home/arjun/3d-multiplayer-template --quit
```

In Godot, run the main scene and press **F5**. The host will:
- Spawn as seeker (peer_id = 1) by default
- See all hiders immediately when phase starts

### Join a Game:
Connect via WebSocket or ENet using the `join_game()` function in `network.gd`.

## Visual Indicators

| Indicator | Meaning |
|-----------|---------|
| Red ring around seeker | Your detection range (1.5m) |
| Hider flashes red | They've been found! |
| Minimap shows red dot | Seeker is nearby |
| Timer turns yellow | Less than 10 seconds left |

## Troubleshooting

### "No player scene assigned" warning:
- Check `res://scenes/player.tscn` exists and loads correctly

### AI bots not moving:
- Verify `SimpleAIBot` script is attached to bot instances
- Check patrol points are set in the inspector

### Minimap not showing:
- Ensure `MinimapController` is added as a CanvasLayer node
- Check `show_seeker = true` in minimap settings

## Next Steps (Optional Enhancements)

1. **Add sound effects** for seeker detection and hider footsteps
2. **Create hiding spots** using closets or props from Kenney assets
3. **Implement disguises** that let hiders blend into the environment
4. **Add power-ups**: speed boost, temporary invisibility, etc.
5. **Build a lobby system** for role selection before rounds start

Enjoy your hide-and-seek arena! 🎮
