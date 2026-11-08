# Templo del Eclipse (nivel 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable third chapter: a temple of stone islands over an animated lava sea, three real height
levels, irregular rooms with bridges and stairs, stage-by-stage lava surges, and a per-run roster of the 25
temple enemies, built by the existing procedural generator.

**Architecture:** Same pipeline as the Ruinas: Python tools draw the art (16 px grid) → a GDScript tool
makes the tileset profile, theme and room data → `MapGenerator` lays out rooms → `Level` builds them. A pure
`TemplePlan` (text plan → per-cell heights, collision per layer, validation) feeds a `TempleShape` node that
draws and collides. `Heights` grows from 2 to 3 levels without changing the Ruinas. `LavaSurge` is a room
child driven by a pure `LavaSurgeLogic`.

**Tech Stack:** Godot 4.7.2 GDScript (static typing), Python 3 + Pillow for art, headless tests
(`extends SceneTree`, `tests/test_*.gd`).

**Spec:** `docs/superpowers/specs/2026-11-06-templo-nivel3-design.md` (read it before any task; §10 holds
the decisions taken after review).

## Global Constraints

- Read `CLAUDE.md` first. Its rules hold in every task; the ones below are the most often broken.
- Repo root: `isla-espejo/`. Branch `auto/mejoras-noche`. Never push, never tag.
- Commits: Conventional Commits in English (`feat(world): ...`, scopes from `CLAUDE.md`), ≤ 72 chars.
  **No `Co-Authored-By` or any AI attribution in commits or files.**
- GDScript: static typing, English identifiers and comments. Player-facing text in Spanish, in `data/`
  (`data/ui/texts.json` through `UiText.t`), never in scripts.
- Look values in `Tuning` (`scripts/core/tuning.gd`) under a `# --- Temple ---` section, each effect with
  an off switch. Gameplay numbers (surge kills, waves, roster size) live in `data/`.
- Damage only through `Hitbox`/`Hurtbox`/`HealthComponent`. Gameplay emits `Events`; it never plays sounds,
  shakes the camera or freezes time.
- Draw order: floors at `RoomTheme.FLOOR_Z` (-2), ground effects at `GROUND_FX_Z` (-1), actors and upright
  props at z 0, y-sorted. Decorations at z ≥ 0 must be y-sorted.
- Art: drawn pixel by pixel at game size with Pillow, colors only from `tools/temple_palette.py` (plus
  alpha), 1 px `OUTLINE` on upright props, light from the upper left. Never resample or copy pixels from the
  reference zip. Every piece that can move has ≥ 4 frames, and neighbours are phase-shifted (offset seeded by
  position) so they never pulse in unison.
- References: `docs/referencias/templo_mapa.jpg`, `docs/referencias/templo_enemigos.jpg`, and the zip's
  contact sheets in `C:/Users/nikol/AppData/Local/Temp/claude/df2c576e85fc45d0/ebad0627-9e71-45cf-9031-e542a4b008b9/scratchpad/templo_zip/Templo_Antiguo_TileSet_Tecnico/preview/`
  (piece list, proportions and palette only).
- Tests: in tests, never `preload` scenes or reference `class_name` types of scripts that use autoloads;
  load at runtime, untyped variables, `await process_frame` first if an autoload is touched. Model:
  `tests/test_heights.gd`.
- Godot to run tests (Git Bash):
  `GODOT="/c/Users/nikol/Downloads/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" ./tools/run_tests.sh <test names>`.
  The first run in a fresh checkout imports the project (slow). A task is done only when its own tests **and**
  every test named in its "Regression" line pass.
- The forest and the Ruinas must look and play exactly as before. `tools/dump_tiles.gd` and the existing tests
  are the proof.

## Review Focus

1. **Spawns in lava or in unreachable places.** A spot on lava, on a cliff-face row, or on a level with no stairs
   to the room's doors must never hold an enemy, chest or player. Pinned in Task 4 (`spawn_ok`) and Task 9
   (generator validation on every room).
2. **Actors left on a flooding level.** Nico on level 0 when the surge rises must be able to reach stairs and
   take periodic damage, not instant death, and must not be stuck behind the sealed doors. Pinned in Task 8
   (`test_lava_surge`: walk-to-stairs and damage-rate checks).
3. **Arrows and cliffs.** A level-1 arrow flies over level-1 edges and stops at a level-2 cliff. A level-0 arrow
   stops at any higher cliff. Every arrow flies over lava. Pinned in Task 1.
4. **Doors at different heights.** Corridors join only rooms whose base heights differ by ≤ 1, and a door cell
   always sits on the room's base height. Pinned in Task 5 (generator) and Task 4 (plan validation).
5. **Same seed, same map and roster.** Pinned in Task 5.

---

## Waves (what may run in parallel)

- **Wave A** (independent, each in its own worktree): Tasks 1, 2, 3, 4, 5.
- **Wave B** (after A is merged): Tasks 6, 7, 8, in parallel. Task 6 owns `room.gd`, Task 7 owns `level.gd`,
  Task 8 owns `events.gd`. `tuning.gd` and `texts.json` take only appended sections.
- **Wave C:** Task 9.
- **Wave D:** Task 10.

---

### Task 1: Three height levels

**Files:**
- Modify: `scripts/world/heights.gd`, `scripts/world/stair_zone.gd`, `project.godot` (`[layer_names]`: `2d_physics/layer_10="block_top"`, `2d_physics/layer_11="cliff_top"`)
- Test: `tests/test_heights.gd` (keep every existing check unchanged; add new ones)

**Interfaces:**
- Produces:
  - `Heights.LOW = 0`, `Heights.MID = 1`, `Heights.HIGH = 1` (alias kept for the Ruinas), `Heights.TOP = 2`,
    `Heights.LEVELS = 3`.
  - `Heights.BLOCK_TOP_LAYER = 10`, `Heights.CLIFF_TOP_LAYER = 11`.
  - `static func block_layer(level: int) -> int`, returning 8, 9 or 10. That layer holds what blocks
    *actors* standing on `level`.
  - `static func is_flyer(node: CollisionObject2D) -> bool`. True when the body's original mask had no water
    bit (the same stored meta `set_level` already uses). Call `set_level` once first if the meta is unset.
  - `set_level(node, level)`:
    - mask bit 7 = `level == 0` and the body had water;
    - bit 8 = `level == 0`; bit 9 = `level == 1`; bit 10 = `level == 2`;
    - bit 11 is never set on bodies.
  - `set_projectile_level(sensor, level)`:
    - bit 8 = `level == 0`; bit 11 = `level == 1`;
    - bits 9 and 10 are never set.
  - Meaning of the layers:
    - layer 8 holds every cell of height ≥ 1;
    - layer 9 holds what a level-1 actor may not enter;
    - layer 10 holds what a level-2 actor may not enter;
    - layer 11 holds cells of height 2, so level-1 projectiles see the cliff.
  - `StairZone.low_level: int = 0` (export). The zone switches bodies between `low_level` and
    `low_level + 1` halfway along `direction`.

- [ ] **Step 1: Add the failing checks to `tests/test_heights.gd`**

Add these checks after the existing ones. Use walls built with the existing `_wall()` helper on layers 10
and 11, and a `_stairs()` with `low_level = 1` (extend the helper with an optional `low_level` parameter):
- `"a level-2 Nico is stopped by layer 10 and passes layers 8 and 9"`
- `"a level-1 Nico is not stopped by layer 11"`: walking right through a layer-11 block, x passes the block.
- `"stairs with low_level 1 move Nico between levels 1 and 2"`
- `"a level-1 arrow flies over a layer-9 rail and stops at a layer-11 cliff"`
- `"a level-2 arrow is stopped by none of 8, 9, 10, 11"`
- `"a flyer is detected and a walker is not"`: `Heights.is_flyer` on the flyer body and on the grunt.

- [ ] **Step 2: Run, expect the new checks to FAIL and the old ones to PASS**

Run: `./tools/run_tests.sh test_heights`.

- [ ] **Step 3: Implement the interfaces above.** Keep `BLOCK_LOW_LAYER` and `BLOCK_HIGH_LAYER`. Update the
  class doc comment to describe three levels and the four layers.

- [ ] **Step 4: Run the tests.** Expect `test_heights` to PASS.
  Regression: `test_stairs_corridor test_ruin_shape test_ruin_props test_ruins test_water test_draw_order`.

- [ ] **Step 5: Commit** with `feat(world): add a third height level for the temple`.

---

### Task 2: Temple terrain art, tileset profile and theme

**Files:**
- Create: `tools/make_temple_tileset_art.py` → `assets/tilesets/temple/temple_sheet.png` (16 columns of 16 px tiles) and `assets/tilesets/temple/temple_tiles.json` (name → `[col,row]`; patterns and animations → lists of `[col,row]`)
- Create: `tools/make_tileset_temple.gd` → `data/tilesets/temple.tres`; `tools/make_temple_theme.gd` → `data/themes/temple.tres`
- Modify: `scripts/world/room_theme.gd` (add `WallStyle.LAVA`)
- Test: `tests/test_temple_tileset.gd`; the existing `tests/test_tileset_profile.gd` must accept the new profile

**Interfaces:**
- Consumes: `tools/temple_palette.py` (already in the repo).
- Produces: the named tiles below, readable through `TileArt.coords(&"<name>")` once `TileArt.use_profile(load("res://data/tilesets/temple.tres"))` is called. The profile also maps every standard role in `TileArt.ROLES`/`PATTERNS` to its closest temple tile, following `tools/make_tileset_ruins.gd`.
  - Floors: `floor_a`..`floor_f`, seamless 16 px flagstones in 2×2 or 3×2 slab patterns. Over any 8×8 repeat,
    no single tile may be recognisable.
  - Detail floors: `floor_moss_a/b`, `floor_crack_a/b`, `floor_rune_a`..`floor_rune_d`. The runes are animated:
    `floor_rune_glow` is 4 frames, pulsing in `RUNE_GLOW`.
  - Lava: `lava_a`..`lava_d` (seamless base). `lava_flow` is 8 frames, a slow drift over 16 px with a seamless
    loop. `lava_bubble` is 6 frames: a bubble swells and pops.
  - Lava rim: pattern `lava_rim` (the 47-tile blob set used by `TileArt.blob_tile`, the same mask convention as
    the pond). It is drawn where floor meets lava: a cooled crust in `CRUST_*` with glowing cracks.
    `lava_rim_glow` is 4 frames of the crack pulse.
  - Cliff faces, one row high per level of drop (16 px). There is a set per face depth:
    - `cliff_face_l/m/r` for one row;
    - `cliff_face2_top_l/m/r` and `cliff_face2_bot_l/m/r` for two rows;
    - `cliff_foot_lava_l/m/r`, the last row of a face standing in lava, lit from below in `CLIFF_LAVA_LIT`;
      it has 4 frames of flickering light;
    - `cliff_moss_*` variants with hanging moss.
  - Platform edge tops: pattern `ledge` (blob 47). It is a 1–2 px lighter lip on the high side of every
    height change.
  - Drop shadow: `shadow_s_1`, `shadow_s_2`, semi-transparent dark tiles laid on the lower floor south of a
    face.
  - Stairs, one cell per tile:
    - `stairs_up_steps`, `stairs_up_rail_l`, `stairs_up_rail_r` (climbing north);
    - `stairs_side_steps`, `stairs_side_rail_t`, `stairs_side_rail_b` (climbing east/west, mirrored in code).
  - Bridges:
    - stone: `bridge_stone_deck_h`, `bridge_stone_deck_v`, `bridge_stone_rail_n/s/e/w`, `bridge_stone_post`;
    - wood: `bridge_wood_deck_h/v`, `bridge_wood_rail_n/s/e/w`, `bridge_rope_post`.
  - Animated tiles are stored as consecutive cells in one row. `temple_tiles.json` lists them under
    `"animations": {"<name>": [[c,r],...]}`, and `TilesetProfile` keeps that list
    (`profile.animations: Dictionary`, name → `Array[Vector2i]`). Add this field to `tileset_profile.gd`
    with an empty default so the other profiles are unaffected.
- Produces: `RoomTheme.WallStyle.LAVA` (enum value appended after `ROCKS`) and `data/themes/temple.tres`:
  - `tileset` = temple profile; `floor_tile` = `&"floor_a"`; `wall_style = LAVA`;
  - `world_tint` warm (`Tuning.TEMPLE_WORLD_TINT = Color(1.0, 0.93, 0.86)`, a new constant);
  - `ambient_life = false`.
- `python tools/make_temple_tileset_art.py --preview <folder>` also writes a labelled contact sheet, a
  sample 30×18 composition (lava, two islands at heights 0/1/2 with faces, rims, shadows, stairs and a
  bridge) and GIFs of every animation. The output must be deterministic (fixed seeds).

- [ ] **Step 1: Write `tests/test_temple_tileset.gd`.** It loads the profile and checks:
  - `"every named temple tile exists"`: the tile and pattern names above, all present.
  - `"rim and ledge patterns have 47 tiles"`
  - `"animations have the promised frame counts"`: `lava_flow` 8, `lava_bubble` 6, `floor_rune_glow` 4,
    `lava_rim_glow` 4, `cliff_foot_lava_m` 4.
  - `"temple floors tile without seams"`: for each `floor_*`, the left column of pixels and the right column of
    its neighbour differ by less than a colour-distance threshold of 60 on average. Same top to bottom.
  - `"the sheet uses only the palette"`: every opaque pixel's RGB is in the set built from
    `tools/temple_palette.py` (parse the hex strings from the .py file at test time) or within 1 of one.
  - `"the temple theme uses the LAVA wall style"`
- [ ] **Step 2: Run it. Expect FAIL** (the files are missing).
- [ ] **Step 3: Write the Python tool, then the two `.gd` tools, then the `TilesetProfile.animations` field and
  the enum.** Run the tools:
  - `python tools/make_temple_tileset_art.py --preview <scratch>`
  - `"$GODOT" --headless --path . --script res://tools/make_tileset_temple.gd`
  - same for `make_temple_theme.gd`

  Open the preview composition and the GIFs, then compare them with `templo_mapa.jpg` side by side:
  - the islands must read as raised blocks over lava, with visible faces, rims and drop shadows;
  - the lava must flow and glow.

  Iterate until they do.
- [ ] **Step 4: Run the tests.** Expect `test_temple_tileset` and `test_tileset_profile` to PASS.
  Regression: `test_ruins_tileset test_ruins test_forest_look`.
- [ ] **Step 5: Commit.** Include the tools, the sheet with its `.import` (let Godot generate it), the json, the
  profile, the theme and the test: `feat(art): add the temple tileset, lava and theme`.

---

### Task 3: Temple props art and `TempleProp`

**Files:**
- Create: `tools/make_temple_props_art.py` → `assets/sprites/temple_props/<name>.png`, horizontal frame strips with square or fixed cells, plus `assets/sprites/temple_props/props.json` (name → `{cell: [w,h], frames: n, fps: f, foot: [x,y], footprint: [w,h]}`)
- Create: `scripts/world/temple_prop.gd` (`class_name TempleProp extends Node2D`)
- Test: `tests/test_temple_props.gd`

**Interfaces:**
- Consumes: `tools/temple_palette.py`.
- Produces: `TempleProp`
  - `enum Kind { PILLAR_CARVED, PILLAR_BLOCK, COLUMN_LOW, COLUMN_BROKEN, STATUE_GUARDIAN, BRAZIER, BRAZIER_PEDESTAL, TORCH_WALL, URN, VASE, BARREL, RUBBLE, ROCK_SMOKING, PLANT, VINES, BANNER, LAVA_FALL, GEYSER, FACE_GATE, ALTAR_RUNE, EMBER_VENT }`
  - `@export var kind: Kind`, `@export var flip := false`, `@export var level := 0`
  - Each kind is an `AnimatedSprite2D` child built from its strip. Its frame offset is seeded by
    `hash(Vector2i(global_position))`. The node's origin is the prop's foot, and the prop is y-sorted.
  - Solid kinds (`PILLAR_*`, `COLUMN_*`, `STATUE_GUARDIAN`, `BRAZIER_PEDESTAL`, `URN`, `BARREL`,
    `ROCK_SMOKING`, `FACE_GATE`, `ALTAR_RUNE`) add a `StaticBody2D` on `Heights.block_layer(level)` plus the
    `world` bit when `level == 0`. Its rectangle is `footprint`, centered on the foot, sitting at the base only,
    so Nico can walk behind the top.
  - Flat or overhead kinds (`VINES`, `BANNER`, `LAVA_FALL`, `EMBER_VENT`, `PLANT`, `RUBBLE`) have no collision.
  - Fire kinds (braziers, torch, gate mouth, geyser while erupting, lava fall) add a `RuinLight` glow with
    temple colours. Check `scripts/world/ruin_light.gd` for its API.
  - `GEYSER` cycles idle → rumble → erupt → settle with an `ambient` flag (`@export var hazard := false`). When
    `hazard` is true, erupting activates a `Hitbox` (enemy_attack layer 5, mask 2, damage 1) over its
    footprint. Durations are in `Tuning.TEMPLE_GEYSER_*`.
  - `func blocks_cells() -> Array[Vector2i]` returns the room cells its footprint covers, so the room generator
    can avoid lanes.
- Art list:
  - Every piece has ≥ 4 frames: fire and lava 6–8; stone pieces 4 frames of subtle life (rune glints, moss
    sway, ember flecks rising).
  - Proportions: Nico is 32 px tall; a carved pillar is about 16×56; the guardian statue about 32×48; the face
    gate 80×64 with a lava tongue; a brazier pedestal 16×32; a lava fall 16 wide × 48 tall loop (stackable
    middle) with a splash foot.
- Preview: `--preview <folder>` writes a contact sheet and one GIF per prop.

- [ ] **Step 1: Write `tests/test_temple_props.gd`:**
  - `"every kind builds and animates"`: for each `Kind`, the sprite has ≥ 4 frames and is playing.
  - `"neighbouring props start on different frames"`: two braziers 32 px apart.
  - `"a pillar blocks a low walker at its base and not at its top"`: walk Nico into the base row → stopped; walk
    behind the top row → passes.
  - `"a pillar on level 2 blocks only level-2 actors"`: uses `Heights.set_level`.
  - `"a hazard geyser hurts Nico only while erupting"`: count `Events.player_damaged`.
  - `"vines and banners have no collision"`
- [ ] **Step 2: Run it. Expect FAIL.**
- [ ] **Step 3: Implement the tool and `TempleProp`, then look at the GIFs.** Each prop must read clearly
  at 1× scale on the lava/stone background and match the shapes in the zip's `props_contact_sheet.jpg`
  and `componentes_extraidos.jpg`.
- [ ] **Step 4: Run the tests.** Expect PASS. Regression: `test_ruin_props test_draw_order`.
- [ ] **Step 5: Commit** with `feat(art): add animated temple props`.

---

### Task 4: `TemplePlan`, the pure room plan

**Files:**
- Create: `scripts/world/temple_plan.gd` (`class_name TemplePlan extends RefCounted`, no nodes, no autoloads)
- Test: `tests/test_temple_plan.gd`

**Interfaces:**
- Produces:
  - `static func parse(text: String) -> TemplePlan`, which needs exactly 18 rows of 30 characters.
    `errors: Array[String]` is non-empty when the plan is malformed.
  - Alphabet, one character per 16 px cell:
    - floors: `.` = floor at height 0; `1` = floor at height 1; `2` = floor at height 2;
    - `~` = lava;
    - stairs climb toward the arrow, one level, and the stair cell's height is the low end:
      `^` (climbs north), `>` (east), `<` (west), `v` (south);
    - bridges: `=` = east–west bridge deck; `|` = north–south deck; `b` = bridge deck at height 1;
      `B` = bridge deck at height 2;
    - `#` = solid temple masonry (wall block); `p` = pillar slot (floor of the height of its west neighbour,
      later filled by a `TempleProp`).
    - The outer ring is the room's wall. Door gaps are the 4 middle cells of each edge
      (x 13..16 on top/bottom, y 7..10 on left/right), and they must be floor of the room's base height.
  - `var base_height: int` comes from the door cells (all doors equal, or an error).
  - `func height_at(cell: Vector2i) -> int`: −1 for lava, the deck height for bridges, the low end for stairs,
    99 for masonry.
  - `func is_walkable(cell: Vector2i, level: int) -> bool`
  - `func face_rows(cell: Vector2i) -> int`: how many rows of cliff face are drawn in this cell. A cell directly
    south of a cell `d` levels higher (lava counts as −1) is a face cell for `d` rows. A face cell is not
    walkable at its own height.
  - `func collision_rects(layer: int) -> Array[Rect2]` merges cells into rectangles in room pixels:
    - layer 7 (water bit, used for lava): lava cells and face cells over lava;
    - layer 8: cells of height ≥ 1, plus face cells whose high side is ≥ 1;
    - layer 9: what level 1 may not enter;
    - layer 10: what level 2 may not enter;
    - layer 11: cells of height 2;
    - layer 1 (`world`): masonry `#`.
    - Stair cells are walkable at both their levels. Bridge decks are walkable only at their own height
      (a level-0 deck crosses lava; level-0 actors under a raised deck are blocked by its supports only at
      the ends).
  - `func stairs() -> Array[Dictionary]`: each entry is
    `{cells: Rect2i, direction: Vector2i, low_level: int}`, with adjacent stair cells of the same direction
    merged.
  - `func validate(surge_stages := 0) -> Array[String]`. It returns problems and is empty when the plan is fine:
    - every door is reachable from every other door at base height, walking on walkable cells and changing
      level only through stairs (BFS over `(cell, level)`);
    - every stair has one free walkable cell at its low end and one at its high end;
    - no floor region is a plain rectangle: at least 20% of the inner 28×16 is not base-height floor;
    - the center cross (x 13..16 or y 7..10, from each door to the room's middle) is walkable at base height or
      by stairs;
    - with `surge_stages ≥ 1`: every walkable level-0 cell is ≤ `Tuning.TEMPLE_SURGE_MAX_STAIR_DISTANCE`
      (default 9) steps from a stair up, and the safe level (1 if `surge_stages == 1`, else 2) has ≥ 60
      walkable cells in one connected region.
  - `func spawn_ok(cell: Vector2i) -> bool`: walkable at its own height, not a face cell, not a stair, not
    within 1 cell of lava.
  - `func level_regions() -> Dictionary`: level → `Array[Vector2i]` walkable cells. Used by the surge and the
    generator.

- [ ] **Step 1: Write `tests/test_temple_plan.gd`** with 4 inline plans:
  1. Flat with lava moat and bridges.
  2. Three levels with stairs.
  3. Broken: a door is unreachable.
  4. Surge, two stages.

  Checks:
  - `"a malformed plan reports its row count"`
  - `"lava is height -1 and blocks only on the water layer"`
  - `"a face cell south of a 2-high platform has 2 rows and is not walkable"`
  - `"stairs merge into one zone with low_level and direction"`
  - `"collision on layer 9 excludes level-1 floor and stairs touching level 1"`
  - `"layer 11 holds exactly the height-2 cells"`
  - `"the valid plans validate clean"`
  - `"the broken plan reports the unreachable door"`
  - `"a rectangle-only plan is rejected"`
  - `"the surge plan fails when a level-0 cell is too far from stairs"`: mutate one plan to break it.
  - `"spawn_ok rejects lava, faces, stairs and lava neighbours"`
- [ ] **Step 2: Run it. Expect FAIL.**
- [ ] **Step 3: Implement it.** Rectangle merging: greedy row runs merged downward, as in
  `RuinShape._build_collision`.
- [ ] **Step 4: Run the test.** Expect PASS.
- [ ] **Step 5: Commit** with `feat(world): add the temple room plan with heights and validation`.

---

### Task 5: Enemy roster per run and height-aware room picking

**Files:**
- Create: `scripts/world/enemy_roster.gd` (`class_name EnemyRoster extends RefCounted`, pure)
- Modify: `scripts/world/scenario_data.gd` (`@export var roster_size := 0` in group Population), `scripts/world/room_data.gd` (`@export var enemy_affinity: Dictionary = {}`; `@export_range(0, 2) var height`), `scripts/world/level.gd` (only `generate()` and `_populate()`), `scripts/world/map_generator.gd` (`_assign_rooms`/`_pick_room`)
- Test: `tests/test_enemy_roster.gd`; extend `tests/test_map_generator.gd`

**Interfaces:**
- Produces:
  - `static func EnemyRoster.pick(pool: Array[PackedScene], size: int, map_seed: int, base_weights: Dictionary, plan: DirectorPlan) -> Array[PackedScene]`
    - It draws `size` distinct scenes without replacement, weighted by `base_weights[id] * plan.enemy_weight(id)`
      (a missing id counts as 1), using an RNG seeded with `map_seed + 3`.
    - `size <= 0` or `size >= pool.size()` returns the whole pool in its original order.
    - An enemy id is the scene file name.
  - `Level.roster: Array[PackedScene]` is set in `generate()` after the plan. `_populate` passes it to
    `room.spawn_enemies` instead of `scenario.enemy_pool`.
  - The base weights for a room are `scenario.enemy_weights` multiplied by `cell.room_data.enemy_affinity`
    (per id), passed as `base_weights`.
  - `MapGenerator`: when picking a room for a cell, rooms whose `height` differs by more than 1 from an
    already-assigned connected neighbour get weight 0. If every candidate is 0, the generator falls back to
    the candidates at the neighbour's height, then to any. The start and boss rooms are fixed. A
    `layout.validate()` problem `"height step > 1 between <a> and <b>"` is added to `MapLayout.validate()`.
- Data: `temple.tres` will set `roster_size = 10` (Task 9). Forest and ruins keep 0 (unchanged).

- [ ] **Step 1: Write the tests.**
  - `test_enemy_roster`:
    - `"size 0 keeps the whole pool"`
    - `"a roster has size distinct enemies"`
    - `"same seed same roster"`
    - `"different seeds give different rosters over 20 seeds"`: at least 15 distinct sets.
    - `"weight 0 never picked"`
    - `"heavier enemies appear more often over 500 seeds"`
    - `"room affinity multiplies the scenario weight"`: unit test on the helper that builds `base_weights`.
      Expose it as `static func EnemyRoster.room_weights(scenario_weights: Dictionary, affinity: Dictionary) -> Dictionary`.
  - `test_map_generator` additions:
    - `"no corridor joins rooms two levels apart over 200 seeds"`: a synthetic scenario with rooms of heights
      0, 1 and 2.
    - `"forest and ruins layouts are unchanged for seeds 1..20"`: compare `room_data.id` per cell against a
      table computed before your change. Generate the table first with the old code.
- [ ] **Step 2: Run them. Expect FAIL.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expect PASS. Regression: `test_enemy_mix test_level_build test_chapters test_director test_ruins`.
- [ ] **Step 5: Commit** with `feat(world): pick a per-run enemy roster and keep room heights adjacent`.

---

### Task 6: `TempleShape`, the room that draws and collides (Wave B)

**Files:**
- Create: `scripts/world/temple_shape.gd` (`class_name TempleShape extends Node2D`, node named `Shape` in a room)
- Modify: `scripts/world/room.gd` (LAVA wall style: plant no wall art and hide the walls drawn by the shape; `height_at(local: Vector2) -> int`), `scripts/enemies/enemy.gd` (`_ready`: take `get_parent().height_at(position)` when the parent has it)
- Test: `tests/test_temple_shape.gd`

**Interfaces:**
- Consumes:
  - `TemplePlan` (Task 4);
  - the profile and tiles of Task 2 (`TileArt.coords`, `profile.animations`, `TileArt.blob_tile` with `lava_rim`/`ledge`);
  - `TempleProp` (Task 3);
  - `Heights` (Task 1);
  - `StairZone.low_level`.
- Produces:
  - `@export_multiline var rows := ""` and `var plan: TemplePlan`.
  - `func hides_wall_at(cell: Vector2i) -> bool` is true for every border cell that is not a door gap (the
    island floats in lava). `Room._without_hidden` must accept a `TempleShape` too: duck-typed via
    `has_method("hides_wall_at")`.
  - `Room.height_at(local: Vector2) -> int`: the shape's `plan.height_at(cell)` clamped to ≥ 0, else `height`.
  - Built layers, bottom to top, all at `FLOOR_Z` with the order fixed by child order:
    1. `Lava`: animated `lava_flow` frames (TileSet atlas animation), with `lava_bubble` scattered on about 4% of
       the cells and random phase.
    2. `Faces`: cliff faces per `plan.face_rows`. The foot row is `cliff_foot_lava_*` where the face stands in
       lava, and moss variants appear on 25% of the cells.
    3. `Floor0`, `Floor1`, `Floor2`: flagstones per height, with detail floors (moss, cracks, runes) away from
       the door lanes.
    4. `Rims`: `lava_rim` blob plus `lava_rim_glow` animation.
    5. `Ledges`: the `ledge` blob on the high side of every height change.
    6. `Shadows`: `shadow_s_*` on the lower floor south of each face.
    7. `Stairs` and `Bridges`: deck tiles. Rails are upright and y-sorted at z 0.
  - Collision: one `StaticBody2D` per layer from `plan.collision_rects(layer)` (layers 1, 7, 8, 9, 10, 11).
  - Stairs: one `StairZone` per `plan.stairs()` entry, with `low_level` set.
  - `p` cells: a `TempleProp` `PILLAR_CARVED` (or `PILLAR_BLOCK` by seeded coin) on that cell's level.
  - Light: a `RuinLight` in lava colour at about 1 per 12 lava cells along the rims, flickering.
  - Ambient: an `EMBER_VENT` prop on lava cells (about 1 per 40), with embers rising over every layer at
    z 0, y-sorted. Values are in `Tuning.TEMPLE_*`.

- [ ] **Step 1: Write `tests/test_temple_shape.gd`.** Build a room scene in code: `room_base.tscn` plus a
  `Shape` with a 3-level plan, theme temple. Checks:
  - `"layers exist in draw order"`
  - `"lava cells are animated tiles"`
  - `"a low Nico cannot walk into lava; a level-1 Nico on the platform cannot walk off its edge"`
  - `"walking up the stairs makes Nico level 1, then level 2"`
  - `"an enemy placed on a level-2 cell is level 2"`: `Enemy._ready` via `height_at`.
  - `"a low arrow stops at the platform face; a level-1 arrow flies over lava"`
  - `"no wall art is planted on hidden borders"`
- [ ] **Step 2: Run it. Expect FAIL.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expect PASS.
  Regression: `test_heights test_ruin_shape test_rock_wall test_draw_order test_enemy_territory`.
- [ ] **Step 5: Commit** with `feat(world): build temple rooms over lava with three heights`.

---

### Task 7: Level integration: bridges, stairs and the lava sea (Wave B)

**Files:**
- Create: `scripts/world/lava_backdrop.gd` (`class_name LavaBackdrop`, `static func build(parent, area: Rect2i, walkable: Dictionary, taken: Dictionary, map_seed: int)` like `RockBackdrop.build`)
- Modify: `scripts/world/level.gd` (`_paint_corridor`, `_dress_stairs`, `_build_backdrop`, `_build_boundary` branches for `WallStyle.LAVA`)
- Test: `tests/test_temple_corridors.gd`

**Interfaces:**
- Consumes: Task 2 tiles, Task 3 props, `StairZone.low_level` (Task 1).
- Produces:
  - With `wall_style == LAVA`:
    - A same-height corridor is a stone bridge over lava: lava under the whole corridor rectangle, a deck on the
      floor rect, `bridge_stone_rail_*` on the wall rects (the near/south rail upright and y-sorted, the rest
      flat) and a post at each end.
    - A height-changing corridor uses the temple stair tiles with `low_level = min(from, to)`, between rails,
      with a `BRAZIER_PEDESTAL` at the top on each side.
    - Collision keeps using the corridor's wall rects.
  - `LavaBackdrop`:
    - the whole area outside rooms and corridors is animated lava;
    - islets of rock with cliff faces (sizes 2×2 to 5×4 cells, never touching a room or corridor);
    - `LAVA_FALL` props on the north edge of the map and on islets;
    - smoking rocks, ember vents;
    - painted in chunks like `RockBackdrop`, with a darker crust tint farther from the rooms;
    - `Tuning.TEMPLE_BACKDROP_*`.
  - Map boundary: solid collision around the bounds (same as the other styles).
- [ ] **Step 1: Write `tests/test_temple_corridors.gd`.** Build a `Level` on a tiny synthetic 2×2 scenario
  using the temple theme, with test rooms built from `TempleShape` plans at heights 0/1. Checks:
  - `"a same-height corridor is a bridge with lava under it"`
  - `"a height-changing corridor has a StairZone with low_level 0"`
  - `"Nico crosses the bridge and cannot step off it into lava"`
  - `"the backdrop covers the outside with animated lava and never overlaps a room"`
- [ ] **Step 2: Run it. Expect FAIL.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expect PASS.
  Regression: `test_stairs_corridor test_level_build test_ruins test_forest test_draw_order`.
- [ ] **Step 5: Commit** with `feat(world): join temple rooms with bridges and stairs over a lava sea`.

---

### Task 8: Lava surge (Wave B)

**Files:**
- Create: `scripts/world/lava_surge_logic.gd` (`class_name LavaSurgeLogic extends RefCounted`, pure), `scripts/world/lava_surge.gd` (`class_name LavaSurge extends Node2D`, child of a room)
- Modify: `scripts/core/events.gd` (`signal lava_surge_started(room: Node, stage: int)`, `signal lava_surge_receded(room: Node)`), `scripts/world/room_data.gd` (group "Surge": `@export_range(0, 2) var surge_stages := 0`, `@export var kills_stage_1 := 5`, `@export var kills_to_recede := 5`, `@export var wave_size := 2`, `@export var max_alive := 5`), `data/ui/texts.json` (`temple_surge_warning` "¡La lava sube! Busca terreno alto.", `temple_surge_rising` "La lava sigue subiendo…", `temple_surge_receding` "La lava retrocede."), `scripts/core/tuning.gd` (`TEMPLE_SURGE_WARN_SECONDS = 2.5`, `TEMPLE_SURGE_RISE_SECONDS = 3.0`, `TEMPLE_SURGE_RECEDE_SECONDS = 2.5`, `TEMPLE_SURGE_DAMAGE_INTERVAL = 0.8`, `TEMPLE_SURGE_DAMAGE = 1`, `TEMPLE_SURGE_WAVE_INTERVAL = 4.0`, `TEMPLE_SURGE_SPAWN_WARN = 0.8`, `TEMPLE_SURGE_TRIGGER_DEPTH = 64.0`, `TEMPLE_SURGE_MAX_STAIR_DISTANCE = 9`, `TEMPLE_SURGE_ENABLED = true`) (the same constant may already exist from Task 4: keep one)
- Test: `tests/test_lava_surge.gd`

**Interfaces:**
- Consumes: `TemplePlan.level_regions()`, `spawn_ok()` (Task 4); `TempleShape.plan` and the tiles (Tasks 2, 6, merged before this task finishes; until then, test with a `TempleShape` built from an inline plan); `Room.pick_enemies`, `Room.register_enemy`, `Level.roster` (Task 5).
- Produces:
  - `LavaSurgeLogic`:
    - `enum State { IDLE, WARNING, RISING, FIGHT, RECEDING, DONE }`, `var state`, `var stage: int` (number of
      levels flooded: 0..2), `var kills: int`.
    - `func _init(stages: int, kills_stage_1: int, kills_to_recede: int)`
    - `func start()`: IDLE → WARNING.
    - `func step(delta: float) -> Array[StringName]` advances timers (Tuning) and returns events from
      `&"warn"`, `&"rise"`, `&"risen"`, `&"spawn_wave"`, `&"recede"`, `&"receded"`.
    - `func on_kill()`: lava kills are not reported to it.
    - Sequence: WARNING → RISING (stage = 1) → FIGHT. If `stages == 2` and kills reach `kills_stage_1`:
      WARNING → RISING (stage = 2) → FIGHT with kills reset. When kills reach `kills_to_recede`: RECEDING
      (stage goes down one level per `RECEDE_SECONDS`) → DONE.
    - During FIGHT it emits `&"spawn_wave"` every `WAVE_INTERVAL` while kills are below the target.
    - `func flooded_levels() -> int` returns `stage`.
  - `LavaSurge` (added by `Level._populate` to every room whose `room_data.surge_stages > 0`, only if
    `Tuning.TEMPLE_SURGE_ENABLED`):
    - Trigger: Nico's body inside the room more than `TRIGGER_DEPTH` px from every door.
    - Doors seal: a `StaticBody2D` on `world` in each open door gap, with `TempleProp` `FACE_GATE`-style fire bars
      animated (reuse the brazier flame strip if no bar art exists).
    - Flood visual: an overlay `TileMapLayer` at `GROUND_FX_Z` per flooded level. Cells fill in BFS order from
      the lava-touching cells over `RISE_SECONDS`, with the rim tile on the frontier and full lava behind it,
      and empty in reverse on recede. Steam/smoke props spawn on receding cells for 2 s.
    - Damage: a timer every `DAMAGE_INTERVAL` damages every Hurtbox owner in the room that is on a flooded
      level, standing on a cell of that level (`plan.height_at` < `flooded_levels()`), and not
      `Heights.is_flyer`. It uses a dedicated `Hitbox` child with player and enemy masks, moved and activated
      per target. Damage is `TEMPLE_SURGE_DAMAGE`.
    - Kills counted: `Events.enemy_killed` for enemies of this room that were not killed by lava (track the
      lava victims in a set).
    - Waves: `wave_size` enemies from `Level.roster` (fallback `scenario.enemy_pool`) via `Room.pick_enemies`,
      at `spawn_ok` cells of the final safe level that are ≥ 4 cells from Nico. Never more than `max_alive`
      alive. A warning ring (`GROUND_FX_Z`, lava colours) shows for `SPAWN_WARN` seconds before each spawn.
    - Initial enemies of a surge room: `Level._populate` places them only on `spawn_ok` cells of the final
      safe level.
    - Events: `lava_surge_started(room, stage)` on each rise, `lava_surge_receded(room)` at DONE; messages
      through `Events.message_requested(UiText.t(...))`. The doors open when DONE **and** the room is cleared
      (Room's existing cleared logic).
- [ ] **Step 1: Write `tests/test_lava_surge.gd`.**
  - Pure logic:
    - `"one-stage surge: warn, rise, fight, recede, done"`
    - `"two-stage surge rises to stage 2 after kills_stage_1"`
    - `"waves are requested every interval only during FIGHT"`
    - `"lava kills do not advance the surge"`
  - With nodes (a 2-stage plan room):
    - `"entering deep triggers and seals the doors"`
    - `"Nico on level 0 takes 1 damage per interval after the rise, none on level 1"`
    - `"Nico on level 0 can walk to the stairs and climb while flooded"`: drive input for ≤ 3 s and assert his
      level becomes ≥ 1.
    - `"waves spawn only on the safe level and never within 4 cells of Nico"`
    - `"a level-0 grunt burns, its death does not count"`
    - `"after kills_to_recede and clearing, the doors open and the overlay is empty"`
- [ ] **Step 2: Run it. Expect FAIL.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expect PASS. Regression: `test_enemy_mix test_hud test_game_feel test_save_menu`.
- [ ] **Step 5: Commit** with `feat(world): add the temple lava surge`.

---

### Task 9: Temple rooms, scenario and chapter wiring (Wave C)

**Files:**
- Create:
  - `tools/make_temple_rooms.py` → `scenes/levels/rooms/temple/<id>.tscn`
  - `tools/make_temple_data.gd` → `data/rooms/temple_<id>.tres` and `data/scenarios/temple.tres`
  - `scenes/levels/temple_level.tscn` (copy of `ruins_level.tscn` with the temple scenario)
  - `tools/snapshot_temple.gd` (windowed; saves screenshots of every room type and one whole-map overview to `user://snapshots/temple/`)
- Modify: `data/scenarios/ruins.tres` (`next_scenario = temple`); move `end_after_last_chapter` behaviour so the temple is the last chapter (check `tests/test_ending.gd`)
- Test: `tests/test_temple.gd`; make sure `tests/test_room_designs.gd`, `test_map_generator.gd` and `test_chapters.gd` cover the temple scenario

**Interfaces:**
- Consumes: everything above.
- Rooms: plans written by the Python tool. Each room scene has `room_base.tscn` as its base plus `Shape` (`TempleShape`), `TempleProp` nodes, markers (`PlayerSpawn`, `EnemySpawns` with ≥ 6 points on `spawn_ok` cells, `BossSpawn`/`ExitSpawn`, `ChestSpawn`, `NpcSpawn`, `SpecialSpawn` as needed). The tool validates every plan with the same rules as `TemplePlan.validate` (port them to Python, or call Godot), checks markers with `spawn_ok`, and refuses to write an invalid room. Room set:

  | id | type | base h | tags | notes |
  |---|---|---|---|---|
  | `start` | START | 0 | — | wide island; the bridge in is the bottom door |
  | `boss` | BOSS | 1 | — | big raised arena, face gate north, braziers ring |
  | `pillar_court` | COMBAT | 0 | `court` | the reference's central court: 4 pillars, rune floor, stairs to a level-1 gallery |
  | `isles` | COMBAT | 0 | `bridges` | 3–4 islands joined by stone/wood bridges, one isle only by bridge |
  | `terraces` | COMBAT | 0 | `heights` | stepped 0→1→2 with side stairs |
  | `trap_walk` | COMBAT | 0 | `traps` | narrow walkway, spikes, saw and rolling-rock props (hazard geysers) |
  | `lava_falls` | COMBAT | 1 | `falls` | raised room, lava falls down the north face |
  | `surge_basin` | COMBAT | 0 | `surge` | 1 stage: sunken level-0 basin, level-1 ring |
  | `surge_tiers` | COMBAT | 0 | `surge` | 2 stages: 0/1/2 tiers, the level-2 top is the safe fight |
  | `surge_bridges` | COMBAT | 0 | `surge` `bridges` | 2 stages: level-1 bridges become the escape, level-2 isle the safe zone |
  | `sanctum` | REWARD | 0 | `bridges` | chest on an isle reachable only by one bridge |
  | `event` | EVENT | 0 | — | quiet shrine (no NPC yet) |
  | `special` | SPECIAL | 0 | — | altar room (no NPC yet) |

- Scenario `temple.tres`:
  - `id = &"temple"`, `display_name = "Templo del Eclipse"`, `chapter_title = "El templo conoce tu destino."`;
  - `grid_size = Vector2i(5, 6)`, `min_main_path = 7`, `max_main_path = 12`, `side_rooms = 4`,
    `reward_rooms = 2`;
  - `theme = temple`;
  - `enemy_pool` = the 25 temple enemy scenes listed in `CLAUDE.md` "Temple enemies (island 3)" (not
    `cria_volcanica`/`reina_volcanica`, which `nucleo_cria` brings);
  - `roster_size = 10`;
  - `boss_scene = ancient_guardian.tscn`, `objective_flag = &"temple_boss_defeated"`, objective texts in Spanish;
  - drops and chests like the ruins;
  - room weights: `surge` rooms 2.0 each;
  - `completion_text` in Spanish;
  - no `next_scenario`.
- Director: add temple room tags to the rule table only if `data/ai/director_rules.tres` keys by tag. Use
  `tools/make_director_data.gd`; never code.
- Enemy needs: for each of the 25, run it in `enemy_arena.tscn` logic placed inside `pillar_court` (a headless
  check in `test_temple`: spawn, step 3 s, no `SCRIPT ERROR`, still inside the room, not in lava). Where an
  enemy needs room features (water for `manta_hollin` → it flies over lava; bridges for `gusano_puentes`),
  set `enemy_affinity` on the fitting rooms rather than changing the enemy.

- [ ] **Step 1: Write `tests/test_temple.gd`:**
  - `"temple scenario loads with 25 enemies and roster 10"`
  - `"every temple room plan validates and every marker is spawn_ok"`
  - `"seeds 1..30 build a full temple map without errors, every room reachable from the start"`: BFS over room
    doors and corridors, with the stairs' levels.
  - `"at least one surge room appears in 25 of 30 seeds"`
  - `"each of the 25 enemies runs 3 s in a temple room without leaving it or entering lava"`
  - `"ruins lead to the temple"`
  - `"the temple ends the journey"`

  Add the temple scenario to the scenario lists in `test_room_designs.gd`, `test_map_generator.gd` and
  `test_chapters.gd`.
- [ ] **Step 2: Run them. Expect FAIL.**
- [ ] **Step 3: Write the tools, generate the rooms and data, and run `tools/snapshot_temple.gd` with a window**
  (`"$GODOT" --path . --script res://tools/snapshot_temple.gd`). Open the screenshots and compare them with
  `docs/referencias/templo_mapa.jpg`. Fix any room that reads flat, square or empty.
- [ ] **Step 4: Run the full suite** (`./tools/run_tests.sh`). Expect "All tests passed."
- [ ] **Step 5: Commit** with `feat(world): add the Templo del Eclipse scenario and its rooms`.

---

### Task 10: Polish pass, docs and final verification (Wave D)

**Files:**
- Modify: whatever the screenshot review shows; `docs/JUEGO.md` (temple: three heights, platforms over lava, surge), `docs/TAREAS.md` §11 (tick the tileset, rooms with traps, enemies placed; reword "sin plataformas flotantes"), `CLAUDE.md` (sections for the temple theme and art, `TemplePlan`/`TempleShape`, Heights with 3 levels and layers 10/11, `LavaSurge`, `EnemyRoster`, temple scenario, regeneration order), `README.md` only if a run step changed.

- [ ] **Step 1:** Run `tools/snapshot_temple.gd` on 3 seeds and run `tools/playtest_bot.gd` on 3 seeds of
  `temple_level.tscn`. Note any room where the bot gets stuck, any spawn in lava, and any static or flat-looking
  area.
- [ ] **Step 2:** Fix every finding in its own owning file.
- [ ] **Step 3:** Update the docs as listed above.
- [ ] **Step 4:** Run the full suite. Expect "All tests passed." Also start `temple_level.tscn` once windowed
  and check the console for errors and warnings.
- [ ] **Step 5: Commit** with `docs(world): document the temple chapter` (and `fix(...)` commits for the
  polish fixes).
