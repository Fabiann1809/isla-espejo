class_name RoomDressing
extends RefCounted
## Decoration that tells the special rooms apart at a glance, added by Level after it fills a room:
## - boss arena: darker ground, roots on the floor, a ring of standing stones, torches at its doors;
## - reward glade: a pool of warm light around the chest and a few flowers;
## - event camp: the campfire's flickering light and a signpost by the way in.
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
	if Tuning.CAMP_SIGN and not room.open_doors.is_empty():
		var sign_spot := _beside_door(room, room.open_doors[0])[0]
		var holder := Node2D.new()
		holder.name = "CampSign"
		holder.position = sign_spot.round()
		holder.add_child(TileArt.sprite(TileArt.SIGN, Vector2(-8, -15)))
		room.add_child(holder)


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
