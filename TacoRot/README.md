<img width="197" height="84" alt="image" src="https://github.com/user-attachments/assets/407c86b2-439e-49d2-839f-cd485d1fe56a" />

TacoRot Rotation Helper for Epoch (WotLK 3.3.5)

TacoRot is a lightweight DPS rotation helper designed for Project Epoch’s Wrath of the Lich King 3.3.5 client. When installed, the addon displays a three‑icon queue—now, next, and later—to help you time abilities without alt‑tabbing to guides. It favours clear visuals, sensible defaults and a small footprint, making it ideal for newer players and anyone looking for a clean, distraction‑free rotation helper.

Features

Three‑icon queue: See your current cast suggestion plus two upcoming abilities. The secondary icons help you plan GCDs or movement.

Auto‑detects your class and spec: Engines are included for Rogue, Warlock, Hunter, Druid, Warrior, Paladin, Mage, Priest and Shaman DPS specs. Each engine resolves spell ranks and updates as you level.

Padding and accessibility options: Optional low‑level padding keeps the queue alive while you’re still unlocking spells. You can customise icon size, whether secondary icons are shown, and enable a GCD sweep on the main icon.

Ace3 integration: TacoRot uses Ace3 libraries for its database, configuration and timers. It integrates with the standard Interface Options panel for easy configuration.

Installation

Download or clone this repository.

Copy the entire TacoRot folder into your Interface\AddOns\ directory. Keep the folder name unchanged—the client uses this folder name to register the addon.

Launch the game and type /reload in chat to reload your UI.

Note: Each class module has an ids.lua file and an engine.lua file. The addon’s TOC/XML files ensure the IDs file loads before the engine
GitHub
. If you modify the folder structure, make sure these paths remain correct or the class engines won’t initialise properly
github.com
.

Slash Commands

The addon registers two slash commands, /tacorot and /tr, which both accept the same sub‑commands:

Command	Action
/tr or /tacorot	Opens the TacoRot configuration panel in the Interface Options.
/tr unlock	Toggles whether the icon frames are locked. Unlocking allows you to drag the frames.
/tr aoe	Toggles AoE mode. When enabled the engines hint AoE priorities (where implemented).
/tr config	Shortcut to reopen the configuration panel.

Commands are not case‑sensitive. When no argument is supplied, TacoRot simply opens its options panel.

Using the Addon

Target a dummy or mob to start receiving rotation suggestions. The main icon shows what to cast now; the next two icons help you prepare upcoming abilities.

Move and resize the UI: Use /tr unlock to unlock the frames, then drag them to your desired position. The default sizes are 52 px for the main icon and smaller sizes for the secondary icons, but you can adjust these under Main Icon Size and Next Icon Scale in the options.

Configure spells and padding: Open /tr and navigate to Class → Spells to toggle individual abilities on or off. The Padding section lets you enable low‑level padding and adjust the look‑ahead window (default 1.60 s). Enabling padding prevents the queue from going blank when you’re still unlocking spells.

AoE mode: Toggle AoE mode with /tr aoe. Some class engines implement AoE priorities; others are single‑target only.

Troubleshooting

Three red question marks: This usually indicates the class ID table didn’t load before the engine. Make sure the ids.lua file is listed before the engine.lua file in the XML manifest
github.com
.

No icons at very low levels: Enable padding and keep the default 1.60 s window so the addon can suggest soon‑available abilities.

Missing Ace libraries: The addon uses several Ace3 libraries defined in embeds.xml
github.com
. If you restructure or nest the libs folder, update the paths in the embeds.xml so the WoW client can locate the libraries.

Contributing

Pull requests that improve readability, new‑player clarity or add additional DPS specs are welcome. Please keep changes surgical and consistent with the existing engine/IDs structure (healing and tanking engines are out of scope). Always ensure ids.lua loads before engine.lua and test your changes on the 3.3.5 Epoch client before submitting.
