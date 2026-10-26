# PLAN: M2, the core twist, playable (proof of concept)

Source of truth: the design doc "Cross-Cliff Co-op Defense: Game Plan & Build Prompt".
M0 and M1 are done. Since M1, two requests from Logan: a much deeper canyon (now 60 m)
and a pause menu (Controls with remapping, Graphics, Audio, Social).

**Done when:** two players survive (or lose) 5 waves, and in a playtest both say they had to rely on the other's turrets.

**Status:** built and running. 18/18 unit tests pass; headless and windowed runs show no script errors; two-instance network run replicates bugs, turrets and the kill feed. Soak tests: with 2 starting Gatlings and reinvesting, turrets alone hold the far cliffs for several waves but breachers slip through and will flatten a Homestead if no player shoots them; with no turrets, a Homestead falls in wave 1. Balance (Gatling 3.5 dmg at 65% hit, bugs climb 1.5x doc speed for the 60 m cliff, +12% bug HP per wave) still needs the two-person playtest.

| # | Task | Files | How it's verified | Status |
|---|------|-------|-------------------|--------|
| 0a | Deeper canyon (60 m), all heights derived from `CLIFF_HEIGHT` | `data/world_layout.gd`, `gen/cliff_builder.gd` | Screenshots from lip and floor | Done |
| 0b | Pause menu + Settings (saved to `user://settings.cfg`): remapping, brightness, FPS cap, V-Sync, fullscreen, FOV, shadows, MSAA, render scale, volumes, Social invite/join | `autoload/Settings.gd`, `scenes/ui/pause_menu.gd`, `*_tab.gd`, `ui_style.gd` | Esc in game; Settings on title screen; remap persists after restart | Done |
| 1 | Data: BugDef, TurretDef, WaveConfig + .tres files, `Defs` registry | `data/` | Unit tests load them | Done |
| 2 | Cross-defense rule in one place + unit tests | `components/Targeting.gd`, `tests/test_targeting.gd` | `godot --headless -s res://tests/run_tests.gd` | Done |
| 3 | Economy (ledger + synced autoload) + tests | `components/economy_ledger.gd`, `autoload/Economy.gd`, `tests/test_economy.gd` | Unit tests | Done |
| 4 | Wave budget, split, pulses (planner + director) + tests | `components/wave_planner.gd`, `autoload/WaveDirector.gd`, `tests/test_wave_budget.gd` | Unit tests; waves end when bugs die | Done |
| 5 | Bugs: procedural bodies (mite, spider, beetle, scorpion), IK legs, lane climbing, leaps, lane switches, cresting, breachers, spitter acid, armour plate, weak spots | `gen/bug_builder.gd`, `gen/leg_rig.gd`, `scenes/bugs/`, `components/LaneClimber.gd`, `Breacher.gd`, `Health.gd`, `Hitbox.gd`, `WeakSpot.gd` | F8 spawns; screenshots of bugs on the face | Done |
| 6 | Turrets: Gatling Post, Buffalo Rifle Nest; pitch limit, range, line of sight, aim sync, tracers | `gen/turret_builder.gd`, `scenes/turrets/turret.gd` | `--autobuild` soak: turrets only shoot the far cliff | Done |
| 7 | Build mode (B, 1/2, ghost, click, X demolish), repair (hold E), salvage piles | `scenes/player/build_mode.gd`, `scenes/structures/` | Manual | Done |
| 8 | Homestead HP, win at wave 10, lose if either falls; player health, downed 15 s | `autoload/GameState.gd`, `scenes/structures/homestead.gd`, `scenes/player/player_vitals.gd` | Soak test | Done |
| 9 | HUD: resources, both Homestead bars, kill feed ("X saved Y"), lane report, prompts, game over | `scenes/ui/hud_status.gd`, `hud_feed.gd` | Visual | Done |
| 10 | Generated SFX (19 sounds) + Audio autoload with 3 buses | `tools/audio/make_sfx.py`, `audio/sfx/`, `autoload/Audio.gd` | Generated OK; listen in game | Done |
| 11 | Debug: F6 skip, F7 scrap, F8 spawn bug, F9 god mode, F10 lanes (with `--debug`); solo mode = build on both cliffs | `scenes/debug_tools.gd` | Manual | Done |

## Tests
```
godot --headless --path . -s res://tests/run_tests.gd
```
A tiny built-in runner (no addon download); see DECISIONS.md.

## What to playtest (once it runs)
- Host + join; survive 5 waves; do both players feel they relied on the other's turrets?
- Is the 60 m climb too slow? (climb speeds live in `data/bugs/*.tres`)
- Do spitters (cling at 65% height) feel fair to hit?
