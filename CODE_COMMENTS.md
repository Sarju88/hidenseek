# Godot 4.x Multiplayer Template - Code Documentation

## Architecture Overview

This is a server-authoritative multiplayer game template supporting up to 10 players in a competitive arena shooter. The architecture prioritizes:

- **Server Authority**: All critical state (inventory, animations, item pickups) is validated and processed on the server
- **Protocol Flexibility**: Supports both ENet UDP (default, lower latency) and WebSocket protocols
- **Deterministic Synchronization**: Uses sequence numbers and timestamps to prevent replay attacks and race conditions

## Core Design Decisions

### 1. Network Layer (`autoload/network.gd`)

**Protocol Selection:**
```gdscript
# Default: ENet UDP for native platforms (lower latency)
var enet := ENetMultiplayerPeer.new()
error = enet.create_server(SERVER_PORT, MAX_PLAYERS)

# Alternative: WebSocket for browser compatibility
if websocket_host or "--websocket" in OS.get_cmdline_user_args():
    var ws := WebSocketMultiplayerPeer.new()
    error = ws.create_server(8081)
```

**Why ENet UDP?**
- Connection-oriented but uses UDP transport (no TCP overhead)
- Built-in range compression reduces bandwidth by ~60%
- Native Godot support, no external dependencies

### 2. RPC Patterns (`player.gd`, `inventory/player_inventory.gd`)

The project uses three distinct RPC patterns:

| Pattern | Direction | Use Case | Example |
|---------|-----------|----------|---------|
| `@rpc("any_peer", "call_local")` | Server → All peers (broadcast) | Syncing state to all clients | `_sync_registered_player()`, `request_animation_state()` |
| `@rpc("authority", "reliable")` | Client → Server only | Critical commands requiring validation | `add_world_item()`, `request_equip_item()` |
| `@rpc("any_peer", "reliable")` | Bidirectional reliable | Commands that need acknowledgment | `sync_animation_state()`, `request_move_item()` |

**Key Security Pattern:** Every client-to-server RPC validates the sender:
```gdscript
func _is_owner_request() -> bool:
    var sender := multiplayer.get_remote_sender_id()
    return sender == get_multiplayer_authority() or (sender == 0 and multiplayer.is_server())
```

This ensures only the legitimate owner of a player can modify their state.

### 3. Animation Synchronization (`player.gd`)

**Problem:** In multiplayer games, playing animations locally based on input creates desync between clients.

**Solution:** Server-authoritative animation sync with token-based rate limiting:
```gdscript
const SERVER_ANIMATION_REQUESTS_PER_SECOND := 10.0
const SERVER_ANIMATION_REQUEST_BURST := 6.0

func _server_consume_animation_request_token() -> bool:
    # Tokens refill at 10/sec, burst of 6 allowed initially
    if _last_server_animation_request_tokens < 1.0:
        return false
    _server_animation_request_tokens -= 1.0
    return true
```

**Flow:**
1. Client sends animation request via `@rpc("any_peer", "call_local")`
2. Server validates it's from the legitimate owner (`_is_owner_request()`)
3. Server consumes a token (prevents spam)
4. Server broadcasts the authoritative state to all clients

### 4. Inventory System (`inventory/player_inventory.gd`)

**Server-Authoritative Design:**
- All inventory modifications go through RPC calls validated on server
- Client can request changes, but server is the source of truth
- Uses dictionary serialization for network transfer:
```gdscript
func to_dict() -> Dictionary:
    return {
        "slots": [slot.to_dict() for slot in slots],
        "equipped_weapon": equipped_weapon.to_dict(),
        # ... hat, backpack
    }
```

**Security Considerations:**
- `request_move_item()` validates sender ID before processing
- Slot indices are clamped and validated against active count
- Empty slot checks prevent null pointer issues

### 5. Nickname Sanitization (`autoload/network.gd`)

Prevents injection attacks and display corruption:

```gdscript
func sanitize_nickname(nickname: String, fallback: String) -> String:
    # Strips control characters (<=31, 127) to prevent terminal/code injection
    # Normalizes whitespace (collapses multiple spaces into one)
    # Enforces MAX_NICK_LENGTH = 24 chars
```

**Why this matters:**
- Control characters can break console output or cause parsing errors
- Multiple spaces create inconsistent display widths
- Length limits prevent buffer overflow-style attacks in UI rendering

### 6. Pickup Mechanics (`player.gd`)

**Race Condition Prevention:**
```gdscript
const PICKUP_REQUEST_COOLDOWN_MSEC := 1000
var _last_server_pickup_request_msec := -PICKUP_REQUEST_COOLDOWN_MSEC

func request_pickup() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_server_pickup_request_msec < PICKUP_REQUEST_COOLDOWN_MSEC:
        return  # Prevents double-pickup exploits
```

**Flow:**
1. Player presses pickup key → client sends `request_pickup()` RPC
2. Server checks cooldown window (1 second)
3. Server validates animation timing window (1-2.5 seconds after pickup starts)
4. If valid, item is removed from world and added to inventory

## Known Limitations & Future Work

### 1. Unfinished: Starting Items (`player.gd` line 773)
```gdscript
# TODO: Implement starting items for new players.
func _add_starting_items():
    pass
```

**Recommended Implementation:**
```gdscript
@rpc("authority", "call_local")
func give_starter_pack() -> void:
    if not multiplayer.is_server(): return
    
    var player_inv = get_inventory()
    
    # Give starting weapon (pistol)
    var pistol_item = ItemDatabase.get_item("pistol")
    if pistol_item and player_inv:
        player_inv.add_item(pistol_item, 1)
        
    # Give basic ammo/consumables
    for _ in range(5):
        var ammo_item = ItemDatabase.get_item("ammo_small")
        if ammo_item and player_inv:
            player_inv.add_item(ammo_item, 10)
```

### 2. Missing Blaster Weapons Class
The `BlasterWeapons.IDS` array is referenced but the full class implementation appears to be in a separate file that wasn't found during review. This should contain weapon-specific RPCs for firing, reloading, and damage calculation.

**Expected Structure:**
```gdscript
class_name BlasterWeapons extends Node:
    @rpc("authority", "reliable")
    func fire_weapon(weapon_id: String) -> void:
        # Server validates and processes shot
        pass
    
    @rpc("any_peer", "call_local")
    func sync_damage_taken(damage: float, attacker_id: int) -> void:
        # Broadcast damage to all clients for visual feedback
        pass
```

### 3. No Lag Compensation
Currently uses simple authoritative server model without:
- Client-side prediction
- Server reconciliation
- Timestamp-based hit validation

**Impact:** May feel slightly "floaty" in fast-paced combat scenarios. For a template/demo, this is acceptable; for production use, consider adding shot timestamps and validating hits within a time window on the server.

### 4. Bot AI is Minimal (`bot.gd`)
Bots currently:
- Navigate randomly toward a target point
- Have no combat logic (shooting, health management)
- Don't interact with items or inventory

**Recommended Enhancement:** Add simple state machine for bots:
```gdscript
enum State { IDLE, SEEK_TARGET, ENGAGE, RETREAT }
var current_state := State.IDLE

func _physics_process(delta):
    if Shooter.phase == "results": return
    
    match current_state:
        State.SEEK_TARGET:
            # Find nearest living player
            target = find_nearest_enemy()
            navigate_to(target)
            
        State.ENGAGE:
            # Shoot at target when in range
            if is_in_range(target):
                fire_weapon()
```

## Security Checklist for Production Use

- [ ] Add shot timestamps to `fire_weapon()` RPCs and validate on server
- [ ] Implement client-side prediction with server reconciliation
- [ ] Add rate limiting to all client-to-server RPCs (currently only animations have tokens)
- [ ] Validate weapon IDs in `BlasterWeapons` before processing shots
- [ ] Consider adding encryption for WebSocket connections if hosting publicly
- [ ] Implement anti-cheat hooks: log unusual movement speeds, inventory manipulation attempts

## File Structure Quick Reference

```
scripts/
├── autoload/
│   ├── network.gd          # Multiplayer session management
│   └── item_database.gd     # Central item registry
├── player/
│   ├── player.gd           # Character controller + inventory sync
│   ├── spring_arm_offset.gd # Camera perspective control
│   └── 3d_godot_robot.gd   # Animation state machine
├── inventory/
│   ├── player_inventory.gd # Server-authoritative inventory logic
│   ├── item.gd             # Item data structure
│   └── inventory_slot.gd   # Individual slot management
├── items/
│   ├── item.gd             # Rigid body physics for pickupables
│   └── item_rigid_body_3d.gd
├── ui/
│   ├── main_menu_ui.gd     # Host/Join lobby UI
│   ├── inventory_ui.gd     # Inventory display and interaction
│   ├── player_list_ui.gd   # Online players list
│   └── multiplayer_chat_ui.gd
├── shooter/
│   ├── shooter.gd          # Game state, phases, scoring
│   ├── hud.gd              # In-game HUD overlay
│   ├── weapons.gd          # Weapon data (partial)
│   ├── arena.gd            # Level generation + navigation mesh
│   └── bot.gd              # Simple AI bots
```

## Quick Start Commands

**Host a game:**
```bash
godot4 --server 3d-multiplayer-template.tscn
# or with WebSocket:
godot4 --websocket 3d-multiplayer-template.tscn
```

**Join a game:**
```bash
godot4 --join "ws://127.0.0.1:8081" 3d-multiplayer-template.tscn
# or ENet UDP:
godot4 --join "127.0.0.1:8080" 3d-multiplayer-template.tscn
```

---
*Last updated: November 2026*
*Template version: 1.0*
