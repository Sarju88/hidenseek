# 🏢 Office Building Hide & Seek Arena - Complete Guide

## ✅ What You Have Now

A **fully enclosed, multi-level office building** with:
- Proper lobby spawn point (not open space)
- Interconnected offices and corridors for tactical gameplay
- 3 floors connected by stairs and ladders
- Third-person camera orbiting around character
- Office-appropriate lighting with shadows for hiding
- Random furniture as additional cover/hiding spots

## 🎮 Controls

| Key | Action |
|-----|--------|
| **W / Up Arrow** | Move forward (through space) |
| **S / Down Arrow** | Move backward |
| **A / Left Arrow** | Strafe left |
| **D / Right Arrow** | Strafe right |
| **Space / Up Arrow** | Jump |

## 🎯 Camera Controls (Third-Person Orbit)

- **Mouse** → Rotates camera orbit around player character
- **Arrow Keys** → Fine-tune camera angle  
- Character stays visible behind/beside you as you navigate rooms and corridors

## 🏗️ Building Layout

```
Floor 3 (~12m high):  Living/Office spaces with desks, bookshelves
    ├── Stairs up from Floor 2 + Ladder access
        
Floor 2 (~8m high):   Corridors connecting multiple offices  
    └── Accessible via stairs/ladders from ground
        
Floor 1 (Ground - ~4m high): Main lobby and reception area
    └── Central hub with all upper floors accessible

Each floor features:
- Fully enclosed rooms (walls on all sides)
- Corridors connecting spaces
- Desks, chairs, bookshelves as cover objects
- Window lighting creating shadows for hiding gameplay
```

## 🌙 Lighting & Atmosphere

- **Daylight through windows** - Bright but creates directional shadows
- **Office-appropriate colors** - Neutral grays, browns, muted blues
- **SSao shadows + fog** - Adds depth and makes dark corners feel real
- **Darker room interiors** (~0.15-0.25 albedo) for concealment

## 🧪 Testing the Build

```bash
cd /home/arjun/3d-multiplayer-template
godot --path .
# Press F5 or click Run button
```

You'll spawn at the **ground floor lobby** and see:
- A reception-style entrance area with desks/chairs
- Corridors leading to enclosed offices on all sides
- Upper floors accessible via stairs (right side) and ladders (left side)
- Camera orbiting behind you in third-person view

## 🔍 Key Features for Hide & Seek Gameplay

✅ **Fully enclosed rooms** - Walls prevent walking through floors  
✅ **Multiple levels** - Vertical hiding opportunities (rooftops, upper offices)  
✅ **Stairs + ladders** - Guaranteed vertical access between floors  
✅ **Corridors connecting spaces** - Navigation without open voids  
✅ **Office furniture as cover** - Desks, chairs, bookshelves for concealment  
✅ **Shadow-rich lighting** - Window light creates hiding spots naturally  

## 📊 Building Stats

- **Total floors:** 3
- **Ground floor area:** ~20m × 20m lobby + interconnected offices
- **Upper floors:** Smaller office spaces (~14-20m per level)
- **Room variety:** Random sizes, colors, and layouts each session
- **Cover objects:** Desks, chairs, bookshelves, filing cabinets, plants

## 🎨 Office Theme Details

### Colors & Materials:
- Floor: Light gray/beige (lobby), darker slate gray (offices)
- Walls: Dark brown/gray for enclosure and shadows
- Furniture: Wood tones (desks, shelves), metal grays (cabinets)
- Lighting: Cool daylight with warm window spotlights

### Room Types:
1. **Lobby** - Large open space with reception desk, waiting chairs
2. **Offices** - Enclosed private spaces with desks and bookshelves
3. **Corridors** - Narrow passages connecting rooms (great for flanking)

## 🎯 Gameplay Tips

### For Hiders:
- Hide behind office furniture (desks are perfect cover)
- Use upper floors for elevation advantage
- Corridors provide stealth movement between offices
- Darker corners near windows create natural shadows

### For Seekers:
- Window light reveals silhouettes in darker rooms
- Stairs/ladders provide vantage points over lower areas
- Listen for footsteps in corridors (audio detection system ready)
- Radar pulse works best when positioned at stair landings

## 📋 Quick Reference

| Aspect | Value |
|--------|-------|
| Player spawn location | Ground floor lobby center |
| Camera type | Third-person orbit |
| Movement style | WASD moves character through 3D space |
| Floor count | 3 (Ground + 2 upper) |
| Vertical access | Stairs (70%) and ladders (30%) |
| Room enclosure | Fully enclosed on all sides |

## 🔧 Technical Notes

### Generation System:
```gdscript
# Uses time-based seed for unique layouts each session
var rng_seed = Time.get_ticks_msec()
building_generator.seed = rng_seed
```

### Enclosure Guarantee:
- All rooms have walls on 4 sides forming a closed box
- Doors create openings to corridors (not gaps in the floor!)
- No "floating" geometry - everything grounded properly

---

**Ready to play!** Run the project and experience a proper office building hide & seek arena. 🏢🎮
