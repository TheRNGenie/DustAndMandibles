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
13. **Lobby can start solo.** The game starts automatically once two players are ready; the host also gets a "Start alone (testing)" button (and `--solo` flag) until M2's proper solo test mode.
14. **Tin cans are cosmetic and not synced.** Every peer nudges its own cans when it sees a shot land. Host-authoritative damage only applies to things with `apply_hit` that aren't loose physics props.
15. **Bridge is a two-half rope drawbridge at z = -17**, pivoting at each lip. It lowers in the build (and lobby) phase and hauls up when the warning starts. Each peer animates it from the replicated phase, so it needs no sync of its own.
16. **Placeholder wave length of 30 s** until M2's bugs end the wave. `--fast` scales phase times by 0.15 for testing; `--debug` enables F6 to skip a phase.
17. **Physics layers:** 1 = world (bullets hit it), 2 = player-only blockers (invisible boundary walls).
18. **Shot origin is trusted from the client** (host re-raycasts from it). Fine for co-op; revisit if cheating ever matters.
19. **The cliff face away from the sun sits in shadow tint.** Left as is for now; the M3 day/dusk lighting pass should make sure both far faces read well.
