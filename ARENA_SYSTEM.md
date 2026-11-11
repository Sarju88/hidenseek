# 🏗️ Procedural Multi-Level Arena System

## Overview
This arena system generates a unique multi-level hide & seek environment each session with:
- **Procedural generation** - Different layout every game using time-based seeds
- **4 vertical levels** - Ground → Mid → Rooftop progression
- **Guaranteed connectivity** - Stairs and ladders ensure all areas are reachable
- **Organic design** - Random cover objects, bridges, arches for tactical gameplay

## Features

### 🎨 Visual Style
- Bright cartoon aesthetic with colorful platforms
- Procedural skybox (blue horizon, warm sun)
- SSao shadows and fog for depth
- Each level has a unique color theme

### 🏔️ Level Structure
```
Level 4 (Rooftop) - 12m high
    └── Bridge connection
        ├── Level 3 (Mid-tier) - 8m high  
            └── Bridge/Stairs connection
                ├── Level 2 (Lower Mid) - 4m high
                    └── Staircase up to ground
                        └── Ground Plaza (0m)
```

### 🌉 Vertical Access Points
- **Staircases** (ground → mid): Solid steps, climbable
- **Ladders** (mid → rooftop): Rung-based climbing
- **Bridges**: Connect levels horizontally with slight angles for variety

## How It Works

### ArenaGenerator Script (`scripts/autoload/arena_generator.gd`)
```gdscript
# Configuration
@export var num_levels: int = 4          # Vertical layers
@export var seed: int = -1               # Use Time.get_ticks_msec() for randomness

# Usage in _ready():
var rng_seed = Time.get_ticks_msec()     # Unique each session
arena_generator.seed = rng_seed
```

### Generation Algorithm
1. **Ground Level**: Large plaza with 8-12 random cover objects (crates, pillars)
2. **Upper Levels** (1-3): Smaller platforms (~5m smaller per level), colorful materials
3. **Connections**: Each new level connects to 1-2 previous levels via bridges
4. **Access Points**: Stairs/ladders automatically placed at random positions

### Player Integration (`scripts/level/main_level.gd`)
```gdscript
# Spawn a player (calls arena_generator.spawn_demo_player on first load)
var spawn_node := $ArenaGenerator as ArenaGenerator
spawn_node.seed = Time.get_ticks_msec()  # Different layout each session
```

## Camera System

### Third-Person Orbit (`scripts/camera/third_person_camera.gd`)
- Mouse/Arrow key rotation around player
- Spring-arm elastic feel for cartoon aesthetic
- Configurable orbit radius (3.0 - 15.0m)

### Player Controller (`scripts/player/player_controller.gd`)
```gdscript
# Input mapping:
WASD / Arrows    → Move character
Space / Up       → Jump  
Mouse/Arrows     → Rotate camera orbit
```

## Testing & Debugging

### Verify Generation
1. Run the project (F5 or Run button)
2. Check terminal for output:
   ```
   [ArenaGen] Arena seed: 1731148923456 - Layout will be unique this session
   [ArenaGen] Generated layout: layout_0_423_1_891_2_567_3_234
   ```

### Reuse Same Layout (Development)
```gdscript
arena_generator.seed = 12345  # Fixed seed for reproducible testing
```

### Arena Bounds
- Base size: 60m × 60m (ground level)
- Each upper level reduces by ~5m per floor
- Safe play area: ±45m on X/Z axes from center

## Extending the System

### Add Kenney Assets
Replace procedural boxes with imported models:
```gdscript
# In create_cover_object():
var stair_asset = preload("res://assets/kenney/stairs.tscn")
var mesh = stair_asset.instantiate() as MeshInstance3D
ground_level.add_child(mesh)
mesh.position = position
```

### Custom Level Themes
Override colors in `create_floor()`:
```gdscript
func create_floor(parent, size, color, rng):
    # Example: Darker upper levels for contrast
    var theme_color = if level_idx > 2: Color(0.1, 0.15, 0.3) else: color
```

### Add More Levels
Simply increase `num_levels` export variable - system auto-adjusts heights!

## Files Modified/Created
- ✅ `scripts/autoload/arena_generator.gd` - Core generation logic
- ✅ `scripts/level/main_level.gd` - Scene management & player spawning  
- ✅ `scripts/player/player_controller.gd` - Movement + camera input
- ✅ `scenes/arena_multi_level.tscn` - Template for arena structure
- ✅ `scenes/main_level.tscn` - Integrated with ArenaGenerator

---

**Built for Hide & Seek gameplay: Tactical verticality meets chaotic fun!** 🎮
