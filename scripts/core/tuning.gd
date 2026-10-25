class_name Tuning
extends RefCounted
## The one place for the values added in the level-1 polish pass (see docs/PULIDO_LOG.md): how
## enemies keep to their rooms and share the chase, and the look and "game feel" of the forest.
## Gameplay data (enemy stats, rooms, the director's rules) stays in `data/`; these are pacing and
## presentation limits. Every effect can be switched off here.

# --- Enemies ---------------------------------------------------------------------------------------
## A patrol point stays this far inside the enemy's room (px), so patrols do not walk into the walls.
const PATROL_MARGIN := 24.0
## A patrol leg gives up after this many times its expected walking time (blocked by a tree or rock).
const PATROL_TIMEOUT_FACTOR := 2.0
## A patrol that barely moves for this long (s) is blocked: the enemy rests and picks another point.
const PATROL_STALL_TIME := 0.4
## Enemies keep to their room: they hunt Nico while he is inside it or this far past its edge (px;
## a corridor is 48 px long) and walk back home when he leaves.
const TERRITORY_MARGIN := 40.0
## At most this many enemies hunt Nico at once, and at most this many of one kind (a bat group);
## the others keep patrolling until a place frees up. Bosses do not count.
const MAX_HUNTERS := 4
const MAX_HUNTERS_OF_A_KIND := 3
## Hand-placed spawn markers of a room are at least this far apart (checked by tests/test_enemy_pack.gd).
const MIN_SPAWN_DISTANCE := 48.0
## Prints what each enemy decides (starts or stops hunting, goes back home), for debugging.
const ENEMY_DEBUG_LOG := false
## Boss eruptions (roots) stay this far inside the arena's outer edge (px): the wall is 16 px thick.
const ARENA_MARGIN := 24.0

# --- Forest look -----------------------------------------------------------------------------------
## The deep forest drawn around (and between) the rooms, so no black shows anywhere.
const BACKDROP_ENABLED := true
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

# --- Game feel -------------------------------------------------------------------------------------
## Frames the game freezes when Nico lands a hit (0 = off).
const HITSTOP_FRAMES := 3
## Camera shake when Nico is hurt: strength in px and duration in s (strength 0 = off).
const SHAKE_STRENGTH := 2.0
const SHAKE_DURATION := 0.15
## Particles when an enemy dies (0 = off), how long they last and their base color.
const DEATH_PARTICLES := 10
const DEATH_PARTICLE_LIFETIME := 0.45
const DEATH_PARTICLE_COLOR := Color(0.18, 0.14, 0.24)
## A dark ring around warning circles and skill areas, so they read on the bright grass (0 = off).
const ZONE_OUTLINE_ALPHA := 0.55
## Dark outline around the HUD's text, so it reads over the bright forest floor (0 = off).
const HUD_TEXT_OUTLINE := 3
const HUD_TEXT_OUTLINE_COLOR := Color(0.05, 0.07, 0.05, 0.85)
