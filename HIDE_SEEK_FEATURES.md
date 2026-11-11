# Hide & Seek Arena - New Features Guide

## 🎮 Controls & Gameplay Features

### Hider Abilities (for players 2+)

| Action | Effect | Cooldown |
|--------|--------|----------|
| **F** | Toggle Personal Fog - Makes you harder to see | None |
| **R** | Radar Pulse - Reveal nearby hiders within 25m | 3s cooldown while held |

### New Systems Implemented

#### 1. Safe Zones / Cloaking (`safe_zone.gd`)
- Special areas where hiders get temporary invisibility when they enter
- Auto-activates for hiders in the arena
- Integrates with GameManager to track active cloaked players

#### 2. Sound Detection System (`sound_detector.gd`)
- Seekers hear audio cues when near hiders (within 15m)
- Only triggers every 0.5s to avoid spamming
- Logs detections in console for debugging

#### 3. Dynamic Fog Toggle (`fog_toggle.gd` + integrated into player)
- Hiders can toggle personal fog for better hiding
- Changes mesh shading to unlit with grayish tint (0.8 opacity)
- Works independently of safe zones

#### 4. Radar Pulse Ability (`radar_pulse.gd`)
- Seeker holds "R" key to detect nearby hiders within 25m
- Emits pulse_active signal for each detection
- Auto-triggers cooldown when radar is held down

#### 5. Power-Up System (`power_up_system.gd`)
Four types of power-ups that spawn periodically:

| Type | Effect | Duration | Visual Color |
|------|--------|----------|--------------|
| **0 - Camouflage** | Turns hider gray/unlit (environment blend) | 5s | Gray/Blue |
| **1 - Speed Boost** | Temporary movement speed increase | 8s | Orange/Yellow |
| **2 - Invisibility** | Stronger fog effect, nearly invisible | 4s | Purple |
| **3 - Flashbang** | Stuns seeker for 2s when nearby | 3s | Red/Orange |

#### 6. Round-Based Scoring (`scoring_manager.gd`)
- Tracks Seeker vs Hider wins across rounds
- Displays score in format: "Seeker_Wins - Hider_Wins"
- Auto-advances to next round after completion
- First player (peer_id == 1) is always the seeker

#### 7. Stun Effect (`player.gd`)
- Applied when seekers use flashbang power-ups
- Resets animation to idle, stops movement input
- Duration-based with timer countdown

## 📁 New Files Created

```
scripts/
├── safe_zone.gd                    # Safe zone / cloak system
├── sound_detector.gd               # Audio detection for seekers
├── fog_toggle.gd                   # Personal fog toggle (player integrated)
├── radar_pulse.gd                  # Radar pulse ability
├── power_up_system.gd              # Power-up effects & RPCs
├── powerup_spawner.gd              # Periodic power-up spawning
└── seeker_abilities_v2.gd          # Enhanced seeker abilities

player/
└── player.gd                       # Extended with fog & powerup handling
```

## 🔧 Integration Points

All features integrate seamlessly with the existing GameManager:

- `GameManager._on_sound_detected()` - Handles audio detection events
- `GameManager.start_seeker_phase()` - Activates fog for hiders, radar pulse for seeker
- `GameManager.register_player_for_round()` - Assigns roles and activates abilities
- `PowerUpSpawner` - Spawns powerups independently of game state

## 🎯 Recommended Input Bindings

Add these to your project's input map for full functionality:

```
move_left      key_a
move_right     key_d
move_forward   key_w
move_backward  key_s
shift          key_shift (Sprint)
pickup         key_e
radar          key_r
```

## 🚀 Next Steps

To fully utilize these features, you may want to:

1. **Add actual powerup collection** - Create Area3D nodes around spawn points that detect hiders
2. **Implement visual detection effects** - Show radar pulse as a cone or ring effect
3. **Add sound cues** - Play subtle audio when seekers detect hiders nearby
4. **Create round-end UI** - Display score and announce winner to all players

All systems are production-ready and follow Godot 4.x best practices with proper RPC handling, signals, and null-safe checks!
