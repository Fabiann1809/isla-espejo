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
## Dark trees and canopies from `scripts/world/forest_boundary.gd` around the map (branch
## diseño-de-paisajes). Off: the backdrop covers it completely, so it only cost time.
const FOREST_BOUNDARY_ENABLED := false
## How far the forest reaches beyond the map's rooms, in tiles: the camera never looks past the
## rooms, so only enough for the crowns that lean in.
const BACKDROP_MARGIN_TILES := 3
## Trees of the deep forest: spacing of their scattered spots (px), how far each spot wanders from
## its place (px), the chance that a spot gets a tree, how many px of a tree's picture (its
## transparent edge) may lie over a room or corridor, and the size of the pictures they are painted
## into (px).
const BACKDROP_TREE_STEP := 20.0
const BACKDROP_TREE_JITTER := 6.0
const BACKDROP_TREE_DENSITY := 0.92
const BACKDROP_TREE_OVERLAP := 3.0
const BACKDROP_CHUNK := 512
## The forest's darker floor (Level's ForestShade): its color, how dark under the trees, how dark at
## a clearing's edge, how many tiles it fades over into the clearing, how much that edge wobbles
## (tiles) and how fast.
const FOREST_SHADE_COLOR := Color(0.02, 0.09, 0.05)
const FOREST_SHADE_ALPHA := 0.42
const FOREST_SHADE_EDGE_ALPHA := 0.3
const FOREST_SHADE_DEPTH := 2.5
const FOREST_SHADE_WOBBLE := 1.4
const FOREST_SHADE_FREQUENCY := 0.15
## Irregular patches of textured grass on room floors: noise frequency and how much is covered.
const GRASS_PATCH_FREQUENCY := 0.09
const GRASS_PATCH_THRESHOLD := 0.28
## Small natural groups of ground details (mushrooms, stones, a stump) per room.
const DETAIL_GROUPS_PER_ROOM := 5
const DETAIL_GROUP_SIZE := Vector2i(2, 4)
## Share of the rooms' bushes that are boulders of the forest art set instead.
const BUSH_ROCK_CHANCE := 0.3
## How far a bush's picture may wander from its tile's middle (px), so bushes side by side do not
## line up like a hedge.
const BUSH_NUDGE := Vector2(3, 2)
## How far above a tile's bottom the floor details of the forest art stand (px).
const DETAIL_FOOT_LIFT := 3.0
## Trees on the walls of the rooms and corridors: distance between them, how far each one wanders
## from its place and how far behind the top wall's front row its back row stands (px).
const WALL_TREE_STEP := 18.0
const WALL_TREE_JITTER := 2.0
const WALL_TREE_BACK_ROW := 9.0
## Rock columns on the walls of the rooms and corridors of the Ruinas: distance between them, how far
## each one wanders from its place (px), how far behind the top wall's front row its back row stands,
## and the share of taller columns.
const ROCK_WALL_STEP := 11.0
const ROCK_WALL_JITTER := 3.0
const ROCK_WALL_BACK_ROW := 8.0
const ROCK_WALL_TALL_CHANCE := 0.25
## The blocking part of a bush, rock or stump of the forest art (ForestArt.footprint): how much
## narrower than the picture, and its smallest and largest size (px).
const PROP_FOOT_INSET := 2.0
const PROP_FOOT_MIN := Vector2(6, 4)
const PROP_FOOT_MAX := Vector2(14, 7)
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

# --- Ruinas: light and darkness ---
## Soft additive light around torches, braziers and crystals (alpha 0 = off), radius in px, and the
## draw order of lights over the shade of a dark room (both over every actor).
const RUIN_LIGHTS_ENABLED := true
const RUIN_TORCH_LIGHT := Color(1.0, 0.62, 0.25, 0.38)
const RUIN_TORCH_LIGHT_RADIUS := 44.0
const RUIN_BRAZIER_LIGHT := Color(1.0, 0.6, 0.22, 0.45)
const RUIN_BRAZIER_LIGHT_RADIUS := 70.0
const RUIN_CRYSTAL_LIGHT := Color(0.35, 0.78, 1.0, 0.36)
const RUIN_CRYSTAL_LIGHT_RADIUS := 60.0
## How far a light's strength wanders while it flickers (share of its alpha) and how often it does.
const RUIN_LIGHT_FLICKER := 0.2
const RUIN_LIGHT_FLICKER_SECONDS := 0.5
const RUIN_DARK_Z := 4
const RUIN_LIGHT_Z := 5
## A dark room: shade over the whole room (alpha 0 = off) and the glow that follows Nico inside it.
const RUIN_DARK_SHADE := Color(0.02, 0.04, 0.12, 0.52)
const RUIN_PLAYER_LIGHT := Color(0.85, 0.92, 1.0, 0.3)
const RUIN_PLAYER_LIGHT_RADIUS := 64.0

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

# --- Game feel (GameFeel: what a hit, a kill or a wound feels like) ------------------------------
## Every effect below can be switched off on its own. Hit stop = the game freezes for an instant
## (seconds, real time) so a blow reads; shake = the camera jumps (px, then fades over seconds).
const GAME_FEEL_ENABLED := true
## Time scale while a hit stop lasts (near 0 = frozen).
const HIT_STOP_SCALE := 0.05
const HIT_STOP_KILL := 0.05
const HIT_STOP_PLAYER_HURT := 0.09
const HIT_STOP_BOSS_PHASE := 0.15
const HIT_STOP_BOSS_DEFEATED := 0.35
const SHAKE_KILL := Vector2(2.0, 0.15)
const SHAKE_PLAYER_HURT := Vector2(4.0, 0.25)
const SHAKE_BOSS_SLAM := Vector2(5.0, 0.35)
const SHAKE_BOSS_ROOTS := Vector2(2.5, 0.25)
const SHAKE_BOSS_PHASE := Vector2(4.0, 0.4)
const SHAKE_BOSS_DEFEATED := Vector2(7.0, 0.7)
## Particles thrown when an enemy is hit and when it dies (count 0 = off), in the enemy's color.
const HIT_PARTICLES := 5
const DEATH_PARTICLES := 18
## Size of each spark (px).
const PARTICLE_SIZE := Vector2(2.0, 3.0)
## How long sparks live (s), how fast they fall (px/s²) and slow down (min, max), and the speed of
## the small burst of a hit (a death uses DEATH_PARTICLE_SPEED).
const PARTICLE_LIFETIME := 0.45
const PARTICLE_GRAVITY := 160.0
const PARTICLE_DAMPING := Vector2(40.0, 80.0)
const HIT_PARTICLE_SPEED := 40.0
const DEATH_PARTICLE_SPEED := 70.0
## Dust under Nico's feet when he dodges (count 0 = off).
const DASH_DUST := 8
const DASH_DUST_COLOR := Color(0.85, 0.8, 0.65, 0.8)
const DASH_DUST_SPEED := 25.0
## Afterimages left by Nico's dodge: how many (0 = off), seconds between them, how long each fades,
## and the one color of their silhouette (its alpha is how see-through they start).
const DASH_GHOSTS := 3
const DASH_GHOST_EVERY := 0.04
const DASH_GHOST_FADE := 0.2
const DASH_GHOST_TINT := Color(0.55, 0.85, 1.0, 0.4)
## Damage numbers over an enemy: how high they rise (px) and how long they last (s; 0 = off).
const DAMAGE_NUMBER_TIME := 0.6
const DAMAGE_NUMBER_RISE := 14.0
const DAMAGE_NUMBER_COLOR := Color(1.0, 0.95, 0.75)
## Font size of the numbers (the pixel font is drawn crisp at multiples of 16).
const DAMAGE_NUMBER_SIZE := 16
const DAMAGE_NUMBER_BOSS_COLOR := Color(1.0, 0.75, 0.4)
## Red flash over the screen when Nico is hurt (alpha 0 = off) and how long it fades (s).
const HURT_FLASH := Color(0.85, 0.05, 0.05, 0.28)
const HURT_FLASH_TIME := 0.3
## Below this health Nico's screen edge pulses red (0 = off).
const LOW_HEALTH := 1
const LOW_HEALTH_PULSE := Color(0.6, 0.0, 0.0, 0.22)

# --- Trees in front of Nico (CanopyFade) -----------------------------------------------------------
## A tree whose crown covers Nico turns see-through to this alpha (1 = off), at this speed (per s).
const CANOPY_FADE_ALPHA := 0.45
const CANOPY_FADE_SPEED := 8.0
