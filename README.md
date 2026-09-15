# ☀️ DayBreak Alt Control ☀️
### *The Ultimate Multi-Instance Bot Orchestration & Meme Fleet Engine for Roblox*

[![Version](https://img.shields.io/badge/Version-3.0_Nocturnal-gold?style=for-the-badge&logo=roblox&logoColor=white)](https://github.com/DayyBreak69/DayBreak-Alt-Control)
[![Commands](https://img.shields.io/badge/Commands-140%2B-red?style=for-the-badge&logo=terminal&logoColor=white)](https://github.com/DayyBreak69/DayBreak-Alt-Control)
[![Status](https://img.shields.io/badge/Status-Active%20%26%20Undetected-brightgreen?style=for-the-badge)](https://github.com/DayyBreak69/DayBreak-Alt-Control)
[![Theme](https://img.shields.io/badge/Theme-Nocturnal%20Starlight-blueviolet?style=for-the-badge)](https://github.com/DayyBreak69/DayBreak-Alt-Control)

---

## 🌟 What's New in v3.0

- 🌌 **Nocturnal Starlight / Monochrome Glow UI Theme**: Deep Obsidian Noir (`#0a0a0c`), sleek slate cards (`#121216`), glowing starlight borders (`#dce1f0`), and radiant white typography.
- ⭐ **Embedded DayBreak Star Keychain**: High-resolution 128x128 star emblem embedded directly in Base64 (zero external web requests, no Roblox decal moderation risks).
- 📊 **Live Bot Fleet & RAM Dashboard**: Dedicated tab in the GUI showing each connected bot's live RAM consumption in MB (`gcinfo()`), active status, and one-click `[Purge GC]` button.
- ⚡ **Ultra-Low RAM Mode (`!lowram` / `!unlowram`)**: Disables shadows, global lighting fog, and textures for peak FPS on 10+ multi-instances.
- 🎭 **Viral Meme & Troll Squad**:
  - `!bodyguard <target>` — Elite security detail formation with responsive target look vectors.
  - `!ritual <target>` — Orbiting cult chanting circle with randomized incantations.
  - `!paparazzi <target>` — Flashing camera mob swarming the target with dynamic paparazzi dialogue.
  - `!coffin <target>` — Synchronized pallbearer dance formation bobbing in unison.
  - `!conga <target>` — Fluid snake conga dance line.
  - `!stare <target>` — Surrounds target with an eerie, unblinking void gaze.
  - `!tornado <target>` — Multi-tier high-velocity rotating aerial vortex.
  - `!creeper <target>` / `!uncreeper` — Red Light Green Light stealth creeping (only moves when target looks away).
- 🕺 **Enhanced Multi-Method Emote Engine**: Automatic fallback across `Humanoid:PlayEmote`, `Animator:LoadAnimation`, and `Animate.playEmote` with staggered delays preventing Roblox CDN rate limits.
---

## 🚀 Quick Execution Loader

```lua
-- [[ DAYBREAK ALT CONTROL v3.0 ]] --
getgenv().Settings = {
    prefix      = "!",                  -- Command prefix
    mainAccount = "DayBreak",          -- Controller Roblox username
    fpsCap      = 10,                   -- Background bot FPS cap
    altAccounts = {
        ["YourAlt1"] = true,
        ["YourAlt2"] = true,
        ["YourAlt3"] = true,
    },
    announceOnLoad = true,
    lowRamMode     = false,
}

loadstring(game:HttpGet("https://raw.githubusercontent.com/DayyBreak69/DayBreak-Alt-Control/main/DayBreakAltControl.lua"))()
```

---

## 📋 Comprehensive Command Reference (140+ Commands)

<details>
<summary><b>🌟 Click to Expand Full Command List</b></summary>

### 🏃 Movement & Positioning
| Command | Arguments | Description |
|---|---|---|
| `!goto` | `[bot] <target>` | Teleports bots directly to target player |
| `!follow` | `[bot] <target>` | Smoothly follows target player |
| `!walkto` | `[bot] <target>` | Pathfinds / walks to target player |
| `!bring` | `[bot] <target>` | Summons bots to your current position |
| `!wonder` | None | Randomly wanders around |
| `!stalk` | `[bot] <target>` | Silently stalks target from behind |
| `!worm` | `[bot] <target>` | Forms a moving snake chain |
| `!swarm` | `[bot] [speed] [radius] <target>` | Chaotic high-speed swarming |
| `!carpet` | `[bot] <target>` | Grid floor / bridge pattern |
| `!tp` | `[bot] <X Y Z / target>` | Teleports to exact coordinates or player |
| `!scatter`| `[bot] [range]` | Randomly scatters bots |

### 🎭 Meme & Troll Squad
| Command | Arguments | Description |
|---|---|---|
| `!bodyguard` | `<target>` | Surrounds and protects target in security formation |
| `!ritual` | `<target>` | Dark cult ritual circle with incantation chants |
| `!paparazzi` | `<target>` | Flashing camera mob swarming the target |
| `!coffin` | `<target>` | Pallbearer coffin dance formation |
| `!conga` | `<target>` | Follows target in a swaying conga dance line |
| `!stare` | `<target>` | Surrounds target with a synchronized void stare |
| `!tornado` | `<target>` | High-speed rotating vertical cyclone |
| `!creeper` | `<target>` | Red Light Green Light stealth creeping |
| `!uncreeper` | None | Stops stealth creeping |

### 📐 Formations
| Command | Arguments | Description |
|---|---|---|
| `!circle` | `[radius] <target>` | Snaps bots into a circular perimeter |
| `!loopcircle` | `[radius] <target>` | Continuously updating active circle |
| `!arrow` | `<target>` | V-formation arrow behind target |
| `!box` | `<target>` | Enclosing geometric square box |
| `!stackon` | `<target>` | Vertical bot tower |
| `!rline` / `!lline` | `<target>` | Right / Left flank line |
| `!fline` / `!bline` | `<target>` | Front / Rear formation line |

### 🌌 Orbits & Spirals
| Command | Arguments | Description |
|---|---|---|
| `!orbit` | `[spd] [r] <target>` | Flat circular planar orbit |
| `!orbit1` - `!orbit10` | `[spd] [r] <target>` | Double helix, atomic ring, galaxy, vertical vortex, figure-eight, pulsar orbits |
| `!spiral1` - `!spiral10` | `[spd] [r] <target>` | Upward ascent, cone vortex, ladder, funnel tornado, golden ratio spirals |

### 🛡️ Shields & Defense
| Command | Arguments | Description |
|---|---|---|
| `!shield1` - `!shield5` | `<target>` | Protective wall, defensive arc, V-guard, reinforced wall, full enclosure |

### 💥 Action & Physics
| Command | Arguments | Description |
|---|---|---|
| `!jump` / `!sit` / `!rest` | None | Forces bot jump, sit, or lay flat |
| `!spin` | `[speed]` | High-speed character spin |
| `!firework` | None | Rockets bots into the stratosphere |
| `!nuke` | None | Explosive radial scatter fling |
| `!vfling` | `[bot] <target>` | High-velocity vehicle/physics fling attack |
| `!kill` | None | Safely resets bot characters |

### 🕺 Emotes & Sync
| Command | Arguments | Description |
|---|---|---|
| `!sync` | `<emote_name>` | Synchronizes any catalog emote across all bots |
| `!emote` | `<emote_name>` | Plays emote with multi-method fallback |
| `!dance` | `[1-3]` | Group synchronized dance |
| `!unemote` | None | Cancels all active emotes immediately |

### ⚡ Performance & RAM
| Command | Arguments | Description |
|---|---|---|
| `!ram` / `!memory` | None | Prints individual bot RAM consumption in MB |
| `!lowram` | None | Activates ultra-low RAM mode (strips meshes/shadows) |
| `!unlowram` | None | Restores full 3D rendering |
| `!cleanram` / `!flush` | None | Forces dual-pass Lua garbage collection purge |
| `!ping` / `!uptime` / `!altcount` | None | Network, uptime, and bot count diagnostics |

### 🛠️ System & Control
| Command | Arguments | Description |
|---|---|---|
| `!cmds` | None | Opens / closes the in-game Nocturnal Starlight GUI |
| `!whitelist` / `!blacklist` | `<target>` | Manages bot access permissions |
| `!noclip` / `!clip` | None | Toggles ghost collision bypass |
| `!invisible` / `!visible` | None | Toggles character visibility |
| `!freeze` / `!unfreeze` | None | Anchors / unanchors bots |
| `!stop` | None | Halts all running commands and routines |
| `!rejoin` | None | Safely reconnects bots to current server |
| `!quit` | None | Safely terminates and disconnects alt sessions |

</details>

## 🤝 Community & Support

- **Discord**: [Join DayBreak Community](https://discord.gg/ws5Zb2EzYA)
- **GitHub**: [DayBreak Alt Control Repository](https://github.com/DayyBreak69/DayBreak-Alt-Control)

<div align="center">
  <sub>Created with ❤️ by DayBreak</sub>
</div>
