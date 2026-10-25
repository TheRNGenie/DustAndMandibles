# Decisions and deviations

Assumptions and changes from the design doc, newest last.

1. **Project lives at the repo root.** The doc's layout uses a `dust-and-mandibles/` folder; here `D:\DustAndMandibles` itself is the Godot project, so `project.godot` sits at the root.
2. **Input actions are registered in code** (`autoload/InputSetup.gd`) instead of the `[input]` section of `project.godot`. Hand-writing serialized InputEvents is error-prone, and this keeps all bindings in one readable place. Adds one autoload not named in the doc.
3. **Canyon runs along Z.** West plateau at x < -22.5, east at x > 22.5. Playable plateau is 40 m along Z by 30 m back from the lip; terrain extends further (hills beyond the fence, end walls at z = ±88) so the canyon reads as a landscape.
4. **Lip overhang 2.2 m**, lip band from 26.6 m up, underside 25.4 to 26.6 m. Starting values for the line-of-sight layer of the cross-defense rule; tune in M2.
5. **Lanes at z = -16, -8, 0, 8, 16**, marked by a vertical crack plus ledges at 7, 14 and 21 m.
6. **Vertex colours carry albedo; vertex alpha < 1 marks glowing parts.** Lets each generated prop be one mesh with one shared toon material (fewer draw calls). Colours are converted to linear in `MeshKit.vcol`.
7. **Strata shader uses `cull_disabled` and flips the normal on back faces**, so terrain shades correctly whatever the winding.
8. **Outline width grows with distance** (up to 3x) so bugs stay readable 45 to 60 m away. The optional full-screen edge-detect pass for terrain is deferred.
9. **No custom font yet.** Fonts from Google Fonts would be a download; the HUD uses Godot's built-in font until a Rye/Rubik (OFL) font is added with its license file.
10. **GUT not added in M0.** It's a download (MIT), and M0 has no logic worth unit-testing. It gets added in M1/M2 before the targeting, economy and wave-budget tests.
11. **Canyon fall penalty deferred.** Falling hauls you home after 3 s; the "small penalty" (scrap) needs the M2 economy.
12. **Hits apply locally in M0.** The revolver emits `fired(origin, dir)` so M1 can route it through `request_fire` to the host.
