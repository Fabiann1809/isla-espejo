# Temple art v2

## Integrated runtime art
Run `python tools/adapt_temple_art_v2.py` from the repository. Pillow is required. Run this adaptation AFTER the original temple art generators if rebuilding everything.

The adapter writes the existing resources consumed by Godot:
- `assets/tilesets/temple/temple_sheet.png`: 16 px tiles, three 64 px floor macros, painted cliff/masonry faces and three animated 128 px lava macros.
- `assets/sprites/temple_props/*.png`: 23 adapted strips, using the original integral cell dimensions, feet and frame counts from `props.json`.

No runtime script, scene, resource path, collision footprint, elevation rule, hazard timer or phase span needs to change. Alpha is cleaned to 0/255, detached speckles are discarded, and colours use `tools/temple_palette.py`. Texture filtering stays nearest with no mipmaps. Lava periods share boundaries; floor height tones remain distinct.

Fire frames keep the stone base fixed. Plant roots and hanging attachments stay anchored while leaves, vines and banners sway. The geyser, spikes and rolling rock retain the existing phase ranges; the rock keeps its authored break/spawn frames. `ember_vent` and `saw_track` retain their existing art. Structural ledge masks, stairs, bridge rails and corner topology also remain authored in the original atlas.

## Source sheets
The PNGs in this folder are sources, not runtime atlases. They measure 1254 × 1254; the adapter rounds source cell boundaries once and outputs integral runtime cells. Do not import these directly as a 16 px TileSet.

- `props.png`: 4 × 4 pillars, columns, guardian, braziers, torch, gate, altar, pottery, barrel, rubble, volcanic rock and plant.
- `architecture.png`: 4 × 4 architecture pieces; the adapter uses the vines and banner.
- `terrain.png`: 8 × 8 terrain regions, including stone, cliffs, walls and lava.
- `effects.png`: eight rows of eight frames: brazier, torch, lava fall, geyser, spikes, saw, rock and smoke. The smoke row is reference only.
- `props_original.png`: previous source version retained for comparison; do not use it directly.

Direction: top-down temple, dusty rose stone, olive moss, geometric carvings, purple shadows and amber lava. The reference map guides style; actual room layouts remain procedural.

## Verification
Use `tools/run_tests.sh` for gameplay checks. `tools/snapshot_temple.gd` renders all 13 room designs and a complete seeded map. Review at native game scale, including raised terraces, bridges and trap lanes. Final screen captures and a comparison are in the sibling `revision_arte/temple_after` and `revision_arte/temple_v2_comparison.png` outside this repository.
