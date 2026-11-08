# Temple scenery — complete adaptation and depth

Rebuild with `python tools/finish_temple_art.py` (Pillow required). This calls the base adapter and then finishes all structural and incidental tile roles. Run it after the older temple art generators. Running only `adapt_temple_art_v2.py` rebuilds the partial first pass.

## Runtime assets
- `assets/tilesets/temple/temple_sheet.png`: all 1989 named roles adapted, including stairs, decks, rails, posts, ledges, cap corners, mossy faces, illuminated cliff feet, shore, bubbles, floors, incidental props and animations.
- `assets/sprites/temple_props/*.png`: all 25 strips, including smoke/embers, saw groove and rolling rock break/spawn phases.
- `coverage.json`: complete list of tile roles handled by the rebuild.

Atlas coordinates and topology masks stay compatible with the existing profiles. The source template supplies cutouts, neighbour masks and step joints; painted source materials replace the old material pixels. This retains the game's modular silhouettes rather than introducing a different collision grid. Colours use `tools/temple_palette.py`; sprite alpha is binary and runtime dimensions remain integral.

## Depth
The visual foundation extends up to two extra rock rows into lava (`Tuning.TEMPLE_LAVA_CLIFF_EXTRA_ROWS`). Existing plan checks stop it before walkable islands, stairs and decks. This changes no collision rectangle or actor height. `LavaShadows` casts a shadow below the foundation, above the sea and below every floor. Darker cliff faces, stronger south/east shadows, distinct floor tones and softer fire glare reveal the three heights.

## Sources
The four painted source sheets measure 1254 × 1254. They are not runtime TileSets; the adapter rounds source regions once and exports the original game-sized cells.
- props.png: pillars, guardian, fire bases, portal, pottery, rubble, vegetation.
- architecture.png: structural pieces, vines, banner and chest.
- terrain.png: stone, cliff, masonry, lava, stair treads and bridge planks.
- effects.png: fire, falls, geyser, spikes, saw, rock and smoke.
- atlas_template.png: compatible topology and silhouette template from the preceding revision.
- props_original.png: earlier reference, not consumed by the rebuild.

## Review
Render all 13 room designs and a complete map with `tools/snapshot_temple.gd`. Current captures are in the sibling `revision_arte/temple_depth/`; `temple_depth_comparison.png` compares the terraces with the previous integration. The source folder is excluded from Godot import/export through .gdignore; final textures are in the runtime asset folders above.

The player, enemies and gameplay UI retain their established art; this adaptation concerns scenery. Gameplay footprints, trap timing, phase spans and procedural room plans remain unchanged.
