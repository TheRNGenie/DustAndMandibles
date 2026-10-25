# PLAN: M0, Graybox and the shader kit

Source of truth: the design doc "Cross-Cliff Co-op Defense: Game Plan & Build Prompt".

**Done when:** you can walk to the lip, look across, and it already looks like a stylized western canyon.

| # | Task | Files | How it's verified | Status |
|---|------|-------|-------------------|--------|
| 1 | Project skeleton, input map, autoload stubs | `project.godot`, `autoload/` | Project opens; `godot --headless --quit-after 300` prints no errors | Written, not run |
| 2 | Shader kit: toon ramp (3 bands, purple shadows, rim), inverted-hull outline, cliff strata (triplanar, height bands), sky, VFX star | `shaders/` | Shaders compile on import, no errors in the output panel | Written, not run |
| 3 | Mesh kit (box, cylinder, cone, ellipsoid, limb into one SurfaceTool with vertex colours) and shared materials | `gen/mesh_kit.gd`, `gen/materials.gd`, `gen/palette.gd` | Props render with correct facing (no inside-out faces) and outlines | Written, not run |
| 4 | Canyon generator: 45 m gap, 28 m cliffs, overhanging lip, 5 carved lanes with ledges, plateaus with hills beyond the play area, riverbed floor, end walls; trimesh collision | `gen/cliff_builder.gd`, `data/world_layout.gd` | Walk the plateau, look down: own face hidden by the lip, far face fully visible | Written, not run |
| 5 | Dressing: homestead, water tower, windmill (spinning fan), fences + invisible walls, cacti, rocks, barrels, crates, nest mounds | `gen/building_builder.gd`, `gen/prop_builder.gd`, `scenes/world_dressing.gd` | Visual check from both plateaus | Written, not run |
| 6 | First-person controller: walk, sprint, jump, slide, mantle, canyon fall teleports home after 3 s | `scenes/player/` | Manual: mantle onto crate/porch, slide, jump off the lip and get hauled back | Written, not run |
| 7 | Revolver viewmodel: 6 rounds, reload, recoil, muzzle flash, hit sparks, tin-can targets | `scenes/player/revolver.gd`, `scenes/vfx/vfx_pool.gd`, `scenes/props/tin_can.gd` | Manual: shoot cans and rock, see sparks, reload | Written, not run |
| 8 | HUD: crosshair, ammo sign, fall message, F3 debug overlay | `scenes/ui/hud.gd` | Manual | Written, not run |
| 9 | README, DECISIONS, git init + push | root | Repo on GitHub | Docs written; git waiting on install |

## Blocked
Godot and Git are not installed on this PC yet, so nothing has been run. Next step once
Godot is in: run headless, fix every error and warning, then a visual check.
