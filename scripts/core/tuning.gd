class_name Tuning
extends RefCounted
## The one place for the values of the level-1 polish: how enemies keep to their rooms, the look of
## the forest, the special rooms, the tileset profile and the boss arena. Gameplay data (enemy stats, rooms, the director's rules)
## stays in `data/`; these are presentation limits. Every effect can be switched off here.

# --- Enemies (every enemy that lives in a room, whatever the level) ------------------------------------
## Enemies keep to their room: they hunt Nico while he is inside it or this far past its edge (px;
## a corridor is 48 px long) and walk back home when he leaves.
const TERRITORY_MARGIN := 40.0
## A patrol point stays this far inside the enemy's room (px), so patrols do not walk into the walls.
const PATROL_MARGIN := 24.0
## A patrol leg gives up after this many times its expected walking time.
const PATROL_TIMEOUT_FACTOR := 2.0
## A patrol that covers less than this share of its expected distance over PATROL_STALL_TIME (s) is
## blocked by a tree or a rock: the enemy rests and picks another point. The window is longer than a
## slime's hop, so moving in hops does not count as blocked.
const PATROL_STALL_TIME := 0.6
const PATROL_STALL_PROGRESS := 0.25
## An attack that moves the enemy (a lunge, a charge) stops this far inside its room (px), so no
## attack carries it into another room.
const DASH_ROOM_MARGIN := 20.0
## Seconds an enemy waits, after its hurt, before warning again when a hit or a push cut its attack
## short (0 = off).
const INTERRUPTED_ATTACK_COOLDOWN := 0.6
## Prints what each enemy decides (goes back home), for debugging.
const ENEMY_DEBUG_LOG := false

# --- Boss ----------------------------------------------------------------------------------------
## Boss eruptions (roots) stay this far inside the arena's outer edge (px): the wall is 16 px thick.
const ARENA_MARGIN := 24.0

# --- Forest look -----------------------------------------------------------------------------------
## The deep forest drawn around (and between) the rooms, so no black shows anywhere.
const BACKDROP_ENABLED := true
## Dark trees and canopies from `scripts/world/forest_boundary.gd` around the map (branch diseño-de-paisajes).
const FOREST_BOUNDARY_ENABLED := true
## How far the forest reaches beyond the map's rooms, in tiles.
const BACKDROP_MARGIN_TILES := 12
## Brightness of the forest by distance to the nearest room or corridor (tiles): near, middle, far.
const BACKDROP_BAND_LIMITS: Array[int] = [3, 7]
const BACKDROP_BAND_TINTS: Array[Color] = [
	Color(0.62, 0.7, 0.62), Color(0.47, 0.54, 0.5), Color(0.34, 0.4, 0.38)]
## Chance of a tree, bush or rock on a forest tile, by band: thicker next to the paths.
const BACKDROP_BAND_DENSITY: Array[float] = [0.7, 0.5, 0.38]
## Irregular patches of textured grass on room floors: noise frequency and how much is covered.
const GRASS_PATCH_FREQUENCY := 0.09
const GRASS_PATCH_THRESHOLD := 0.28
## Small natural groups of ground details (mushrooms, stones, a stump) per room.
const DETAIL_GROUPS_PER_ROOM := 5
const DETAIL_GROUP_SIZE := Vector2i(2, 4)
## Soft dirt edges on paths (the nine-slice dirt patch of the sheet) instead of square tiles.
const SOFT_PATH_EDGES := true
## A light tint over the whole world (not the HUD); white = off.
const WORLD_TINT_ENABLED := true
const WORLD_TINT := Color(0.95, 0.97, 0.95)
## Full-screen pass over the world: a little less saturation and a soft vignette.
const SCREEN_GRADE_ENABLED := true
const DESATURATION := 0.12
const VIGNETTE_STRENGTH := 0.32
## Where the vignette starts darkening, from the center (0) to the corners (1).
const VIGNETTE_START := 0.6
## A soft ellipse under Nico, enemies and NPCs.
const SHADOWS_ENABLED := true
const SHADOW_ALPHA := 0.28
const SHADOW_WIDTH_FACTOR := 0.7
const SHADOW_HEIGHT_FACTOR := 0.35

## Quiet life around the camera, at ground level (under every actor): fireflies drifting and leaves
## falling. Counts are particles alive at once (0 = off).
const AMBIENT_LIFE_ENABLED := true
const FIREFLIES := 10
const FIREFLY_COLOR := Color(1.0, 0.96, 0.66, 0.85)
const FALLING_LEAVES := 5
const LEAF_COLOR := Color(0.78, 0.52, 0.22, 0.85)
## Sizes in world pixels; 1 px was too small to be seen at all.
const FIREFLY_SIZE := 2.0
const LEAF_SIZE := Vector2(2.0, 3.0)
## Building a map takes about 0.4 s (and its first frame is the slowest): it happens behind a black
## veil that fades out, then in once the map has drawn a few frames (seconds; 0 = no veil).
const MAP_VEIL_FADE_OUT := 0.3
const MAP_VEIL_FADE_IN := 0.45
const MAP_VEIL_HOLD_FRAMES := 3

# --- Warnings --------------------------------------------------------------------------------------
## A dark ring around warning circles and skill areas, so they read on the bright grass (0 = off).
const ZONE_OUTLINE_ALPHA := 0.55

# --- Tileset ---
## A pack whose tiles are not 16 px (e.g. 32x32): true scales each tile to one 16 px cell of the world
## grid, so rooms, props and collision stay the same size (see docs/GUIA_TILESET.md). False = tiles
## are drawn at their own size (the current 16 px pack is unaffected either way).
const TILESET_FIT_TO_GRID := false

# --- Special rooms and exits ---
## Decoration of the boss arena, the reward glade and the event camp (RoomDressing). False = off.
const ROOM_DRESSING_ENABLED := true
## Boss arena: shade over its floor (alpha 0 = off), roots lying on it (0 = off), standing stones
## around it (0 = off) and torches at its doors.
const BOSS_ARENA_SHADE := Color(0.06, 0.04, 0.03, 0.4)
const BOSS_ARENA_ROOTS := 6
const BOSS_ROOT_COLOR := Color(0.26, 0.17, 0.09, 0.5)
const BOSS_STONES := 14
const DOOR_TORCHES := true
const TORCH_FLICKER_FPS := 4.0
## Warm light on the ground around each torch (alpha 0 = off), radius in px.
const TORCH_LIGHT := Color(1.0, 0.65, 0.3, 0.3)
const TORCH_LIGHT_RADIUS := 26.0
## Reward glade: light around the chest (alpha 0 = off), radius in px, and flowers around it.
const GLADE_LIGHT := Color(1.0, 0.92, 0.6, 0.3)
const GLADE_LIGHT_RADIUS := 84.0
const GLADE_FLOWERS := 8
## Event camp: the campfire's flickering light (alpha 0 = off), radius in px, and a signpost.
const CAMPFIRE_LIGHT := Color(1.0, 0.6, 0.28, 0.35)
const CAMPFIRE_LIGHT_RADIUS := 64.0
const CAMP_SIGN := true
## Exit portal: a stone base always visible (so the way out reads before the boss falls) and, once
## open, light on the ground and rising sparks (0 = off).
const PORTAL_BASE := true
const PORTAL_LIGHT := Color(0.7, 0.45, 1.0, 0.35)
const PORTAL_LIGHT_RADIUS := 40.0
const PORTAL_SPARKS := 10
