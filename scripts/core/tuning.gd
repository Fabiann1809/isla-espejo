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
## The forest's own water and bridges (WaterArt, drawn by tools/make_water_art.py); false = the
## tileset's flat pond and square of planks. Seconds per frame of the water's ripples, glints and
## foam, and the share of open-water tiles with a lily pad.
const WATER_ART_ENABLED := true
const WATER_FRAME_TIME := 0.22
const WATER_LILY_CHANCE := 0.2
## A bridge: how far its deck reaches onto each bank (px), how far inside the deck's edge its rail
## posts stand (px) and where the shade it casts on the water falls (px, light from the upper left).
const BRIDGE_OVERHANG := 6
const BRIDGE_RAIL_INSET := 3.0
const BRIDGE_SHADOW_OFFSET := Vector2(3, 3)
## The forest's own bare earth for paths and dirt patches (DirtArt, drawn by tools/make_dirt_art.py):
## a frayed, wandering edge instead of the tileset's boxes with a dotted rim. False = the tileset's.
const DIRT_ART_ENABLED := true
## A dirt patch loses its corner cells, and a side at least this many tiles long gets a bite of grass.
const DIRT_PATCH_BITE_SIDE := 7
## The camp's own campfire (stones, logs and a flame) and the cut stump with roots and a shadow
## (tools/make_camp_art.py); false = the tileset's campfire and the forest art set's stump. Frames
## per second of the flame.
const CAMP_ART_ENABLED := true
const CAMPFIRE_FPS := 8.0
## The Anciano's camp around its fire (RoomDressing; art in assets/art_forest/camp/, drawn in
## Aseprite, sources in its source/ folder). Each piece: its picture, where its foot stands from the
## middle of the campfire (px), whether it blocks (with its base only) and, optionally, how tall that
## base is (px; a log lying towards us blocks along its length; default CAMP_BASE_HEIGHT). The seats
## ring the fire: a log across below it and one lying towards us on its right. A piece that would land
## on another prop, a spawn marker or a door lane is left out.
const CAMP_PROPS_ENABLED := true
const CAMP_PIECES := [
	["tent", Vector2(-36, -26), true],
	["lantern", Vector2(-14, -24), false],
	["woodpile", Vector2(28, -22), true],
	["pot", Vector2(20, 2), false],
	["log_seat", Vector2(2, 24), true],
	["log_seat_side", Vector2(36, 14), true, 18.0],
	["backpack", Vector2(-52, 24), false],
	["rune_stone", Vector2(-66, 0), true],
]
## Tufts of tall grass at the edge of the clearing (from the middle of the campfire, px).
const CAMP_GRASS := [Vector2(-58, -30), Vector2(-20, -40), Vector2(44, -36), Vector2(62, 26), Vector2(-62, 26)]
## How far below its foot a piece's shadow reaches (px), the height of a blocking piece's base (px)
## and how far its base keeps from the door lanes (px).
const CAMP_SHADOW_BELOW := 2.0
const CAMP_BASE_HEIGHT := 6.0
const CAMP_LANE_MARGIN := 8.0
## The lantern's warm light and the carved stone's faint glow (alpha 0 = off) and their sizes (px).
const CAMP_LANTERN_LIGHT := Color(1.0, 0.72, 0.36, 0.3)
const CAMP_LANTERN_LIGHT_RADIUS := 26.0
const CAMP_RUNE_LIGHT := Color(0.45, 0.9, 1.0, 0.2)
const CAMP_RUNE_LIGHT_RADIUS := 18.0
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
const ROCK_WALL_STEP := 13.0
const ROCK_WALL_JITTER := 3.0
const ROCK_WALL_BACK_ROW := 8.0
const ROCK_WALL_TALL_CHANCE := 0.25
## Share of the wall's columns that are snapped off, slim or fat (the rest are the plain and tall ones).
const ROCK_WALL_BROKEN_CHANCE := 0.1
const ROCK_WALL_THIN_CHANCE := 0.1
const ROCK_WALL_FAT_CHANCE := 0.06
const ROCK_WALL_TEMPLE_CHANCE := 0.12
const ROCK_WALL_PANEL_CHANCE := 0.1
const ROCK_WALL_STACK_CHANCE := 0.07
## Step between columns varies between these factors of ROCK_WALL_STEP; share of steps left empty (a bay); how far
## (px) the wall sways across its line; share of wall feet that get a chunk of fallen rock at their foot.
const ROCK_WALL_STEP_MIN := 0.6
const ROCK_WALL_STEP_MAX := 1.7
const ROCK_WALL_GAP_CHANCE := 0.12
const ROCK_WALL_WAVE := 3.5
const ROCK_WALL_CHUNK_CHANCE := 0.05
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
## Shadow strength on the Ruinas' dark stone, where the normal one barely shows.
const RUIN_SHADOW_ALPHA := 0.6
## A soft shadow at the foot of trees, bushes, rocks and standing stones (GroundShadow), drawn with the
## floor: how dark, its color, how wide for the picture's width (and at least, px), how flat, and how
## far it leans from the foot (px; light from the upper left).
const PROP_SHADOWS_ENABLED := true
const PROP_SHADOW_ALPHA := 0.3
const PROP_SHADOW_COLOR := Color(0.03, 0.08, 0.02)
const PROP_SHADOW_WIDTH_FACTOR := 0.72
const PROP_SHADOW_MIN_WIDTH := 10.0
const PROP_SHADOW_HEIGHT_FACTOR := 0.3
const PROP_SHADOW_OFFSET := Vector2(2, 0)

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

# --- Chapter intro ----------------------------------------------------------------------------------
## When an island's chapter starts, the camera shows the room where Nico appears from farther away (a bit of
## its neighbours too) and glides in to Nico while the island's name appears (off = the game starts on Nico
## at once, with a small message).
const INTRO_ENABLED := true
## Camera zoom of the first shot (smaller = farther away; the game itself plays at 1).
const INTRO_ZOOM := 0.58
## Seconds: the black fades out, the camera hovers, then glides to Nico; the title rises and leaves.
const INTRO_FADE := 1.6
const INTRO_HOLD := 2.2
const INTRO_FLY := 5.0
const INTRO_TITLE_IN := 0.9
const INTRO_TITLE_SECONDS := 3.4
const INTRO_TITLE_SIZE := 32
const INTRO_SUBTITLE_SIZE := 16

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
## Seconds the shade (and the glow) take to grow when Nico enters a dark room and to fade when he leaves.
const RUIN_DARK_FADE_SECONDS := 1.6
## The rock between the rooms (RockBackdrop): formations on or off, spacing of their spots (px) and how far each
## wanders, base chance of a formation and how much the noise swings it (open pockets, dense stands), noise
## frequency, tiles left bare beside the way, tiles from the way where the middle and the deep rings begin, how
## far the search for the nearest floor goes, px of a picture that may overlap a floor, and how much each ring darkens.
const RUIN_BACKDROP_FORMATIONS := true
const RUIN_BACKDROP_STEP := 15.0
const RUIN_BACKDROP_JITTER := 5.0
const RUIN_BACKDROP_DENSITY := 0.55
## Least chance of a formation close to the way (the narrow gaps between rooms must never stay a bare trench).
const RUIN_BACKDROP_NEAR_DENSITY := 0.85
const RUIN_BACKDROP_CONTRAST := 1.1
const RUIN_BACKDROP_NOISE_FREQUENCY := 0.06
const RUIN_BACKDROP_CLEAR_TILES := 1
const RUIN_BACKDROP_NEAR_TILES := 3
const RUIN_BACKDROP_FAR_TILES := 8
const RUIN_BACKDROP_DEPTH := 12
const RUIN_BACKDROP_OVERLAP := 3.0
const RUIN_BACKDROP_DARKEN := 0.2
## Cold flame of the blue sconces, warm light of the lanterns, and the soft shadow props throw at their foot.
const RUIN_SCONCE_LIGHT := Color(0.3, 0.78, 1.0, 0.4)
const RUIN_SCONCE_LIGHT_RADIUS := 56.0
const RUIN_LANTERN_LIGHT := Color(1.0, 0.7, 0.3, 0.32)
const RUIN_LANTERN_LIGHT_RADIUS := 44.0
const RUIN_PROP_SHADOWS := true
const RUIN_PROP_SHADOW_ALPHA := 0.42
## Chance that a platform's front tile carries hanging vines.
const RUIN_PLATFORM_VINE_CHANCE := 0.3
## Floor variety of a ruin room (RuinShape._build_floor_detail): drift of darker/paler slabs (noise
## frequency, threshold), big flagstones tried per room, and the patches of worn, mossy or broken floor.
const RUIN_FLOOR_DRIFT_FREQUENCY := 0.11
const RUIN_FLOOR_DIM_THRESHOLD := 0.18
const RUIN_FLOOR_SLAB_TRIES := 14
const RUIN_FLOOR_ZONES_MIN := 2
const RUIN_FLOOR_ZONES_MAX := 3
const RUIN_FLOOR_ZONE_RADIUS_MIN := 2.2
const RUIN_FLOOR_ZONE_RADIUS_MAX := 3.8

# --- Idle breathing (IdleBreath) ---
## Nico and the NPCs breathe while they stand still: the body rises up to BREATH_PIXELS whole pixels while the legs
## (the lowest BREATH_LEG_SHARE of the figure) stretch to keep the feet fixed, one breath every BREATH_SECONDS. False = off.
const BREATH_ENABLED := true
const BREATH_PIXELS := 1.5
const BREATH_SECONDS := 1.2
const BREATH_LEG_SHARE := 0.3

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
## The portal's own art (assets/art_forest/portal/, drawn in Aseprite): a round stone dais lying with
## the floor, a stone arch standing with the actors (sorted by its foot, this far below the portal's
## origin, px) and a swirling veil in its doorway once it opens (frames per second). False = the
## tileset's flagstones and the plain violet doorway.
const PORTAL_ART_ENABLED := true
const PORTAL_ARCH_FOOT := 8.0
const PORTAL_VEIL_FPS := 6.0

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

# --- Nico's movement feel ---------------------------------------------------------------------------
## Turning between the walking views (side, front, back) keeps the step of the cycle instead of
## starting it over. False = every turn restarts the walk.
const WALK_KEEP_STEP := true
## Dust under Nico's feet while he walks: particles per step (0 = off), seconds between steps (the
## footstep sound's pace), how fast the dust drifts (px/s) and its color.
const WALK_DUST := 2
const WALK_DUST_EVERY := 0.32
const WALK_DUST_SPEED := 10.0
const WALK_DUST_COLOR := Color(0.85, 0.8, 0.65, 0.55)
## The dodge squashes Nico's picture (x, y scale) as it starts, stretches it as it ends and settles
## back in these seconds. Vector2.ONE for both = no squash.
const DASH_SQUASH := Vector2(1.25, 0.8)
const DASH_STRETCH_END := Vector2(0.9, 1.12)
const DASH_STRETCH_SETTLE := 0.1
## The camera leads Nico this many px where he walks or dodges (0 = off), catching up at this
## speed (per second).
## Off (0) in every map: the lead made the picture tremble. Kept as a switch.
const CAMERA_LOOK_AHEAD := 0.0
const CAMERA_LOOK_AHEAD_SPEED := 3.0

# --- Casting a skill ---------------------------------------------------------------------------------
## A ring of sparks in the skill's color at Nico's feet (false = off) and the flash of that color over
## him, fading in these seconds (0 = off).
const CAST_BURST := true
const CAST_FLASH_SECONDS := 0.3
const CAST_FLASH_STRENGTH := 0.8

# --- Trees in front of Nico (CanopyFade) -----------------------------------------------------------
## A tree whose crown covers Nico turns see-through to this alpha (1 = off), at this speed (per s).
const CANOPY_FADE_ALPHA := 0.45
const CANOPY_FADE_SPEED := 8.0

# --- Temple: plan ---
## In a surge room every walkable level-0 cell must have a stair up within this many steps (cells),
## so nobody is caught by the lava with no way up (TemplePlan.validate).
const TEMPLE_SURGE_MAX_STAIR_DISTANCE := 9

# --- Temple: tileset ---------------------------------------------------------------------------------
## Tint over the whole Templo del Eclipse. Neutral (white): the warm tint stacked with the additive
## glows and burnt the high floors to pale pink. Set a colour here and regenerate
## data/themes/temple.tres (tools/make_temple_theme.gd) to bring it back.
const TEMPLE_WORLD_TINT := Color.WHITE
## Multipliers over the temple's lava layers (the sea, the rooms' lava and bubbles, the bridges'
## lava) and its floor layers (floors, decks, stairs): darker and a little greyer, so the stone
## reads mid-grey and the lava bright but flat. Color.WHITE = off.
const TEMPLE_LAVA_MODULATE := Color(1.0, 0.94, 0.90)
const TEMPLE_FLOOR_MODULATE := Color(0.90, 0.90, 0.94)
## Cap on stacking additive lights: a temple light (prop, rim or stair brazier) is not created when
## another temple light already burns closer than this many px (0 = no cap).
const TEMPLE_LIGHT_MIN_SPACING := 28.0

# --- Temple: props ---
## A lava geyser (TempleProp.GEYSER) cycles idle, rumble, erupt and settle, in seconds; a hazard geyser
## hurts only while it erupts. An ambient geyser starts its idle at a seeded point of it, so neighbours
## never erupt together.
const TEMPLE_GEYSER_IDLE := 3.0
const TEMPLE_GEYSER_RUMBLE := 1.0
const TEMPLE_GEYSER_ERUPT := 1.2
const TEMPLE_GEYSER_SETTLE := 0.6
const TEMPLE_GEYSER_DAMAGE := 1
## Additive glows of the temple's fires and lava (alpha 0 = off) and their radii (px): fire for torches
## and braziers, lava for the falls, the geyser while it erupts and the gate's mouth.
const TEMPLE_FIRE_LIGHT := Color(1.0, 0.62, 0.2, 0.16)
const TEMPLE_FIRE_LIGHT_RADIUS := 38.0
const TEMPLE_LAVA_LIGHT := Color(1.0, 0.42, 0.1, 0.14)
const TEMPLE_LAVA_LIGHT_RADIUS := 56.0
const TEMPLE_GATE_LIGHT_RADIUS := 80.0
## Bounds of a temple light's flicker, as a factor of RUIN_LIGHT_FLICKER_SECONDS (picked per position).
const TEMPLE_PROP_LIGHT_FLICKER_MIN := 0.8
const TEMPLE_PROP_LIGHT_FLICKER_MAX := 1.4
## The trap walk's traps (TempleProp.SPIKES, SAW and ROLLING_ROCK; they hurt only through a Hitbox).
## Off: they stand still on their first frame and never hurt. The damage of every trap; the spikes'
## cycle in seconds (down, the warning with the tips out and the slots glowing, up, sinking back);
## the saw's speed along its track (px/s) and how often it hurts whoever stays on it (s); the rock's
## rumble before it rises (s), its speed (px/s), how long its shards lie (s) and how long the lane
## stays empty before the next one (s).
const TEMPLE_TRAPS_ENABLED := true
const TEMPLE_TRAP_DAMAGE := 1
const TEMPLE_SPIKES_DOWN := 2.4
const TEMPLE_SPIKES_WARN := 0.7
const TEMPLE_SPIKES_UP := 1.0
const TEMPLE_SPIKES_RETRACT := 0.4
const TEMPLE_SAW_SPEED := 40.0
const TEMPLE_SAW_HIT_EVERY := 0.6
const TEMPLE_ROCK_SPAWN := 0.8
const TEMPLE_ROCK_SPEED := 56.0
const TEMPLE_ROCK_BREAK := 0.5
const TEMPLE_ROCK_RESPAWN := 1.4

# --- Temple: level ---
## The lava sea around a temple map (LavaBackdrop) reaches this far past the rooms (tiles): wider
## than the forest's margin, so the sea, its shelves and its islets show around the edge rooms.
const TEMPLE_BACKDROP_MARGIN_TILES := 6
## Frames per second of the lava's flow (every cell in step, so the sea reads as one current), of its
## bursting bubbles, of the crust's pulsing glow and of the lava-lit feet of the cliffs (these three
## start at random times, so neighbours never pulse together).
const TEMPLE_LAVA_FPS := 5.0
const TEMPLE_LAVA_BUBBLE_FPS := 6.0
const TEMPLE_LAVA_GLOW_FPS := 3.0
const TEMPLE_LAVA_FOOT_FPS := 4.0
## Share of the open lava cells (away from any shore or bridge) that carry a bursting bubble.
const TEMPLE_BACKDROP_BUBBLE_CHANCE := 0.035
## The sea's lava is painted from three edge-matched macro variants of the sheet (8x8 tiles each):
## every 8x8 block of the world picks one by a world-space noise of this frequency (per block), so the
## pattern never repeats on a grid. 0 = always the first variant.
const TEMPLE_LAVA_VARIANT_FREQUENCY := 0.4
## Big plates of cooler crust drifting slowly over every lava of the map (the sea, the rooms' lava
## and the bridges' alike; under every floor): a tiling noise picture of TEMPLE_BACKDROP_PLATE_SIZE
## texels, one texel per TEMPLE_BACKDROP_PLATE_TEXEL px. Their colour and alpha (0 = off), the share
## of the sea they cover, how soft their edge is (in noise units), the noise frequency (per texel)
## and their drift (px/s, x and y).
const TEMPLE_BACKDROP_PLATE_COLOR := Color(0.14, 0.03, 0.02)
const TEMPLE_BACKDROP_PLATE_ALPHA := 0.06
const TEMPLE_BACKDROP_PLATE_SIZE := 256
const TEMPLE_BACKDROP_PLATE_TEXEL := 4
const TEMPLE_BACKDROP_PLATE_COVER := 0.42
const TEMPLE_BACKDROP_PLATE_EDGE := 0.1
const TEMPLE_BACKDROP_PLATE_FREQUENCY := 0.028
const TEMPLE_BACKDROP_PLATE_DRIFT := Vector2(2.5, 1.0)
## Islets of rock in the sea: on or off, one islet tried per this many tiles of the sea (fewer with a
## bigger number; the spots are random, never a grid), their size in cells (min, max: the blob is cut
## from a box of that size, so it is irregular and smaller), the chance that a tried islet is a big
## one (the upper half of the sizes), tiles of open lava kept between an islet and anything else,
## rows of cliff face under their top (min, max; an islet that pours a lava fall always has the
## most) and the chance that an islet carries a ruin (a broken column or a brazier) on its top.
const TEMPLE_BACKDROP_ISLETS := true
const TEMPLE_BACKDROP_ISLET_PER_TILES := 230
const TEMPLE_BACKDROP_ISLET_MIN := Vector2i(5, 4)
const TEMPLE_BACKDROP_ISLET_MAX := Vector2i(10, 6)
const TEMPLE_BACKDROP_ISLET_BIG_CHANCE := 0.65
const TEMPLE_BACKDROP_ISLET_CLEAR_TILES := 2
const TEMPLE_BACKDROP_ISLET_FACE_ROWS := Vector2i(1, 3)
const TEMPLE_BACKDROP_RUIN_CHANCE := 0.65
## Rock shelves along the north edge of the map (the lava falls pour over them into the sea): chance
## per spot, their width in cells (min, max), how many rows of top reach into the view (min, max;
## the first row always lies above it, so no shelf has a top edge) and the gap left between them.
const TEMPLE_BACKDROP_SHELF_CHANCE := 0.75
const TEMPLE_BACKDROP_SHELF_WIDTH := Vector2i(3, 6)
const TEMPLE_BACKDROP_SHELF_ROWS := Vector2i(0, 2)
const TEMPLE_BACKDROP_SHELF_GAP := Vector2i(1, 4)
## Chance that an islet or a shelf pours a lava fall, px below the cliff's foot where the fall's splash
## sits, chance of a smoking rock on an islet, of an ember vent on an inner cell of an islet, of a lone
## smoking rock out in the lava (per islet spot), of a mossy cliff face and of a detail (moss, cracks,
## pebbles, embers) on an inner cell.
const TEMPLE_BACKDROP_FALL_CHANCE := 0.4
const TEMPLE_BACKDROP_SHELF_FALL_CHANCE := 0.7
const TEMPLE_BACKDROP_FALL_FOOT := 4.0
const TEMPLE_BACKDROP_ROCK_CHANCE := 0.45
const TEMPLE_BACKDROP_VENT_CHANCE := 0.12
const TEMPLE_BACKDROP_LONE_ROCK_CHANCE := 0.08
const TEMPLE_BACKDROP_MOSS_CHANCE := 0.3
const TEMPLE_BACKDROP_DETAIL_CHANCE := 0.65
## The crust (LavaBackdrop's shade over the sea): the lava darkens with distance from the islands'
## stone (the rooms' floors, not their rectangles) and the bridges, so the way reads bright and the
## far sea reads as cooled rock with glowing channels. Its colour, how dark far out, tiles from the
## stone where it starts and where it is darkest, how much that edge wobbles (tiles), the wobble's
## frequency, how much a second, slower noise mottles the far crust (0..1: cooled regions darker,
## channels lighter), the share of it that falls on the islets' rock (they stand out of the sea) and
## how far the search for the stone goes (tiles).
const TEMPLE_BACKDROP_CRUST_COLOR := Color(0.1, 0.02, 0.02)
const TEMPLE_BACKDROP_CRUST_ALPHA := 0.18
const TEMPLE_BACKDROP_CRUST_NEAR_TILES := 2.0
const TEMPLE_BACKDROP_CRUST_FAR_TILES := 9.0
const TEMPLE_BACKDROP_CRUST_WOBBLE := 3.5
const TEMPLE_BACKDROP_CRUST_FREQUENCY := 0.09
const TEMPLE_BACKDROP_CRUST_MOTTLE := 0.45
const TEMPLE_BACKDROP_CRUST_ON_ROCK := 0.4
const TEMPLE_BACKDROP_DEPTH := 16
## The islets and shelves are darker, warmer rock than the rooms' stone: a tint over their tiles
## (their lava-lit feet stay bright).
const TEMPLE_BACKDROP_ISLET_TINT := Color(0.82, 0.7, 0.66)
## Bridges and stairs between temple rooms: px from the top of a wall tile where the near (south)
## rail's parapet stands (its y-sort point), and px past the top end of a staircase where each
## brazier's foot stands (on the high room's wall, flanking the door: half a wall tile).
const TEMPLE_BRIDGE_RAIL_BASE := 10.0
const TEMPLE_STAIR_BRAZIER_LANDING := 8.0

# --- Temple: bridges ---
## A temple corridor is a stone causeway over the lava (TempleBridge): a deck along the door lane and a
## low parapet on each side, no posts but one at each end where the parapet meets a room (off: the
## parapets end flush). A corridor longer than TEMPLE_LANDING_MIN_TILES gets a landing at mid-span (off
## with TEMPLE_LANDINGS): a stone island TEMPLE_LANDING_TILES long along the corridor and as wide as
## the lane plus the two parapet rows, with this many rows of cliff dropping into the lava on its
## south side (0 = none, its ledge alone marks the edge) and a brazier on a pedestal on each side of
## the way (off: bare).
const TEMPLE_BRIDGE_END_POSTS := false
## Decorative soffits and piers below causeways; no collision. False restores tile-only decks.
const TEMPLE_BRIDGE_VOLUME := true
const TEMPLE_BRIDGE_SOFFIT_PX := 10
const TEMPLE_BRIDGE_PIER_EVERY := 6
const TEMPLE_LANDINGS := true
const TEMPLE_LANDING_MIN_TILES := 10
const TEMPLE_LANDING_TILES := 6
const TEMPLE_LANDING_FACE_ROWS := 2
const TEMPLE_LANDING_BRAZIERS := true
## A corridor between rooms one level apart climbs on one stretch of steps and is a bridge at each
## end's height on the rest (off: the whole corridor is steps, as the Ruinas' are): across the landing
## when it has one (TEMPLE_LANDING_STAIR_TILES long), else at the high room's door (up to
## TEMPLE_BRIDGE_STAIR_TILES long).
const TEMPLE_BRIDGE_STAIR_STRETCH := true
const TEMPLE_BRIDGE_STAIR_TILES := 4
const TEMPLE_LANDING_STAIR_TILES := 2

# --- Temple: shape ---
## A temple room (TempleShape) is a stone island over a sea of lava. Frames per second of the lava's
## flow (the 4x4 macro sea, all in step), its bubbles, the pulsing cracks of the crust along the rims,
## the lava's light on the foot of a cliff, the glowing runes and the sheet's fires (brazier, torch).
## On: the temple's lava, glows and fires play their frames. Off: everything is painted still (first frame).
const TEMPLE_SHAPE_ANIMATE := true
const TEMPLE_RUNE_GLOW_FPS := 2.0
const TEMPLE_FIRE_FPS := 7.0
## Share of the open lava cells that bubble, of the cliff faces that hang moss, and of the floor cells
## (off the door lanes) that carry moss, cracks and glowing runes (runes on levels 1 and 2 only).
const TEMPLE_BUBBLE_SHARE := 0.04
const TEMPLE_FACE_MOSS_SHARE := 0.25
const TEMPLE_FLOOR_MOSS_SHARE := 0.05
const TEMPLE_FLOOR_CRACK_SHARE := 0.03
const TEMPLE_FLOOR_RUNE_SHARE := 0.015
## Chance that a `p` cell holds a pillar of blocks instead of a carved one.
const TEMPLE_PILLAR_BLOCK_CHANCE := 0.35
## Reading the heights (each off = the plain look): a `#` masonry cell drawn as a built wall (capped
## top, carved front) instead of a slab with a cliff; the shadow a platform casts south onto the
## lower floor and the one it casts east; a balustrade on the open sides of every flight of stairs;
## a mark (never blocking) on each top corner of every flight inside a room: a small brazier, or a
## stone post when another brazier burns closer than this many cells (0 = always a brazier).
const TEMPLE_MASONRY_ART := true
const TEMPLE_DROP_SHADOWS := true
## Extra rock rows may occupy empty lava only, never floor, stairs or bridge decks.
const TEMPLE_LAVA_CLIFF_EXTRA_ROWS := 3
const TEMPLE_EAST_SHADOWS := true
const TEMPLE_STAIR_WALLS := true
const TEMPLE_STAIR_TOP_BRAZIERS := true
const TEMPLE_STAIR_BRAZIER_SPACING := 10
## At most this many flights of a room get a pair of braziers at their top (the rest stay bare).
const TEMPLE_STAIR_BRAZIER_MAX_PAIRS := 2
## The ground shadow of Nico, the enemies and the NPCs on the temple's floors: its alpha (the stone
## needs more than the forest's SHADOW_ALPHA to keep them on the ground; < 0 = SHADOW_ALPHA), how
## much bigger than the forest's it is (1 = the same) and how many px below the feet it sits (the
## forest's, centred on the last row of the feet, shows only a sliver); and how far a solid prop's
## shadow leans east, away from the light (px per px of the prop's height; 0 = right under its foot).
const TEMPLE_SHADOW_ALPHA := 0.42
const TEMPLE_SHADOW_SCALE := 1.15
## Negative: the shadow's centre sits a little above the last row of the feet, so the feet stand on it
## (a big shadow below the feet made Nico look like he floated over the floor).
const TEMPLE_SHADOW_DROP := -1.5
## How far the temple shadow's lower edge reaches below the feet (px), for every actor whatever its width
## (-1 = centre it on the feet with TEMPLE_SHADOW_DROP instead).
const TEMPLE_SHADOW_BOTTOM := 1.5
const TEMPLE_PROP_SHADOW_LEAN := 0.22
## One flickering lava light every this many rim cells (0 = none), its colour (alpha 0 = off; softer
## than a fire's, the lava is already bright) and its radius (px); one ember vent every this many lava
## cells (0 = none) with this many embers rising from it (0 = none), their life (s), their climb
## (px/s, min and max), the upward pull (px/s²) and their colour.
const TEMPLE_RIM_LIGHT_EVERY := 12
const TEMPLE_RIM_LIGHT := Color(1.0, 0.45, 0.12, 0.08)
const TEMPLE_RIM_LIGHT_RADIUS := 32.0
const TEMPLE_EMBER_VENT_EVERY := 40
const TEMPLE_EMBERS := 3
const TEMPLE_EMBER_LIFETIME := 1.8
const TEMPLE_EMBER_SPEED := Vector2(8.0, 18.0)
const TEMPLE_EMBER_RISE := 14.0
const TEMPLE_EMBER_COLOR := Color(1.0, 0.6, 0.2, 0.55)

# --- Temple: surge ---------------------------------------------------------------------------------
## Lava surge (LavaSurge, LavaSurgeLogic): the lava rises level by level in a `surge` room. Seconds of
## warning before each rise, of the rise itself (the lava creeps in from the edges) and per level
## when it recedes; the damage the lava deals every interval to whoever walks on a flooded level;
## seconds between waves of enemies, of ring warning before each one appears, and of steam over the
## floor the lava leaves. Nico must be farther than the trigger depth (px) from every door.
const TEMPLE_SURGE_ENABLED := true
const TEMPLE_SURGE_WARN_SECONDS := 2.5
const TEMPLE_SURGE_RISE_SECONDS := 3.0
const TEMPLE_SURGE_RECEDE_SECONDS := 2.5
const TEMPLE_SURGE_DAMAGE_INTERVAL := 0.8
const TEMPLE_SURGE_DAMAGE := 1
const TEMPLE_SURGE_WAVE_INTERVAL := 6.0
const TEMPLE_SURGE_SPAWN_WARN := 0.8
const TEMPLE_SURGE_TRIGGER_DEPTH := 64.0
const TEMPLE_SURGE_STEAM_SECONDS := 2.0
## A wave never appears closer than this many cells to Nico.
const TEMPLE_SURGE_SPAWN_MIN_DISTANCE := 4
## Physics frames the lava's hitbox stays on a target (it retries while Nico is still blinking).
const TEMPLE_SURGE_HIT_FRAMES := 6
## Warning: camera shake (px, seconds), how often a bubble bursts on the edge (s), the glow of the
## cells that flood first (alpha at its brightest).
const TEMPLE_SURGE_WARN_SHAKE := Vector2(1.5, 2.0)
const TEMPLE_SURGE_BUBBLE_EVERY := 0.12
const TEMPLE_SURGE_WARN_GLOW := 0.32
## Colours of the sealing fire, the warning ring of a wave and the bubbles.
const TEMPLE_SURGE_SEAL_COLOR := Color(1.0, 0.42, 0.1, 0.55)
const TEMPLE_SURGE_RING_COLOR := Color(1.0, 0.5, 0.12, 0.9)
const TEMPLE_SURGE_BUBBLE_COLOR := Color(1.0, 0.72, 0.25, 0.85)
## A fight that cannot send a wave (no enemy to pick, no free cell) ends after this many wave intervals
## once nothing is alive, so the doors never stay sealed for good.
const TEMPLE_SURGE_STALL_INTERVALS := 3
## Look of the surge: the ring warning a wave (radius px, how it closes in: start and end scale), the
## puff when it appears (radius px, seconds), the bubbles on the edge (radius range px, seconds), the
## glow on the cells that flood first (colour; its alpha is TEMPLE_SURGE_WARN_GLOW).
const TEMPLE_SURGE_RING_RADIUS := 11.0
const TEMPLE_SURGE_RING_SPAN := Vector2(1.5, 0.9)
const TEMPLE_SURGE_PUFF_RADIUS := 14.0
const TEMPLE_SURGE_PUFF_LIFE := 0.35
const TEMPLE_SURGE_BUBBLE_RADIUS := Vector2(3.0, 6.0)
const TEMPLE_SURGE_BUBBLE_LIFE := 0.5
const TEMPLE_SURGE_WARN_GLOW_COLOR := Color(1.0, 0.5, 0.15)
## The sealing fire: its alpha pulses between these values every this many seconds, fades in and out.
const TEMPLE_SURGE_SEAL_PULSE_ALPHAS := Vector2(0.55, 1.0)
const TEMPLE_SURGE_SEAL_PULSE_SECONDS := 0.35
const TEMPLE_SURGE_SEAL_FADE_IN := 0.4
const TEMPLE_SURGE_SEAL_FADE_OUT := 0.5
## Steam over the floor the lava leaves: particles, life (s), speed (px/s), size (px), pull up (px/s2),
## colour at the start and at the end.
const TEMPLE_SURGE_STEAM_AMOUNT := 3
const TEMPLE_SURGE_STEAM_LIFETIME := 1.0
const TEMPLE_SURGE_STEAM_SPEED := Vector2(4.0, 10.0)
const TEMPLE_SURGE_STEAM_SCALE := Vector2(2.0, 4.0)
const TEMPLE_SURGE_STEAM_RISE := 6.0
const TEMPLE_SURGE_STEAM_COLOR := Color(1.0, 0.85, 0.75, 0.5)
const TEMPLE_SURGE_STEAM_FADE := Color(0.8, 0.8, 0.85, 0.0)

## Pixel bands at every lava contact; zero width disables the effect.
const TEMPLE_SHORE_WIDTH := 6
const TEMPLE_BASALT_VARIANTS := true
const TEMPLE_BACKDROP_OUTCROPS := true
const TEMPLE_SHORE_CRUST_ALPHA := 0.25
const TEMPLE_SHORE_CRACK_ALPHA := 0.2
