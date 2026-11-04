# Terrain textures

AI-generated with fal.ai, then channel-packed for `shaders/cliff_strata.gdshader`:

- `rock_detail.png` / `rock_normal.png`: ledged strata (R, normal RG) and blocky slabs (G, normal BA). fal-ai/patina/material (z-image texture + PATINA normal maps).
- `ground_detail.png` / `ground_normal.png`: canyon floor colour, gravel, flat stones and bones (RGB, normal RG) and the plateau's cracked hardpan (A, normal BA). fal-ai/patina/material.
- `infest_mask.png`: hive resin (R), claw scrapes (G), burrow holes (B), silk stains (A). fal-ai/z-image/turbo/tiling, thresholded and blurred into masks.

Prompts, seeds and the packing script are kept in D:\DustAndMandibles-archive\textures (manifest.jsonl, pack.py, pack2.py).
