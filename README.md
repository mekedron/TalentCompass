# Talent Compass

A World of Warcraft: Forever addon that adds a build guide to the talent window.

- **Builds for your class** — three popular builds per class (leveling, damage, tank or healer), picked automatically for the character you log in with.
- **Next talent** — shows which talent to take next and highlights it on the talent tree with a pulsing gold glow and a "NEXT" marker. Other talents of the build get a soft frame with the target rank, finished ones a green check, and points spent outside the build a red marker.
- **Point order** — the full 51-point order from level 10 to 60, with progress.
- **How to play** — rotation / ability priority, stat priority, gear to look for and practical tips for each build, plus a short note on what changed for the class in Forever.
- **English and Russian** — follows the game language; can be switched in the panel. Talent names come from the game itself, so they always match your client.
- **Chat hint** — on level-up, prints which talent the build wants next.

## Installation

1. Download the repository (Code → Download ZIP) and unpack it.
2. Rename the folder to `TalentCompass` if needed and copy it to
   `World of Warcraft/_forever_/Interface/AddOns/`.
3. Restart the game or `/reload`.

The folder must contain `TalentCompass.toc` directly (not a nested folder).

## Usage

- Open the talent window (`N`). The Talent Compass panel docks to its right side; the **Builds** button next to the search box toggles it.
- Click a build card to make it active. The choice is saved per character.
- `/tc` — show or hide the panel (works without the talent window too).
- `/tc reset` — reset the floating panel position.
- `/tc dump` — store the class's live talent list (names, spell IDs, positions) in `TalentCompassDB.dump`; after `/reload` it is in `WTF/Account/<account>/SavedVariables/TalentCompass.lua`. Useful for checking guide data against the current game build.

## How it works

WoW Forever uses the modern trait system (`C_Traits`) with a Classic-style three-tree layout in `PlayerSpellsFrame.TalentsFrame`. The addon reads the active (or staged) talent config, matches guide talents to tree nodes by spell ID, then by English name, then by Russian name, and draws its markers on the Blizzard talent buttons without changing them.

## Guide data

Builds are static data in `Data/<CLASS>.lua`, generated from `guides/<CLASS>.json` with `tools/json2lua.py`, which also validates each build (exactly 51 points, maximum ranks, 5 points per tier gating). `tools/simulate.py` runs the addon's build logic offline against a mocked talent API.

Each build has:

| Field | Meaning |
|---|---|
| `id`, `role` | identifier and role (`LEVELING`, `DPS`, `TANK`, `HEAL`) |
| `name`, `summary` | `{ en = ..., ru = ... }` |
| `order` | `{ "Talent Name", ranks }` entries in the order points are spent, 51 in total |
| `rotation`, `gear`, `tips` | `{ en = { ... }, ru = { ... } }` lists |
| `stats` | `{ en = ..., ru = ... }` |

The data reflects WoW Forever 1.60.1 (build 71037) and comes from public guides and the Wowhead Forever talent calculator. Builds will be loaded dynamically from an external source later; the data format is designed so that only the source changes.

## License

MIT
