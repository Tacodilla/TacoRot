TacoRot – DPS Rotation Helper (Wrath 3.3.5)

TacoRot is a lightweight rotation helper built for new players, accessibility, and learning. It shows a 3-icon queue (now + next + later) so you can practice timing without reading guides mid-fight. The pack favors clear visuals, low configuration, and sensible defaults.

Who this is for

Players learning a class/spec for the first time

Anyone who benefits from simple visual prompts instead of dense UIs

Leveling characters (the engines include low-level padding so the queue never goes blank while you’re still unlocking spells)

Game & classes

Client: Wrath of the Lich King 3.3.5

Focus: DPS only (no healing rotations)

Classes supported: Hunter, Rogue, Warlock, Druid, Warrior, Paladin, Mage, Priest, Shaman

Specs: DPS specs only (e.g., Ret, Shadow, Ele/Enh, Arms/Fury, Arcane/Fire/Frost). Tanks/healers are not prioritized.

Install

Download or clone this repository.

Copy the TacoRot folder into Interface\AddOns\ (keep the folder name).

Launch the game and /reload.

Load order note: each class has an *_ids.lua file and an engine_*.lua file. The IDs file must load before the engine.

Quick start

Target a dummy or mob.

You’ll see three icons: main (left), next, later.

Cast what the main icon shows. The next two help you prepare GCDs and movement.

Use the Options (below) to show/hide spells or change the “padding” window for low levels.

Slash commands
/tr                -> open TacoRot options
/tr on             -> enable the engine for your current class
/tr off            -> disable the engine for your current class
/tr aoe on         -> hint engines to use AoE priorities (where implemented)
/tr aoe off        -> return to single-target priorities


If /tr is unavailable in your build, open via Esc → Interface → AddOns → TacoRot.

Options menu

Open /tr or go to Interface → AddOns → TacoRot. You’ll see:

Class → Spells

A toggle list of abilities the engine can propose.

Uncheck a spell to prevent it from appearing in the queue (useful while leveling or if you prefer a variant).

Class → Padding

Enable low-level padding: keeps the queue alive with “soon-ready” abilities and safe fallbacks while you’re leveling.

Pad window (seconds): the look-ahead time used by the queue.

Default: 1.60s (about a GCD at low haste).

Set to 0.00 for strict “ready now” behavior; increase slightly if you want earlier notice.

Tip: Padding affects only the suggestion timing, not your actual cooldowns or casting.

Accessibility choices

Three big, readable icons instead of dense text or complicated overlays

Low-level padding so the UI doesn’t degrade while spells unlock

Minimal chat output; no sound spam; low CPU footprint

Troubleshooting

Three red question marks:

Usually indicates the class ID table didn’t load before the engine. Ensure *_ids.lua loads before engine_*.lua in the addon's XML.

/reload after enabling a class.

No icons at level 1–20:

Enable Padding and keep the default 1.60s window.

AoE not changing behavior:

Some specs have AoE hints implemented; others are single-target only. Toggle with /tr aoe on|off.

Contributing

Pull requests that improve readability, new-player clarity, or leveling coverage are welcome. Keep changes surgical and consistent with the existing engine/IDs structure (no healing specs).
