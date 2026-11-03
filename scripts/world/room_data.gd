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
## Height level of the whole room (0 = ground, 1 = raised; see Heights). A corridor between rooms of
## different height is a staircase. A raised room has no water, terraces or alcoves of its own.
@export_range(0, 1) var height := 0

@export_group("Enemies")
@export var min_enemies := 2
@export var max_enemies := 4
