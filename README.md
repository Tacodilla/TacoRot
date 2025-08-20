# TacoRot - DPS Rotation Helper

A lightweight rotation helper addon for World of Warcraft 3.3.5a (Wrath of the Lich King). Shows a simple 3-icon queue to help you learn and execute optimal DPS rotations.

## ✨ Features

- **Simple 3-Icon Display**: Shows current + next 2 spells in your rotation
- **Multi-Class Support**: Works with all DPS specs across 9 classes
- **Smart Recommendations**: Adapts to your level, spec, and combat situation
- **Drag & Drop Interface**: Movable, scalable, and customizable
- **Low-Level Friendly**: Includes "padding" so the queue never goes empty while leveling
- **Zero Configuration**: Works out of the box with sensible defaults

## 🎮 Supported Classes

| Class | Specs | Notes |
|-------|-------|-------|
| **Hunter** | Beast Mastery, Marksmanship, Survival | Pet management included |
| **Rogue** | Assassination, Combat, Subtlety | Combo point aware |
| **Warlock** | Affliction, Demonology, Destruction | Pet summoning, DoT tracking |
| **Druid** | Balance, Feral (Cat) | Form-specific rotations |
| **Warrior** | Arms, Fury | Rage management |
| **Paladin** | Retribution | Seal/Judgement tracking |
| **Mage** | Arcane, Fire, Frost | Proc-aware suggestions |
| **Priest** | Shadow | DoT priority system |
| **Shaman** | Elemental, Enhancement | Melee/caster hybrid support |

## 📦 Installation

1. Download the latest release
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Ensure the folder is named `TacoRot`
4. Restart WoW or `/reload`

## 🚀 Quick Start

1. Target a training dummy or enemy
2. Three icons will appear showing your rotation
3. Cast the **left icon** (main suggestion)
4. The **middle** and **right** icons help you prepare for what's next

That's it! The addon automatically detects your class and spec.

## ⚙️ Commands

| Command | Description |
|---------|-------------|
| `/tr` | Open configuration menu |
| `/tr unlock` | Unlock UI for repositioning |
| `/tr lock` | Lock UI in place |
| `/trui scale 1.2` | Change UI scale |
| `/trui reset` | Reset UI position |

## 🎯 Who This Is For

- **New Players** learning their class rotation
- **Leveling Characters** who want guidance as spells unlock
- **Players Returning** to WoW who need rotation refreshers
- **Anyone** who prefers visual cues over memorizing complex rotations

## 🔧 Configuration

Access the full configuration menu with `/tr` or through:
**ESC → Interface → AddOns → TacoRot**

### Key Options:
- **Spell Toggles**: Enable/disable specific abilities
- **Padding Settings**: Adjust the "look-ahead" window for smoother rotations
- **Buff Management**: Configure out-of-combat buff suggestions
- **Pet Options**: Control pet summoning and maintenance (Hunter/Warlock)

## 🛠️ Technical Details

- **Client**: WoW 3.3.5a (Wrath of the Lich King)
- **Framework**: Ace3
- **Performance**: Lightweight with minimal CPU usage
- **Compatibility**: Works with most other addons

## 🤝 Contributing

Contributions welcome! Please:
- Keep changes focused on rotation accuracy and new-player friendliness
- Test with multiple classes/specs
- Follow the existing code style

## 📄 License

MIT License - feel free to modify and redistribute.

## 💡 Tips

- **Enable Padding** while leveling to keep suggestions flowing
- **Unlock the UI** to reposition icons where they're comfortable
- **Check class-specific options** for buff and pet management settings
- **Use training dummies** to practice rotations without pressure

---

*Built for the 3.3.5a community with ❤️*
