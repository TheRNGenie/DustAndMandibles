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

## Checklist
1. Unit tests pass; the log says `[net] backends: Direct only (...)` for script runs.
2. Two copies on this PC through the relay:
   host `-- --debug --epic --eosrelay --netlog --fast --menu --host --players=2`,
   joiner `-- --debug --epic --eosrelay --eosnewdevice --netlog --fast --join=DUST-XXXXXX`
   (code from the host's `[net] Epic lobby ..., invite` line). Both log
   `Epic P2P link ...: relayed`, the run starts and waves play.
3. Normal launch (no flags): Host shows "Signing in to online play...", then a
   `DUST-XXXXXX` code with the note "Works from anywhere...".
4. A friend on another network (no port forwarding) joins with that code and plays a wave.
5. Leave as host: the friend returns to the menu; the old code then says "No game with code".
6. Wrong or missing credentials, or no internet: Host still works, with a direct
   code and a note saying why online is off; joining a `DUST-XXXXXX` code says why it can't.
7. Release build from a tag with the secrets set: the release has the exe, three DLLs,
   the zip and the setup; a fresh install via the setup gets an online code.
