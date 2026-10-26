# PLAN: M4, boss, polish and packaging (M3 below)

**Done when:** a full 10-wave run is playable start to finish by two people on two PCs over LAN, with no debug tools.

| # | Task | Status |
|---|------|--------|
| 1 | The Iron Tumble boss (wave 10): boulder, armoured back, glowing belly seam, switches cliffs at half health, boss bar | Done |
| 2 | HUD polish: wanted-poster/wood-sign panels, damage numbers, hit markers, screen shake, death pops | Done |
| 3 | Settings menu (sensitivity, volume, FOV, more) | Done (pause menu) |
| 4 | Windows and Linux export presets | Presets done; needs export templates (download) to build |
| 5 | Full 10-wave automated run | Done: soak with all turrets/traps/farming reaches wave 10, beats the boss, ends in a win |
| 6 | Two-person LAN playtest of the whole run | Waiting on Logan |

Extra (Logan's request): the canyon now continues ~700 m into the distance instead of ending in walls.

---

# PLAN: M3, survival and the full roster

Source of truth: the design doc "Cross-Cliff Co-op Defense: Game Plan & Build Prompt".
M0-M2 are done (M2 still wants its two-person playtest). Logan's extra requests so far:
a 60 m canyon and a pause menu (both done).

**Done when:** all 9 waves before the boss run with the full roster, and farming visibly changes how players defend.

| # | Task | Files | How it's verified | Status |
|---|------|-------|-------------------|--------|
| 1 | Resources water/food/chili; CropDef/StructureDef; crop growth logic + tests | `data/`, `components/crop_growth.gd`, `tests/test_crop_growth.gd` | Unit tests | Done |
| 2 | Crop field (9 plots per Homestead), windmill well (fix for 80 scrap), rain catcher, storms | `scenes/farm/` | Soak bot farms every build phase | Done |
| 3 | Hunger/thirst, eat (F) / drink (Q), sprint and reload debuffs | `scenes/player/player_vitals.gd`, `player_net.gd` | HUD bars | Done |
| 4 | Turrets: Water Cannon (knock-off, water ammo), Chili Mortar (burning patch, chili ammo), Dynamite Lobber (splash), Lasso Harpoon (pin); chitin upgrades (U) | `data/turrets/`, `components/turret_effects.gd`, `scenes/turrets/turret.gd`, `gen/turret_builder.gd` | Soak bot builds and upgrades all of them | Done |
| 5 | Traps: barbed wire, bear trap, dynamite crate, palisade, lantern post | `data/structures/`, `scenes/structures/structure_node.gd`, `gen/structure_builder.gd` | Soak bot places them | Done |
| 6 | Bugs: Brood Mother (+spiderlings), Burrow Tick, Dragonfly Bandit, Crop Weevil | `data/bugs/`, `gen/bug_builder.gd`, `scenes/bugs/`, `components/Flier.gd`, `Breacher.gd`, `bug_status.gd` | `--showcase=2` screenshot; soak runs all 9 pre-boss waves (`--god --autokill`) | Done |
| 7 | Build menu for 12 items (1-0, mouse wheel), demolish any structure | `scenes/player/build_mode.gd`, `scenes/structures/build_manager.gd` | Manual | Done |
| 8 | Day/dusk lighting + two generated music loops | `scenes/day_cycle.gd`, `tools/audio/make_music.py`, `autoload/Audio.gd` | Dusk screenshot | Done |

## What to playtest
- Does farming matter? Water Cannons and Chili Mortars go quiet without water/chili.
- Burrow Ticks: are they findable without lanterns? Dragonfly Bandits: fair to shoot?
- Storm build phases: noticeable enough?
