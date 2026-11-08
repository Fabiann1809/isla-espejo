class_name RoomDressing
extends RefCounted
## Decoration that tells the special rooms apart at a glance, added by Level after it fills a room:
## - boss arena: darker ground, roots on the floor, a ring of standing stones, torches at its doors;
## - reward glade: a pool of warm light around the chest and a few flowers;
## - event camp: the campfire's flickering light and a signpost by the way in;
## - the Mercader's shop (any room where a merchant NPC stands): a stall, a rug, lanterns and crates.
## Purely visual: no collision, no gameplay. Every element can be switched off in Tuning.

const TORCH_FRAMES := [TileArt.TORCH_A, TileArt.TORCH_B]
const STONES := [TileArt.ROCK, TileArt.ROCK_MOSSY, TileArt.ROCK, TileArt.ROCK_SMALL]
## Door lanes stay clear of stones: half the door width plus a tile.
const LANE_HALF := Room.DOOR_WIDTH / 2.0 + 16.0

static var _glow_texture: Texture2D
static var _pixel: Texture2D


## Dresses `room` according to its type (rooms of other types are left as they are).
static func dress(room: Room) -> void:
	if not Tuning.ROOM_DRESSING_ENABLED or room.theme == null or room.data == null:
		return
	if Tuning.SHOP_ROOM_ENABLED:
		_dress_shop(room)
	# The Ruinas dress their special rooms with their own props (see RuinProp), not with the forest's.
	if room.theme.wall_style == RoomTheme.WallStyle.ROCKS:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["dressing", Vector2i(room.position)])
	match room.data.type:
		RoomData.RoomType.BOSS:
			_dress_arena(room, rng)
		RoomData.RoomType.REWARD:
			_dress_glade(room, rng)
		RoomData.RoomType.EVENT:
			_dress_camp(room)


# --- Boss arena -------------------------------------------------------------------------------

static func _dress_arena(room: Room, rng: RandomNumberGenerator) -> void:
	var arena := _arena_rect(room)
	var floor_layer := _floor_layer(room, "ArenaFloor")
	var center := arena.get_center()
	if Tuning.BOSS_ARENA_SHADE.a > 0.0:
		var shade := make_glow(Tuning.BOSS_ARENA_SHADE, arena.size * 1.25, false)
		shade.position = center
		floor_layer.add_child(shade)
	# Numbered names: siblings with the same name would be renamed by the engine.
	for i in Tuning.BOSS_ARENA_ROOTS:
		var root := _root_line(center, arena.size / 2.0, TAU * (i + rng.randf_range(-0.3, 0.3)) / Tuning.BOSS_ARENA_ROOTS, rng)
		root.name = "ArenaRoot%d" % i
		floor_layer.add_child(root)
	_place_stones(room, arena, rng)
	var runes := ArenaRunes.new()
	runes.name = "ArenaRunes"
	var boss_spots := room.spawn_points("BossSpawn")
	runes.position = boss_spots[0] if not boss_spots.is_empty() else room.center()
	floor_layer.add_child(runes)
	if Tuning.DOOR_TORCHES:
		for door in room.open_doors:
			for spot in _beside_door(room, door):
				var torch := _torch(spot)
				torch.name = "DoorTorch%d" % room.get_child_count()
				room.add_child(torch)


## The arena: the biggest patch of bare earth of the room (its middle if it has none).
static func _arena_rect(room: Room) -> Rect2:
	var best := Rect2(room.center() - Vector2(112, 80), Vector2(224, 160))
	var best_area := 0.0
	for child in room.get_children():
		if child is RoomProp and child.kind == RoomProp.Kind.DIRT_PATCH:
			var rect := Rect2(child.position, Vector2(child.size_tiles * TileArt.TILE))
			if rect.get_area() > best_area:
				best = rect
				best_area = rect.get_area()
	return best


## A ring of standing stones just outside the arena, leaving the door lanes free.
static func _place_stones(room: Room, arena: Rect2, rng: RandomNumberGenerator) -> void:
	var radius := arena.size / 2.0 + Vector2(20, 16)
	var center := arena.get_center()
	var inside := Rect2(Vector2(Room.WALL, Room.WALL) * 1.5, room.pixel_size() - Vector2(Room.WALL, Room.WALL) * 3.0)
	for i in Tuning.BOSS_STONES:
		var angle := TAU * (i + 0.5) / Tuning.BOSS_STONES + rng.randf_range(-0.08, 0.08)
		var spot := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		var from_center := spot - room.center()
		if absf(from_center.x) < LANE_HALF or absf(from_center.y) < LANE_HALF or not inside.has_point(spot):
			continue
		var stone := TileArt.sprite(STONES[i % STONES.size()], Vector2(-8, -14))
		var holder := Node2D.new()
		holder.name = "ArenaStone%d" % i
		holder.position = spot.round()
		holder.add_child(stone)
		GroundShadow.under(holder, Vector2(0, -1), TileArt.TILE)
		room.add_child(holder)


## A crooked root lying on the floor, from the arena's middle outwards.
static func _root_line(center: Vector2, reach: Vector2, angle: float, rng: RandomNumberGenerator) -> Line2D:
	var line := Line2D.new()
	line.default_color = Tuning.BOSS_ROOT_COLOR
	line.width = 6.0
	line.width_curve = Curve.new()
	line.width_curve.add_point(Vector2(0, 1))
	line.width_curve.add_point(Vector2(1, 0.2))
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var steps := 6
	var length := rng.randf_range(0.55, 0.85)
	for step in steps + 1:
		var t := length * step / steps
		var bend := angle + rng.randf_range(-0.25, 0.25) * step / steps
		var point := center + Vector2(cos(bend) * reach.x, sin(bend) * reach.y) * t
		line.add_point(point.round())
	return line


## Two spots inside the room flanking an open door (left/right of it, or above/below it).
static func _beside_door(room: Room, door: Vector2i) -> Array[Vector2]:
	var size := room.pixel_size()
	var half := Room.DOOR_WIDTH / 2.0 + 8.0
	var inset := Room.WALL + 14.0
	var spots: Array[Vector2] = []
	match door:
		Vector2i.UP:
			spots = [Vector2(size.x / 2.0 - half, inset), Vector2(size.x / 2.0 + half, inset)]
		Vector2i.DOWN:
			spots = [Vector2(size.x / 2.0 - half, size.y - Room.WALL - 2.0), Vector2(size.x / 2.0 + half, size.y - Room.WALL - 2.0)]
		# A torch is 16 px tall above its base: bases at -36 and +48 keep both out of the door gap.
		Vector2i.LEFT:
			spots = [Vector2(inset - 6.0, size.y / 2.0 - half + 4.0), Vector2(inset - 6.0, size.y / 2.0 + half + 8.0)]
		Vector2i.RIGHT:
			spots = [Vector2(size.x - inset + 6.0, size.y / 2.0 - half + 4.0), Vector2(size.x - inset + 6.0, size.y / 2.0 + half + 8.0)]
	return spots


## A standing torch with its base at `spot`: two flame frames and a small light on the ground.
static func _torch(spot: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.position = spot.round()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", Tuning.TORCH_FLICKER_FPS)
	for role in TORCH_FRAMES:
		frames.add_frame(&"default", TileArt.tile(role))
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = frames
	flame.centered = false
	flame.position = Vector2(-8, -16)
	flame.scale = Vector2.ONE * TileArt.draw_scale()
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(flame)
	flame.play()
	if Tuning.TORCH_LIGHT.a > 0.0:
		var light := make_glow(Tuning.TORCH_LIGHT, Vector2.ONE * Tuning.TORCH_LIGHT_RADIUS * 2.0, true)
		light.position = Vector2(0, -6)
		light.z_index = RoomTheme.GROUND_FX_Z
		light.z_as_relative = false
		holder.add_child(light)
	return holder


# --- Reward glade -----------------------------------------------------------------------------

static func _dress_glade(room: Room, rng: RandomNumberGenerator) -> void:
	var points := room.spawn_points("ChestSpawn")
	var center: Vector2 = points[0] if not points.is_empty() else room.center()
	if Tuning.GLADE_LIGHT.a > 0.0:
		var light := make_glow(Tuning.GLADE_LIGHT, Vector2.ONE * Tuning.GLADE_LIGHT_RADIUS * 2.0, true)
		light.name = "GladeLight"
		light.position = center
		light.z_index = RoomTheme.GROUND_FX_Z
		room.add_child(light)
	var floor_layer := _floor_layer(room, "GladeFlowers")
	var flowers := [TileArt.FLOWER_YELLOW, TileArt.FLOWER_PURPLE, TileArt.FLOWER_YELLOW]
	for i in Tuning.GLADE_FLOWERS:
		var angle := TAU * i / maxf(Tuning.GLADE_FLOWERS, 1) + rng.randf_range(-0.3, 0.3)
		var distance := rng.randf_range(34.0, 52.0)
		var spot := center + Vector2(cos(angle), sin(angle) * 0.7) * distance
		var from_center := spot - room.center()
		if absf(from_center.x) < 24.0 or absf(from_center.y) < 24.0:
			continue
		floor_layer.add_child(TileArt.sprite(flowers[i % flowers.size()], (spot - Vector2(8, 8)).round()))


# --- Event camp -------------------------------------------------------------------------------

static func _dress_camp(room: Room) -> void:
	for child in room.get_children():
		if child is RoomProp and child.kind == RoomProp.Kind.CAMPFIRE and Tuning.CAMPFIRE_LIGHT.a > 0.0:
			var light := make_glow(Tuning.CAMPFIRE_LIGHT, Vector2.ONE * Tuning.CAMPFIRE_LIGHT_RADIUS * 2.0, true)
			light.name = "CampfireLight"
			# The prop's origin sits near the bottom of its tile (y-sort): the fire is 4 px above it.
			light.position = child.global_position - room.global_position + Vector2(8, -4)
			light.z_index = RoomTheme.GROUND_FX_Z
			room.add_child(light)
			var full := Tuning.CAMPFIRE_LIGHT.a
			var flicker := light.create_tween().set_loops()
			flicker.tween_property(light, "modulate:a", full * 0.7, 0.35).set_trans(Tween.TRANS_SINE)
			flicker.tween_property(light, "modulate:a", full, 0.45).set_trans(Tween.TRANS_SINE)
		if child is RoomProp and child.kind == RoomProp.Kind.CAMPFIRE and Tuning.CAMP_PROPS_ENABLED:
			_furnish_camp(room, child)
	if Tuning.CAMP_SIGN and not room.open_doors.is_empty():
		var sign_spot := _beside_door(room, room.open_doors[0])[0]
		var holder := Node2D.new()
		holder.name = "CampSign"
		holder.position = sign_spot.round()
		holder.add_child(TileArt.sprite(TileArt.SIGN, Vector2(-8, -15)))
		room.add_child(holder)


## The Anciano's camp around its fire, so the one who tells the island's story lives somewhere: a
## tent, logs to sit on, firewood, a pot, his backpack, a lantern and a standing stone carved with the
## island's mark, with tall grass at the clearing's edge (Tuning.CAMP_PIECES). Pieces stand with the
## actors (y-sorted by their foot) and the big ones block with their base only; one that would land on
## another prop, a marker or a door lane is left out.
static func _furnish_camp(room: Room, fire: RoomProp) -> void:
	# The fire prop's origin is near the bottom of its tile (y-sort): the ring's middle is above it.
	var anchor := fire.position + Vector2(TileArt.TILE / 2.0, 0)
	var taken: Array[Rect2] = _blocked_rects(room)
	var count := 0
	for piece: Array in Tuning.CAMP_PIECES:
		var tex := ForestArt.texture(ForestArt.CAMP_DIR + "%s.png" % piece[0])
		if tex == null:
			continue
		var foot: Vector2 = (anchor + piece[1]).round()
		var base := _camp_base(tex, foot, piece[3] if piece.size() > 3 else Tuning.CAMP_BASE_HEIGHT)
		if not _camp_spot_free(room, base, taken):
			continue
		taken.append(base)
		count += 1
		var holder := Node2D.new()
		holder.name = "CampProp%s%d" % [String(piece[0]).to_pascal_case(), count]
		holder.position = foot
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = -Vector2(floorf(tex.get_width() / 2.0), tex.get_height() - Tuning.CAMP_SHADOW_BELOW)
		holder.add_child(sprite)
		if piece[2]:
			holder.add_child(_base_body(Rect2(base.position - foot, base.size)))
		room.add_child(holder)
		match piece[0]:
			"lantern":
				_camp_light(room, foot + Vector2(0, -6), Tuning.CAMP_LANTERN_LIGHT, Tuning.CAMP_LANTERN_LIGHT_RADIUS, "CampLanternLight")
			"rune_stone":
				_camp_light(room, foot + Vector2(-1, -8), Tuning.CAMP_RUNE_LIGHT, Tuning.CAMP_RUNE_LIGHT_RADIUS, "CampRuneLight")
	var grass := _floor_layer(room, "CampGrass")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["camp", Vector2i(anchor)])
	for offset: Vector2 in Tuning.CAMP_GRASS:
		var spot := (anchor + offset).round()
		if not _camp_spot_free(room, Rect2(spot - Vector2(4, 4), Vector2(8, 4)), taken):
			continue
		var tex := ForestArt.pick(ForestArt.BUSHES, ForestArt.GROUND_PLANTS, rng)
		if tex != null:
			grass.add_child(ForestArt.standing(tex, spot))


## The part of a camp piece that blocks: a band `height` px tall ending at its foot, a little narrower
## than its picture.
static func _camp_base(tex: Texture2D, foot: Vector2, height: float) -> Rect2:
	var width := tex.get_width() - 2.0 * (1.0 + Tuning.PROP_FOOT_INSET)
	return Rect2(foot.x - width / 2.0, foot.y - height, width, height)


## Whether a piece's base (room px) is clear of the walls, the door lanes (the room's central cross),
## the spawn markers and everything that already blocks.
static func _camp_spot_free(room: Room, base: Rect2, taken: Array[Rect2]) -> bool:
	var size := room.pixel_size()
	var inside := Rect2(Vector2.ONE * Room.WALL, size - Vector2.ONE * Room.WALL * 2.0)
	if not inside.encloses(base):
		return false
	var margin := Tuning.CAMP_LANE_MARGIN
	var half := Room.DOOR_WIDTH / 2.0 + margin
	var lanes := [Rect2(size.x / 2.0 - half, 0, half * 2.0, size.y), Rect2(0, size.y / 2.0 - half, size.x, half * 2.0)]
	for lane: Rect2 in lanes:
		if lane.intersects(base):
			return false
	for rect in taken:
		if rect.grow(2.0).intersects(base):
			return false
	for marker in room.find_children("*", "Marker2D", true, false):
		if base.grow(10.0).has_point(room.to_local(marker.global_position)):
			return false
	return true


## What already blocks in the room (its props' bodies), in room px.
static func _blocked_rects(room: Room) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child in room.get_children():
		if not child is RoomProp:
			continue
		for shape in child.find_children("*", "CollisionShape2D", true, false):
			if shape.shape is RectangleShape2D:
				var extent: Vector2 = shape.shape.size / 2.0
				var center := room.to_local(shape.global_position)
				rects.append(Rect2(center - extent, extent * 2.0))
	return rects


## A static body on the world layer over `rect` (local to its holder).
static func _base_body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Base"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	return body


static func _camp_light(room: Room, spot: Vector2, color: Color, radius: float, light_name: String) -> void:
	if color.a <= 0.0:
		return
	var light := make_glow(color, Vector2.ONE * radius * 2.0, true)
	light.name = light_name
	light.position = spot
	light.z_index = RoomTheme.GROUND_FX_Z
	room.add_child(light)


# --- Mercader's shop --------------------------------------------------------------------------

## A market stall behind the Mercader, a rug under him, two lanterns and crates (Tuning.SHOP_*). Art
## from assets/sprites/shop/ when the file exists, else plain shapes. Upright pieces stand with the
## actors (y-sorted by their foot); the rug lies on the ground; only the stall has a (low) solid base.
static func _dress_shop(room: Room) -> void:
	var merchant := _merchant_of(room)
	if merchant == null:
		return
	var spot: Vector2 = merchant.position
	var taken: Array[Rect2] = _blocked_rects(room)
	var rug_size := Tuning.SHOP_RUG_SIZE
	var rug_center := (spot + Tuning.SHOP_RUG_OFFSET).round()
	if _shop_floor_ok(room, Rect2(rug_center - rug_size / 2.0, rug_size)):
		var rug := _shop_rug(rug_size)
		rug.name = "ShopRug"
		rug.position = rug_center
		rug.z_index = RoomTheme.GROUND_FX_Z
		room.add_child(rug)
	var stall_foot := (spot + Tuning.SHOP_STALL_OFFSET).round()
	var stall := _shop_stall()
	var stall_base := _shop_base(stall_foot, stall.get_meta(&"width"), Tuning.SHOP_STALL_BASE_HEIGHT)
	if _camp_spot_free(room, stall_base, taken) and _shop_floor_ok(room, stall_base):
		taken.append(stall_base)
		stall.name = "ShopStall"
		stall.position = stall_foot
		stall.add_child(_base_body(Rect2(stall_base.position - stall_foot, stall_base.size)))
		room.add_child(stall)
	else:
		stall.free()
	var lantern_count := 0
	for offset: Vector2 in Tuning.SHOP_LANTERN_OFFSETS:
		var foot := (spot + offset).round()
		var base := Rect2(foot - Vector2(4, 4), Vector2(8, 4))
		if not (_camp_spot_free(room, base, taken) and _shop_floor_ok(room, base)):
			continue
		taken.append(base)
		lantern_count += 1
		var lantern := _shop_lantern()
		lantern.name = "ShopLantern%d" % lantern_count
		lantern.position = foot
		room.add_child(lantern)
		var light_name := "ShopLanternLight%d" % lantern_count
		_camp_light(room, foot + Vector2(0, -12), Tuning.SHOP_LANTERN_LIGHT, Tuning.SHOP_LANTERN_LIGHT_RADIUS, light_name)
		var light := room.get_node_or_null(light_name)
		if light != null:
			var flicker := light.create_tween().set_loops()
			flicker.tween_property(light, "modulate:a", Tuning.SHOP_LANTERN_LIGHT.a * 0.7, 0.35 + 0.1 * lantern_count).set_trans(Tween.TRANS_SINE)
			flicker.tween_property(light, "modulate:a", Tuning.SHOP_LANTERN_LIGHT.a, 0.5).set_trans(Tween.TRANS_SINE)
	var crate_count := 0
	for offset: Vector2 in Tuning.SHOP_CRATES_OFFSETS:
		var foot := (spot + offset).round()
		var base := _shop_base(foot, Tuning.SHOP_CRATES_SIZE.x, Tuning.SHOP_CRATES_BASE_HEIGHT)
		if not (_camp_spot_free(room, base, taken) and _shop_floor_ok(room, base)):
			continue
		taken.append(base)
		crate_count += 1
		var crates := _shop_crates()
		crates.name = "ShopCrates%d" % crate_count
		crates.position = foot
		room.add_child(crates)


## The merchant NPC standing in the room (the one that opens the shop), if any.
static func _merchant_of(room: Room) -> Node2D:
	for child in room.get_children():
		if child is Node2D and "opens_shop" in child and child.opens_shop:
			return child
	return null


## The strip of ground a piece occupies: `width` wide (minus the picture's margins), `height` tall, ending at `foot`.
static func _shop_base(foot: Vector2, width: float, height: float) -> Rect2:
	var inner := width - 2.0 * (1.0 + Tuning.PROP_FOOT_INSET)
	return Rect2(foot.x - inner / 2.0, foot.y - height, inner, height)


## Whether `rect` (room px) lies on floor of the room's own level. Only the temple has anything else
## (lava, other heights, stairs): there the corners and the middle of the rect must be flat floor.
static func _shop_floor_ok(room: Room, rect: Rect2) -> bool:
	var shape := room.get_node_or_null("Shape")
	if shape == null or not "plan" in shape or not shape.plan is TemplePlan:
		return true
	var plan: TemplePlan = shape.plan
	var level := room.height_at(rect.get_center())
	var inset := Vector2(0.01, 0.01)
	for point in [rect.position, rect.end - inset, Vector2(rect.position.x, rect.end.y - 0.01), Vector2(rect.end.x - 0.01, rect.position.y), rect.get_center()]:
		var cell := Vector2i((point / TileArt.TILE).floor())
		if plan.is_lava(cell) or plan.is_stair(cell) or plan.height_at(cell) != level or not plan.is_walkable(cell, level):
			return false
	return true


## A node holding one picture (or a placeholder) with its foot at the node's origin.
static func _shop_picture(file: String, size: Vector2, placeholder: Callable) -> Node2D:
	var holder := Node2D.new()
	var tex := ForestArt.texture(Tuning.SHOP_ART_DIR + file)
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = -Vector2(floorf(tex.get_width() / 2.0), tex.get_height())
		holder.add_child(sprite)
		holder.set_meta(&"width", float(tex.get_width()))
	else:
		placeholder.call(holder)
		holder.set_meta(&"width", size.x)
	return holder


static func _shape_rect(parent: Node2D, rect: Rect2, color: Color) -> void:
	var box := ColorRect.new()
	box.position = rect.position
	box.size = rect.size
	box.color = color
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)


static func _shop_stall() -> Node2D:
	return _shop_picture("stall.png", Tuning.SHOP_STALL_SIZE, func(holder: Node2D) -> void:
		var size := Tuning.SHOP_STALL_SIZE
		_shape_rect(holder, Rect2(-size.x / 2.0 + 4, -size.y + 8, 4, size.y - 8), Color(0.35, 0.22, 0.12))
		_shape_rect(holder, Rect2(size.x / 2.0 - 8, -size.y + 8, 4, size.y - 8), Color(0.35, 0.22, 0.12))
		_shape_rect(holder, Rect2(-size.x / 2.0, -size.y, size.x, 12), Color(0.75, 0.3, 0.22))
		_shape_rect(holder, Rect2(-size.x / 2.0 + 2, -14, size.x - 4, 14), Color(0.5, 0.33, 0.18)))


static func _shop_crates() -> Node2D:
	return _shop_picture("crates.png", Tuning.SHOP_CRATES_SIZE, func(holder: Node2D) -> void:
		_shape_rect(holder, Rect2(-14, -14, 14, 14), Color(0.55, 0.38, 0.2))
		_shape_rect(holder, Rect2(0, -10, 12, 10), Color(0.48, 0.33, 0.17))
		_shape_rect(holder, Rect2(-8, -22, 12, 9), Color(0.6, 0.42, 0.22)))


## The rug lying flat, centered on the node's origin.
static func _shop_rug(size: Vector2) -> Node2D:
	var holder := Node2D.new()
	var tex := ForestArt.texture(Tuning.SHOP_ART_DIR + "rug.png")
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.add_child(sprite)
	else:
		_shape_rect(holder, Rect2(-size / 2.0, size), Color(0.45, 0.14, 0.14))
		_shape_rect(holder, Rect2(-size / 2.0 + Vector2(3, 3), size - Vector2(6, 6)), Color(0.68, 0.45, 0.2))
	return holder


## A lantern on a post: an animated strip of 16 px wide frames, or a plain post with a lit box.
static func _shop_lantern() -> Node2D:
	var holder := Node2D.new()
	var tex := ForestArt.texture(Tuning.SHOP_ART_DIR + "lantern.png")
	if tex != null:
		var width := Tuning.SHOP_LANTERN_FRAME_WIDTH
		var frames := SpriteFrames.new()
		frames.set_animation_speed(&"default", Tuning.SHOP_LANTERN_FPS)
		for i in maxi(tex.get_width() / width, 1):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * width, 0, width, tex.get_height())
			frames.add_frame(&"default", atlas)
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.centered = false
		flame.position = Vector2(-width / 2.0, -tex.get_height())
		flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.add_child(flame)
		flame.play()
	else:
		_shape_rect(holder, Rect2(-1, -16, 2, 16), Color(0.3, 0.2, 0.12))
		_shape_rect(holder, Rect2(-4, -24, 8, 9), Color(1.0, 0.82, 0.4))
	return holder


# --- Helpers ----------------------------------------------------------------------------------

## A node for things lying flat on the ground: with the floors, after every floor tile of the room
## (its origin is the room's bottom, so the y-sort puts it last among them).
static func _floor_layer(room: Room, layer_name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = layer_name
	holder.z_index = RoomTheme.FLOOR_Z
	holder.position = Vector2(0, room.pixel_size().y)
	var content := Node2D.new()
	content.name = "Content"
	content.position = -holder.position
	holder.add_child(content)
	room.add_child(holder)
	return content


## A soft round spot of `color` (fading to nothing at its edge), `size` across, centered. Additive
## for light, normal blending for shade.
static func make_glow(color: Color, size: Vector2, additive: bool) -> Sprite2D:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_glow_texture = texture
	var sprite := Sprite2D.new()
	sprite.texture = _glow_texture
	sprite.scale = size / 64.0
	sprite.modulate = color
	if additive:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = material
	return sprite


## A 1x1 white texture, for particles (CPUParticles2D draws nothing without a texture).
static func pixel() -> Texture2D:
	if _pixel == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_pixel = ImageTexture.create_from_image(image)
	return _pixel
