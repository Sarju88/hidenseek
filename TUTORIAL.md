# 🎮 Third-Person Enclosed Building Arena - Quick Start Guide

## ✅ What You Have Now

A **third-person hide & seek arena** with:
- Enclosed multi-room buildings (not open space)
- 3 floors connected by stairs/ladders
- Darker lighting for hiding gameplay
- Third-person camera orbiting around character
- WASD movement + Space jump

## 🎮 Controls

| Key | Action |
|-----|--------|
| **W / Up Arrow** | Move forward (toward where you're facing) |
| **S / Down Arrow** | Move backward |
| **A / Left Arrow** | Strafe left |
| **D / Right Arrow** | Strafe right |
| **Space / Up Arrow** | Jump |

## 🎯 Camera Controls (Third-Person Orbit)

- **Mouse** → Rotates camera orbit around player
- **Arrow Keys** → Fine-tune camera angle
- Character stays visible behind/beside you as you move through rooms

## 🏗️ Building Layout

```
Floor 3 (Rooftop/Living Rooms) - ~12m high
    ├── Stairs up from Floor 2
    └── 2-3 small enclosed rooms for hiding
    
Floor 2 (Bedrooms/Hallways) - ~8m high  
    ├── Ladder/Stairs to Floor 3
    ├── Corridors connecting multiple rooms
    └── 3-4 medium rooms

Floor 1 (Ground Floor/Lobby) - ~4m high
    ├── Main entrance area
    ├── Kitchen/Dining room style spaces
    └── Connects all upper floors via stairs
```

## 🌙 Lighting & Atmosphere

- **Cool moonlight** from directional light (0.9 energy, blue tint)
- **Window spotlights** create shadows and hiding spots
- **Darker room interiors** (~0.25 albedo colors for concealment)
- **SSao shadows + fog** add depth perception

## 🧪 Testing the Build

1. Run: `godot --path /home/arjun/3d-multiplayer-template`
2. Press F5 or click **Run** button
3. You'll spawn at center of ground floor lobby
4. Move with WASD, jump with Space
5. Mouse rotates camera around you in orbit

## 🔍 Key Features for Hide & Seek Gameplay

✅ **Enclosed rooms** - Walls prevent walking through floors  
✅ **Multiple levels** - Vertical hiding opportunities (rooftops)  
✅ **Stairs + ladders** - Guaranteed vertical access  
✅ **Corridors connecting rooms** - Navigation without open spaces  
✅ **Dark interiors** - Visual concealment for hiders  

## 📊 Building Stats

- **Total floors:** 3
- **Ground floor area:** ~60m × 60m (main lobby + rooms)
- **Upper floors:** Smaller, more intimate spaces (~40-50m per level)
- **Room variety:** Random sizes (6-12m), colors, and layouts each session

## 🎨 Next Steps (Optional Enhancements)

Want to integrate Kenney assets? Here's where they'd fit:

```gdscript
# Replace procedural boxes with Kenney models in building_generator.gd:
func create_room_walls(parent, width, height, rng):
    # Instead of BoxMesh walls:
    var door_asset = preload("res://kenney/doorway.tscn")
    var mesh = door_asset.instantiate() as MeshInstance3D
    parent.add_child(mesh)
    
# Add furniture/cover in rooms:
func create_room(parent_node, offset, rng):
    # Add Kenney furniture for hiding spots:
    var bed_asset = preload("res://kenney/bed.tscn")
    var bed = bed_asset.instantiate() as MeshInstance3D
    parent_node.add_child(bed)
```

---

**Ready to play!** Run the project and test movement through the enclosed building. 🚀
