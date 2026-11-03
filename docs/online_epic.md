# Online play through Epic Online Services

Players need no Epic account: each PC signs in anonymously (EOS Connect, Device ID).
The host's game gets an EOS lobby holding a `DUST-XXXXXX` code; joiners look the code
up and connect over EOS P2P (NAT punch-through, else Epic's relay servers), so no
router setup is needed. Direct invites (`DUST-XXXXX-XXXXX`, the host's IP) keep working.

Code: `components/net/` (`online_backend.gd` is the interface and lists how to
remove Epic or add Steam), plugin in `addons/epic-online-services-godot/`
(EOSG 2.3.1, MIT, bundles Epic's SDK DLLs).

## Credentials
- Development: `eos_credentials.txt` in the project root (gitignored). Labelled lines
  or a raw copy-paste from the Epic Developer Portal both work.
- Releases: repository secrets `EOS_PRODUCT_ID`, `EOS_SANDBOX_ID`, `EOS_DEPLOYMENT_ID`,
  `EOS_CLIENT_ID`, `EOS_CLIENT_SECRET` (Settings > Secrets and variables > Actions).
  `release.yml` writes them into `eos_release.cfg` (gitignored) inside the build.
  Without them the build has direct invites only.
- The release now ships `DustAndMandibles.exe` plus three DLLs (and a zip of all four);
  the setup program downloads the DLLs too. The exe alone falls back to direct invites.

## Test flags
`--epic` turns online lobbies on in `--debug` launches (they're off there by default),
`--direct` turns them off, `--eosrelay` forces Epic's relay, `--eosnewdevice` gives a
second copy on the same PC its own anonymous id, `--eoscreds=<file>` reads other credentials.
`--netlog` logs every P2P request, link, interruption and close (with EOS's reason) and
the EOS SDK's own warnings (`[eos] ...`, P2P and lobby notes too).

Notes from the release-build join fixes:
- EOS P2P refuses packets over ~1170 bytes (EOSG doesn't split them; it logs
  "Failed to send packet. Packet size exceeds limits." and drops them). The game's
  Epic peer is wrapped in `components/net/fragmenting_peer.gd`, which splits big
  packets and joins them again, so big syncs and spawns always arrive.
- `--eosnewdevice` deletes this PC's Device ID, which the other copy (the host) is
  signed in with: after a while (seconds to minutes) EOS shuts that copy's P2P down
  ("Leave all connections due to P2P network shutdown") and the joiner is dropped.
  Two copies on one PC can't both keep a Device ID; real players on two PCs aren't
  affected, so test long sessions across two PCs.
- The menu's "Host via" pick (Online / Direct (IP/LAN), saved as Settings.host_online)
  lets a host skip Epic if it misbehaves; `--epic` launches always host online.
- Once a run starts the lobby stays findable but says STARTED, so a late joiner is
  told the game already started instead of "no game with that code".

## Checklist
1. Unit tests pass; the log says `[net] backends: Direct only (...)` for script runs.
2. Two copies on this PC through the relay:
   host `-- --debug --epic --eosrelay --netlog --fast --menu --host --players=2`,
   joiner `-- --debug --epic --eosrelay --eosnewdevice --netlog --fast --join=DUST-XXXXXX`
   (code from the host's `[net] Epic lobby ..., invite` line). Both log
   `Epic P2P link ...: relayed`, the run starts and waves play.
3. Normal launch (no flags): Host shows "Signing in to online play...", then
   "Creating lobby..." (Copy Code greyed), then "Lobby  DUST-XXXXXX" with the note
   "Works from anywhere...". Lobby rows and the F3 overlay show ping (Epic games
   measure it with a 1 s ping RPC; Direct games use ENet's figure).
4. A friend on another network (no port forwarding) joins with that code and plays a wave.
5. Leave as host, or lose the host's connection: the friend returns to the menu with
   "The host left the game, or the connection to them dropped."; the old code then
   says "No game with that code". Join errors also cover "That game is full" and
   "Version mismatch".
6. Wrong or missing credentials, or no internet: Host still works, with a direct
   code and a note saying why online is off; joining a `DUST-XXXXXX` code says why it can't.
7. Release build from a tag with the secrets set: the release has the exe, three DLLs,
   the zip and the setup; a fresh install via the setup gets an online code.
