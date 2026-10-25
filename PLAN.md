# PLAN: M0, Graybox and the shader kit

Source of truth: the design doc "Cross-Cliff Co-op Defense: Game Plan & Build Prompt".

**Done when:** you can walk to the lip, look across, and it already looks like a stylized western canyon.
**Result:** passes (checked with screenshots from the spawn, from the lip looking down, and along the canyon). Needs a hands-on playtest of movement feel.

| # | Task | Files | How it's verified | Status |
|---|------|-------|-------------------|--------|
| 1 | Project skeleton, input map, autoload stubs | `project.godot`, `autoload/` | `godot --headless --quit-after 300` prints no errors | Done |
| 2 | Shader kit: toon ramp, outline, cliff strata, sky, VFX star | `shaders/` | Compile on import, visual check | Done |
| 3 | Mesh kit and shared materials | `gen/mesh_kit.gd`, `gen/materials.gd`, `gen/palette.gd` | Props render the right way out with outlines | Done |
| 4 | Canyon generator with overhanging lip and climb lanes | `gen/cliff_builder.gd`, `data/world_layout.gd` | From the lip looking down, your own face is hidden; the far face is fully visible | Done |
| 5 | Dressing: homestead, water tower, windmill, fences, props, nests | `gen/building_builder.gd`, `gen/prop_builder.gd`, `scenes/world_dressing.gd` | Visual check | Done |
| 6 | First-person controller: walk, sprint, jump, slide, mantle, canyon fall | `scenes/player/` | Manual playtest | Done, needs playtest |
| 7 | Revolver, hit sparks, tin-can targets | `scenes/player/revolver.gd`, `scenes/vfx/vfx_pool.gd`, `scenes/props/tin_can.gd` | Manual playtest | Done, needs playtest |
| 8 | HUD: crosshair, ammo sign, fall message, F3 overlay | `scenes/ui/hud.gd` | Visual check | Done |
| 9 | README, DECISIONS, git + push | root | On GitHub | Done |

## Debug screenshot flag
`godot --path . -- --shot=C:\path\shot.png [--pos=d,z] [--look=yaw,pitch] [--east]` renders 90 frames, saves a PNG and quits.

## What to playtest
- Sprint, slide (Ctrl while running), jump and mantle onto the target crate or the porch.
- Walk off the lip into the canyon: you should be hauled home after 3 s.
- Shoot the tin cans on the crate near the spawn and the rocks; reload with R.
