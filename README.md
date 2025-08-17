TacoRot (3.3.5)

TacoRot is a lightweight, ConROC-style rotation helper for WoW 3.3.5 (Epoch).
It embeds Ace3 and shows a main suggestion icon plus two “next” predictions, with optional detectors (Defense, Interrupt, Purge).

Features

Predictive next-3 queue (stable while you’re mid-cast).

DoT clipping: refresh Immolate/Corruption only when remaining time ≤ cast time × 0.30.

Only suggests spells you actually know (rank-aware resolver).

Detectors:

Defense (Shadow Ward icon when low HP).

Interrupt (Felhunter Spell Lock).

Purge/Devour (Felhunter Devour Magic).

AoE mode (optional toggle): Seed → Rain of Fire → DoTs → filler.

Draggable UI, anchor persists across reloads.

Profiles via AceDBOptions.

How to use (in game)

Open options: /tr

Toggle Unlock to drag the main icon; the others follow it.

Adjust sizes, next-icon scale, and detector toggles.

Move the UI:

/tr → Unlock ON → drag the main icon. Position saves automatically.

You can bind “TacoRot Unlock” in Key Bindings.

AoE mode:

Hold ALT for temporary AoE suggestions, or

/tr aoe to toggle AoE mode on/off (persists).

Profiles: Options → Profiles (copy/set per spec or character).

Rotation logic (Warlock)

Single-target (default):

Immolate (clip at 30%)

Corruption (clip at 30%)

Filler: Shadow Bolt (or Searing Pain if you’ve customized)

AoE (when enabled): Seed → Rain of Fire → Immolate → Corruption → filler.

Prediction: While casting Immolate or Corruption, the addon treats that DoT as “virtually up” so the next two suggestions stay stable (e.g., Immolate → Corruption → Shadow Bolt).

Commands

/tr – open options.

/tr aoe – toggle AoE mode (ALT is always a momentary AoE override).

(Optional, if you added the patch) /tr debughud – show/hide a small HUD with queue & DoT timers.

Files overview

TacoRot.toc – addon manifest (Interface 30300).

embeds.xml – loads Ace3 in the correct order (nested AceConfig-3.0.xml).

core.lua – options, profiles, chat commands, lifecycle.

ui.lua – creates the frames (draggable, persisted anchor).

engine_warlock.lua – rotation engine (prediction + DoT clipping + AoE + detectors).

warlock_ids.lua – spell ID tables with rank lists; picks highest known rank.

options.lua – builds the Warlock options panel from resolved spells.

libs\… – embedded Ace3 (LibStub, CallbackHandler, AceAddon, AceEvent, AceConsole, AceTimer, AceHook, AceDB, AceDBOptions, AceGUI, AceConfig).

Customization

Change priorities: edit BuildSingleTarget / BuildAoE in engine_warlock.lua.

Adjust DoT clip: top of engine_warlock.lua, set CLIP (e.g., 0.25 tighter, 0.40 looser).

Add spells/ranks: extend TR_IDS.Rank in warlock_ids.lua. The resolver will pick your highest known rank automatically.

Detectors: tweak the conditions in UpdateDetectors() (e.g., require pet present, combat only, etc).

Troubleshooting

Addon loads but options/UI don’t appear

Make sure you extracted to Interface\AddOns\TacoRot\… (not an extra nested folder).

Use /tr. If nothing opens, check AddOns menu to confirm TacoRot is enabled for your character.

“Cannot find a library instance of AceConfigRegistry-3.0”

Your embeds.xml must include:
…AceGUI-3.0.xml then AceConfig-3.0\AceConfig-3.0.xml (that XML loads the Registry first).
Don’t load AceConfig-3.0.lua directly before the Registry.

“attempt to call global ‘LibStub’ (a nil value)”

LibStub.lua didn’t load. Confirm embeds.xml has libs\LibStub\LibStub.lua first.

Can’t move the icons

/tr → Unlock ON, then drag the main icon. Position persists on drop.

Next-2 boxes seem off while I’m casting

That’s usually GCD/cast timing. The engine treats your current cast as “virtually applied” to keep predictions stable. If you still see flicker, nudge GCD_CUTOFF in engine_warlock.lua to 1.3–1.6.

Credits

Inspired by ConROC’s organization (options and class modules).

Built on Ace3 (embedded).
