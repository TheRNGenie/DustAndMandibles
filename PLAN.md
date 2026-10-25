# PLAN: M1, Networked co-op skeleton

Source of truth: the design doc "Cross-Cliff Co-op Defense: Game Plan & Build Prompt".
M0 (graybox and shader kit) is done; see git history.

**Done when:** two instances connect, both players see each other move and shoot, and phase changes happen together.
**Result:** passes in automated two-instance tests (`tools/run_two_local.ps1`). Needs a hands-on playtest with two people.

| # | Task | Files | How it's verified | Status |
|---|------|-------|-------------------|--------|
| 1 | NetworkManager: ENet host/join, roster, cliff assignment (host west, joiner east), ready, start | `autoload/NetworkManager.gd` | Logs show both peers spawn players on the right cliffs | Done |
| 2 | Main menu + lobby: name, IP (127.0.0.1), port 24565, Host/Join, roster, Ready, Start alone | `scenes/main_menu.tscn`, `scenes/ui/main_menu.gd` | `--host` / `--join` auto-connect and start once both are ready | Done |
| 3 | Player spawning by the host via MultiplayerSpawner once every peer has loaded | `scenes/world.gd` | No "node not found" errors on the client | Done |
| 4 | Movement sync: owner-authoritative, 20 Hz MultiplayerSynchronizer, interpolated; third-person cowboy body with team bandana | `scenes/player/player_net.gd`, `player.tscn`, `gen/character_builder.gd` | Joiner sees the host at the host's real position | Done |
| 5 | Shooting: client predicts, host raycasts and applies damage, host tells others to draw tracer + sparks | `scenes/player/player_net.gd`, `revolver.gd`, `vfx_pool.gd` | `--netlog`: host logs "confirmed shot", other peer logs "drew shot" | Done |
| 6 | Phase clock on the host (build 150 s to 90 s, warning 10 s, placeholder 30 s wave), reliable RPC broadcast, G to vote Ready/skip | `autoload/GameState.gd`, `scenes/ui/hud.gd` | Both HUDs show the same phase; voting skips together | Done |
| 7 | Rope drawbridge: lowered in build phase, both halves haul up at the warning | `scenes/structures/bridge.gd` | Both peers report the bridge raised in the wave phase | Done |
| 8 | HUD phase banner, hints, F3 overlay with peer id, role, ping | `scenes/ui/hud.gd` | Visual | Done |
| 9 | Invisible walls on their own physics layer so they don't stop bullets | `data/world_layout.gd`, `world_dressing.gd` | Shots pass through | Done |

## Testing locally
```
powershell -File tools\run_two_local.ps1
```
Opens a host window (west) and a join window (east) with `--fast --debug`.
Automated checks add `-HostExtra/-JoinExtra "--shot=... --frames=N --autofire --autoskip --netlog"`.

## What to playtest
- Host on one PC, join from another by LAN IP (open UDP 24565 in the firewall if needed).
- Walk across the bridge in the build phase; press G on both PCs to skip; watch the bridge haul up.
- Shoot near your partner and check they see the tracer.
