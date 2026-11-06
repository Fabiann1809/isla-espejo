class_name RoomData
extends Resource
## One kind of room a scenario can use. The layout of the room (obstacles, spawn markers) lives in
## `scene`; this resource says when and how it is used. One `.tres` per room in `data/rooms/`.

enum RoomType { START, COMBAT, EVENT, REWARD, SPECIAL, BOSS }

@export var id: StringName = &"room"
@export var type: RoomType = RoomType.COMBAT
@export var scene: PackedScene
## Relative chance of being picked among rooms of the same type.
@export var weight := 1.0
## Free-form labels the AI director can weight (e.g. "ambush", "watch").
@export var tags: Array[StringName] = []
## A dark room (the Ruinas): a shade over the whole room, lit only by its crystals and torches and by
## a glow around the player.
@export var dark := false
## Height level of the whole room (0 = ground, 1 = raised, 2 only in the temple; see Heights). A
## corridor between rooms of different height is a staircase, so the generator never joins rooms
## two levels apart. A raised room has no water, terraces or alcoves of its own.
@export_range(0, 2) var height := 0

@export_group("Enemies")
@export var min_enemies := 2
@export var max_enemies := 4
## Enemy id -> multiplier of the scenario's `enemy_weights` in this room only (e.g. flyers over
## lava). A missing id counts as 1; 0 keeps that enemy out of the room.
@export var enemy_affinity: Dictionary = {}

@export_group("Surge")
## How many levels the lava of the room floods, one stage at a time (0 = no surge; see LavaSurge).
@export_range(0, 2) var surge_stages := 0
## Kills (not by lava) that make the lava rise to its second stage.
@export var kills_stage_1 := 5
## Kills in the final stage that make the lava recede.
@export var kills_to_recede := 5
## Enemies in each wave, and how many may be alive at once (the room's own included).
@export var wave_size := 2
@export var max_alive := 5
