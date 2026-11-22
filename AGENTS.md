# AGENTS.md

Guidance for agents working on Talent Compass, a World of Warcraft: Forever addon.

## Target client

- WoW Forever (product `wowf`, folder `_forever_`), client 1.60.1, `## Interface: 16001`.
- Blizzard UI source for this client: branch `forever` of https://github.com/Gethe/wow-ui-source. Forever-specific overrides live in `Camelot/` subfolders and TOC lines tagged `[AllowLoadGameType camelot]`.
- The talent window is the modern trait UI, not the Classic `PlayerTalentFrame`: `PlayerSpellsFrame.TalentsFrame` (addon `Blizzard_PlayerSpells`, load on demand), data via `C_Traits` / `C_ClassTalents`. Hook it with `EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", ...)`.
- Local install path: `~/Battle.net/Games/World of Warcraft/_forever_/Interface/AddOns/TalentCompass` (copy `TalentCompass.toc`, `*.lua`, `Data/*.lua`; not `guides/` or `tools/`).

## Layout

| Path | Purpose |
|---|---|
| `Locales.lua` | UI strings (`en`, `ru`), `ns.L`, `ns.T` for `{ en, ru }` values |
| `Core.lua` | saved variables, tree scan (`ns.ScanTree`), build progress (`ns.ComputePlan`), build matching, events, slash commands, fonts |
| `Highlight.lua` | markers drawn on talent buttons |
| `UI.lua` | build panel docked to the talent window |
| `guides/<CLASS>.json` | source of guide data |
| `Data/<CLASS>.lua` | generated from `guides/` — never edit by hand |
| `tools/json2lua.py` | generates `Data/` and validates builds (51 points, max ranks, 5 points per tier) |
| `tools/simulate.py` | runs Core logic offline against a mocked `C_Traits` (needs `pip install lupa`) |

## Fonts and glyphs

- Blizzard font objects (`GameFontNormal`, …) are font families that choose the Latin or Cyrillic font from the start of a string. Mixed strings such as "Protection, 16 ур." then show boxes. All addon text must go through `ns.CreateText(parent, layer, fontObjectName)` or `ns.Font(name)`, which use the Cyrillic Friz Quadrata (`Fonts\FRIZQT___CYR.TTF`, covers Latin and Cyrillic). Never call `CreateFontString` with a Blizzard font object directly.
- Glyphs confirmed to render: Latin, Cyrillic, `«` `»`, en dash `–`, em dash `—`.
- Glyphs that render as boxes or are unverified — do not use: middle dot `·`, arrows `→` `←`, bullet `•`, multiplication sign `×`. Use commas, `–` or ASCII instead. `json2lua.py` replaces these in guide texts.
- When adding a new symbol, check it in game before relying on it.

## Workflow

1. Edit `guides/*.json`, run `python3 tools/json2lua.py guides/*.json` (must print OK for every class).
2. Run `tools/simulate.py guides/<CLASS>.json <points>` for touched classes.
3. Syntax-check Lua (e.g. `load()` via lupa) before installing.
4. Copy the runtime files to the local install path; the user tests with `/reload`.

## Conventions

- Documentation is English; in-game texts exist in English and Russian.
- Talents in guides are keyed by exact English in-game name, with `spell` and `ru` as fallbacks for matching.
- Commits: the user is the only author — no `Co-Authored-By` or other attribution trailers.
