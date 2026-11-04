# Terrain textures

AI-generated with fal.ai, then channel-packed for `shaders/cliff_strata.gdshader`:

- `rock_detail.png` / `rock_normal.png`: ledged strata (R, normal RG) and blocky slabs (G, normal BA). fal-ai/patina/material (z-image texture + PATINA normal maps).
- `ground_detail.png` / `ground_normal.png`: canyon floor colour, gravel, flat stones and bones (RGB, normal RG) and the plateau's cracked hardpan (A, normal BA). fal-ai/patina/material.
- `infest_mask.png`: claw scrapes (G), burrow holes (B), silk stains (A); R is the old resin mask, no longer drawn. fal-ai/z-image/turbo/tiling, thresholded and blurred into masks.
- `resin_atlas.png` / `resin_normal.png`: four hive-resin variants in a 2x2 atlas (drips, debris with trapped bugs and bones, cracked crust, pustules), colour + height and normals. fal-ai/patina/material.

Prompts, seeds and the packing scripts are kept in D:\DustAndMandibles-archive\textures (manifest.jsonl, pack.py, pack2.py, pack3.py).
