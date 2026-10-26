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
| 6 | Bugs: Brood Mother (+spiderlings), Burrow Tick, Dragonfly Bandit, Crop Weevil | `data/bugs/`, `gen/bug_builder.gd`, `scenes/bugs/`, `components/Flier.gd`, `Breacher.gd`, `bug_status.gd` | `--showcase=2` screenshot; soak to wave 9 | Done |
| 7 | Build menu for 12 items (1-0, mouse wheel), demolish any structure | `scenes/player/build_mode.gd`, `scenes/structures/build_manager.gd` | Manual | Done |
| 8 | Day/dusk lighting + two generated music loops | `scenes/day_cycle.gd`, `tools/audio/make_music.py`, `autoload/Audio.gd` | Dusk screenshot | Done |

## What to playtest
- Does farming matter? Water Cannons and Chili Mortars go quiet without water/chili.
- Burrow Ticks: are they findable without lanterns? Dragonfly Bandits: fair to shoot?
- Storm build phases: noticeable enough?
