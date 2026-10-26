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
20. **Canyon is 60 m deep (Logan's request), not the doc's 28 m.** Every height (lip band, overhang underside, fall-into-canyon line, end walls) now derives from `WorldLayout.CLIFF_HEIGHT`. Ledges sit every 10 m. Bugs climbing at the doc's speeds now take about twice as long; climb speeds are a tuning knob for M2 playtests. With a 30 degree turret pitch limit, turrets reach roughly the top 28 m of the far face.
21. **Pause menu (Logan's request): Esc opens it in game; the title screen has a Settings button with the same tabs.** The game keeps running behind the menu (it's online co-op); your character just stops taking input. Settings save to `user://settings.cfg`, including key remaps, which override `InputSetup`'s defaults.
22. **Social tab invites are "IP:port" for now** (LAN address of the host, copied to the clipboard). Joining from the tab leaves the current game and joins from the main menu. Proper invites through Steam or a relay would replace this behind the same tab once internet play is added (doc: "Internet play (later)").
23. **Esc no longer frees the mouse directly**; it opens the pause menu, which frees it.
24. **Unit tests use a tiny built-in runner (`tests/run_tests.gd` + `TestCase`) instead of GUT**, because GUT is a download. The tests are written so GUT can replace the runner later.
25. **Turret pitch limit is 30 degrees, not 15.** With a 45 m gap, 15 degrees only reaches the top few metres of the far face; 30 still can't see your own face (the lip overhang hides it and it's nearly straight down). It's a per-turret field in `data/turrets/*.tres`.
26. **Bug loot goes straight into the stockpile of the cliff the bug was climbing** (with a kill-feed line), instead of physical pickups. Keeps "your turrets earn for your partner" without syncing pickups. Pickups can come later.
27. **Bugs emerge at the base of their lane** instead of walking from the nests. The nests are visual for now.
28. **Breachers steer straight at targets over the open plateau** (no NavigationAgent3D). Generated terrain would need runtime navmesh baking; the plateau is open enough for the proof of concept.
29. **Bugs aren't pooled.** They're replicated with MultiplayerSpawner, which creates and frees nodes; VFX are pooled. Revisit if waves of 150 bugs stutter.
30. **Building is allowed in any phase**, not only the build phase. Repairing is allowed for anyone on any turret (paid by the repairer), since helping your partner is the point.
31. **Spitter Scorpions cling at 65% of the cliff height** (the doc says halfway) so turrets can actually reach them on the deeper canyon.
32. **Players have 100 HP, are downed for 15 s at 0 and respawn at home.** Breachers attack players within 7 m first.
33. **Balance pass from automated soak tests (no players shooting):** climb speeds are 1.5x the doc's (the 60 m cliff doubled exposure time), Gatling damage 3.5 at 65% hit chance, and bug HP grows 12% per wave (`hp_per_wave` in `wave_config.tres`). Starting values only; the M2 playtest decides.
34. **Debug automation flags** for testing without a person: `--soak=N` (headless waves, auto-ready), `--autobuild [--light]`, `--showcase` (one of each bug frozen on the west face), `--cam=x,y,z,tx,ty,tz`, `--pause=tab`, `--seconds=N` with `--shot`.
