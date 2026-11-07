class_name LavaSurge
extends Node2D
## The signature mechanic of the temple: in a room whose RoomData has `surge_stages > 0` the lava rises
## level by level. Nico steps deep into the room (farther than `Tuning.TEMPLE_SURGE_TRIGGER_DEPTH` from
## every door), the doors seal with fire, the room warns (tremor, bubbles on the edges, a glow on the
## cells that flood first, a line in the HUD), then the lava creeps in from the edges over the floor
## of level 0 (and, in a second stage, of level 1). Whoever walks on a flooded level and does not fly is
## burned every interval with a Hitbox. Enemies that were already there fight on with waves that
## appear on the safe high ground; enough kills (not by lava) make the lava recede, the floor smokes,
## and the doors open once the room is cleared.
##
## The rules and the clock are `LavaSurgeLogic` (pure). This node is its body: the overlay of animated
## lava tiles (the Shape's own tile set, so it flows with the sea), the seals, the burning, the waves.
## `Level._populate` calls `attach_to` for a surge room and puts the room's own enemies on
## `safe_spawn_cells()`.

const TILE := TemplePlan.TILE
const NEIGHBOURS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const NEIGHBOURS_4: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const PLAYER_ENEMY_MASK := 0b110

var room: Node2D
var plan: TemplePlan
var logic: LavaSurgeLogic
var roster: Array[PackedScene] = []
## Optional: the director's plan and the scenario's weights, applied to the waves like to any enemy.
var director_plan: DirectorPlan
var base_weights: Dictionary = {}
## The map's seed (0 outside a Level): with the room's place, it seeds the waves' draws.
var map_seed := 0

var _rng := RandomNumberGenerator.new()
## Level -> its cells in the order the lava covers them, and the cells that flood first.
var _order := {0: [] as Array[Vector2i], 1: [] as Array[Vector2i]}
var _edge := {0: [] as Array[Vector2i], 1: [] as Array[Vector2i]}
var _shown := {0: 0, 1: 0}
var _candidates := {}
var _border := {}
var _covered := {}
var _lava_layer: TileMapLayer
var _rim_layer: TileMapLayer
var _glow: Glow
var _seals: Array[StaticBody2D] = []
var _seal_nodes: Array[Node] = []
var _hitbox: Hitbox
var _burn_clock := 0.0
var _burn_queue: Array[Node] = []
var _burning: Node
## Instance ids of what the lava aimed at: a death of one of them is not a kill.
var _lava_victims := {}
var _seal_pulses: Array[Tween] = []
var _stalled := 0
var _burn_frames := 0
var _incoming := 0
var _bubble_clock := 0.0
var _time := 0.0
var _open := false
var _said_receding := false


## Adds a surge to a room whose RoomData has stages and returns it (null if the room has none, the
## feature is off or the room has no temple plan). `roster` is the map's enemy list for the waves.
## An empty `enemies` falls back to the roster or the scenario's pool found above the room (a Level),
## then to `fallback_pool`. `map_seed` joins the room's place in seeding the waves' draws, so the same
## seed gives the same fight.
static func attach_to(target: Node, enemies: Array[PackedScene], fallback_pool: Array[PackedScene] = [], map_seed := 0) -> Node:
	if not Tuning.TEMPLE_SURGE_ENABLED or target == null or target.get("data") == null:
		return null
	if target.data.surge_stages <= 0:
		return null
	var shape := target.get_node_or_null("Shape")
	if shape == null or not ("plan" in shape):
		return null
	var surge := LavaSurge.new()
	surge.name = "LavaSurge"
	surge.room = target
	surge.roster = enemies if not enemies.is_empty() else _find_pool(target, fallback_pool)
	surge.map_seed = map_seed
	target.add_child(surge)
	return surge


static func _find_pool(target: Node, fallback_pool: Array[PackedScene]) -> Array[PackedScene]:
	var node := target.get_parent()
	while node != null:
		var roster: Variant = node.get("roster")
		if roster is Array and not roster.is_empty():
			var found: Array[PackedScene] = []
			found.assign(roster)
			return found
		var scenario: Variant = node.get("scenario")
		if scenario != null and scenario.get("enemy_pool") is Array and not scenario.enemy_pool.is_empty():
			var pool: Array[PackedScene] = []
			pool.assign(scenario.enemy_pool)
			return pool
		node = node.get_parent()
	return fallback_pool


func _ready() -> void:
	var shape := room.get_node("Shape")
	plan = shape.plan if shape.plan != null else TemplePlan.parse(shape.rows)
	_rng.seed = hash([map_seed, Vector2i(room.global_position)]) + 7
	logic = LavaSurgeLogic.new(room.data.surge_stages, room.data.kills_stage_1, room.data.kills_to_recede)
	room.cleared.connect(_on_room_cleared)
	Events.enemy_killed.connect(_on_enemy_killed)
	_build_flood()
	_build_layers()
	_build_hitbox()


func _exit_tree() -> void:
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)


# --- public ------------------------------------------------------------------------------------------------------
## The `spawn_ok` cells of the level that stays safe at the end: where the room's own enemies and every
## wave appear, so the fight is always reachable.
func safe_spawn_cells() -> Array[Vector2i]:
	var level := 1 if room.data.surge_stages == 1 else TemplePlan.MAX_HEIGHT
	var cells: Array[Vector2i] = []
	for cell in plan.level_regions()[level]:
		if plan.height_at(cell) == level and plan.spawn_ok(cell):
			cells.append(cell)
	return cells


## Cells the lava covers right now.
func overlay_cell_count() -> int:
	return _covered.size()


## Cells level `level` will have when fully flooded.
func flood_total(level: int) -> int:
	return _order[level].size()


# --- the flood: which cells, in which order -----------------------------------------------------------------------------
## Level by level, the cells of the level in the order the lava reaches them: a breadth-first search
## from the cells that touch liquid (lava, the wall ring, a level already flooded), with a little jitter
## per cell so the front is ragged, not a ruler.
func _build_flood() -> void:
	var lower := {}
	for level in 2:
		var cells := {}
		for y in plan.rows:
			for x in plan.columns:
				var cell := Vector2i(x, y)
				var c := plan.cell_at(cell)
				if room.is_wall_cell(cell) or c == TemplePlan.LAVA or c == TemplePlan.MASONRY:
					continue
				if plan.height_at(cell) == level:
					cells[cell] = true
		var distance := {}
		var queue: Array[Vector2i] = []
		for cell in cells:
			for n in NEIGHBOURS_8:
				if _is_liquid_for_flood(cell + n, lower):
					distance[cell] = 0
					queue.append(cell)
					break
		var edge: Array[Vector2i] = queue.duplicate()
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			for n in NEIGHBOURS_4:
				var next: Vector2i = cell + n
				if cells.has(next) and not distance.has(next):
					distance[next] = distance[cell] + 1
					queue.append(next)
		var farthest := 0
		for cell in distance:
			farthest = maxi(farthest, distance[cell])
		var keyed: Array = []
		for cell in cells:
			var d: int = distance.get(cell, farthest + 1)
			keyed.append([float(d) + float(absi(hash(cell)) % 1000) / 1000.0 * 0.9, cell])
		keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var order: Array[Vector2i] = []
		for pair in keyed:
			order.append(pair[1])
		_order[level] = order
		_edge[level] = edge
		for cell in cells:
			lower[cell] = true
			_candidates[cell] = true
	# Lava cells (and the wall ring) beside a flooded cell are repainted when it floods, so the crust
	# along the new shore is right.
	for cell in _candidates:
		for n in NEIGHBOURS_8:
			var other: Vector2i = cell + n
			if _candidates.has(other) or not plan.in_grid(other):
				continue
			if plan.is_lava(other) or room.is_wall_cell(other):
				_border[other] = true


func _is_liquid_for_flood(cell: Vector2i, lower: Dictionary) -> bool:
	if not plan.in_grid(cell) or room.is_wall_cell(cell) or plan.is_lava(cell):
		return true
	return lower.has(cell)


func _is_liquid(cell: Vector2i) -> bool:
	if not plan.in_grid(cell) or room.is_wall_cell(cell) or plan.is_lava(cell):
		return true
	return _covered.has(cell)


func _build_layers() -> void:
	_lava_layer = _new_layer("FloodLava")
	_rim_layer = _new_layer("FloodRim")
	_glow = Glow.new()
	_glow.name = "FloodGlow"
	_glow.z_index = RoomTheme.GROUND_FX_Z
	add_child(_glow)


func _new_layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.z_index = RoomTheme.GROUND_FX_Z
	layer.tile_set = TempleShape.animated_tile_set()
	layer.modulate = Tuning.TEMPLE_LAVA_MODULATE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.scale = Vector2.ONE * TileArt.draw_scale()
	add_child(layer)
	return layer


func _repaint(cell: Vector2i) -> void:
	var show := false
	if _candidates.has(cell):
		show = _covered.has(cell)
	elif _border.has(cell):
		for n in NEIGHBOURS_8:
			if _covered.has(cell + n):
				show = true
				break
	if not show:
		_lava_layer.erase_cell(cell)
		_rim_layer.erase_cell(cell)
		return
	var frames := TileArt.profile().animation(StringName("lava_m_%d_%d" % [cell.x % 4, cell.y % 4]))
	_lava_layer.set_cell(cell, 0, frames[0])
	var mask := TileArt.blob_mask(_is_liquid, cell)
	if mask == 255:
		_rim_layer.erase_cell(cell)
	else:
		_rim_layer.set_cell(cell, 0, TileArt.blob47_tile(&"lava_rim", mask))


func _set_covered(cell: Vector2i, covered: bool) -> void:
	if covered:
		_covered[cell] = true
	else:
		_covered.erase(cell)
	_repaint(cell)
	for n in NEIGHBOURS_8:
		_repaint(cell + n)


## Brings the covered cells of each level to what the logic says (the rise creeps in, the recede
## empties in reverse, and the floor it leaves steams).
func _update_overlay() -> void:
	for level in 2:
		var order: Array[Vector2i] = _order[level]
		var target := ceili(logic.level_fraction(level) * order.size() - 0.001)
		while _shown[level] < target:
			_set_covered(order[_shown[level]], true)
			_shown[level] += 1
		while _shown[level] > target:
			_shown[level] -= 1
			var cell := order[_shown[level]]
			_set_covered(cell, false)
			if absi(hash(cell)) % 2 == 0:
				_steam(cell)


# --- clock -------------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_time += delta
	if logic.state == LavaSurgeLogic.State.IDLE:
		_watch_for_trigger()
		return
	if logic.state != LavaSurgeLogic.State.DONE:
		for event in logic.step(delta):
			_on_event(event)
		_update_overlay()
		_update_warning(delta)
		_update_burning(delta)
		_check_stall()
	_run_hitbox()


func _watch_for_trigger() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	# Nothing left to fight before Nico stepped in: the room is simply cleared, no trap is sprung.
	if room.cleared_once:
		return
	var local := room.to_local(player.global_position)
	if not Rect2(Vector2.ZERO, room.pixel_size()).has_point(local):
		return
	for door in room.open_doors:
		if local.distance_to(_door_point(door)) <= Tuning.TEMPLE_SURGE_TRIGGER_DEPTH:
			return
	room.clear_held = true
	logic.start()
	_seal_doors()


func _on_event(event: StringName) -> void:
	match event:
		&"warn":
			Events.lava_surge_warned.emit(room, logic.stage + 1)
			var key := "temple_surge_warning" if logic.stage == 0 else "temple_surge_rising"
			Events.message_requested.emit(UiText.t(key))
		&"rise":
			Events.lava_surge_started.emit(room, logic.stage)
		&"spawn_wave":
			_request_wave()
		&"recede":
			if not _said_receding:
				_said_receding = true
				Events.message_requested.emit(UiText.t("temple_surge_receding"))
		&"receded":
			Events.lava_surge_receded.emit(room)
			room.release_clear()
			if room.enemies_alive == 0:
				_open_doors()


## A fight that cannot go on: nothing can be sent as a wave and nothing is alive. Without enemies to
## pick it is won at once; with no free cell, after a few wave intervals.
func _check_stall() -> void:
	if logic.state != LavaSurgeLogic.State.FIGHT or room.enemies_alive > 0 or _incoming > 0:
		return
	if roster.is_empty() or _stalled >= Tuning.TEMPLE_SURGE_STALL_INTERVALS:
		logic.win_now()


func _on_room_cleared() -> void:
	if logic.state == LavaSurgeLogic.State.DONE:
		_open_doors()


func _on_enemy_killed(enemy: Node) -> void:
	if not is_instance_valid(enemy) or _lava_victims.has(enemy.get_instance_id()) \
			or not room.is_ancestor_of(enemy):
		return
	logic.on_kill()


# --- warning -------------------------------------------------------------------------------------------------------------
## Before a rise: the cells that flood first glow and bubbles burst along the edge.
func _update_warning(delta: float) -> void:
	var warning := logic.state == LavaSurgeLogic.State.WARNING
	if not warning:
		_glow.cells = []
		_glow.queue_redraw()
		return
	var level := mini(logic.stage, 1)
	var ramp := 1.0 - logic.warning_left() / Tuning.TEMPLE_SURGE_WARN_SECONDS
	_glow.cells = _first_ring(level)
	_glow.tint = Tuning.TEMPLE_SURGE_WARN_GLOW_COLOR
	_glow.alpha = Tuning.TEMPLE_SURGE_WARN_GLOW * (0.35 + 0.65 * ramp) * (0.6 + 0.4 * sin(_time * 9.0))
	_glow.queue_redraw()
	_bubble_clock -= delta
	var edge: Array[Vector2i] = _edge[level]
	if _bubble_clock <= 0.0 and not edge.is_empty():
		_bubble_clock = Tuning.TEMPLE_SURGE_BUBBLE_EVERY
		var cell := edge[_rng.randi_range(0, edge.size() - 1)]
		var ring := Ring.new()
		ring.bubble = true
		ring.radius = _rng.randf_range(Tuning.TEMPLE_SURGE_BUBBLE_RADIUS.x, Tuning.TEMPLE_SURGE_BUBBLE_RADIUS.y)
		ring.life = Tuning.TEMPLE_SURGE_BUBBLE_LIFE
		ring.color = Tuning.TEMPLE_SURGE_BUBBLE_COLOR
		ring.position = Vector2(cell * TILE) + Vector2(_rng.randf_range(2.0, 14.0), _rng.randf_range(2.0, 14.0))
		ring.z_index = RoomTheme.GROUND_FX_Z
		room.add_child(ring)


func _first_ring(level: int) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	var order: Array[Vector2i] = _order[level]
	var edge: Array[Vector2i] = _edge[level]
	for cell in edge:
		ring.append(cell)
	for cell in order:
		if ring.size() >= edge.size() + edge.size() / 2:
			break
		if not ring.has(cell):
			ring.append(cell)
	return ring


## The middle of a door's edge, in room pixels.
func _door_point(door: Vector2i) -> Vector2:
	var size: Vector2 = room.pixel_size()
	var middle := size / 2.0
	match door:
		Vector2i.UP:
			return Vector2(middle.x, 0.0)
		Vector2i.DOWN:
			return Vector2(middle.x, size.y)
		Vector2i.LEFT:
			return Vector2(0.0, middle.y)
	return Vector2(size.x, middle.y)


# --- seals -------------------------------------------------------------------------------------------------------------
func _seal_doors() -> void:
	var size: Vector2 = room.pixel_size()
	var wall := float(Room.WALL)
	var gap := float(Room.DOOR_WIDTH)
	for door in room.open_doors:
		var rect: Rect2
		match door:
			Vector2i.UP:
				rect = Rect2((size.x - gap) / 2.0, 0, gap, wall)
			Vector2i.DOWN:
				rect = Rect2((size.x - gap) / 2.0, size.y - wall, gap, wall)
			Vector2i.LEFT:
				rect = Rect2(0, (size.y - gap) / 2.0, wall, gap)
			_:
				rect = Rect2(size.x - wall, (size.y - gap) / 2.0, wall, gap)
		var body := StaticBody2D.new()
		body.name = "Seal%d%d" % [door.x + 1, door.y + 1]
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		_seals.append(body)
		_seal_fire(rect, door)


## A wall of fire in the gap: a pulsing bar on the floor and braziers whose flames are the strip of
## TempleProp, one every tile, y-sorted with the actors.
func _seal_fire(rect: Rect2, door: Vector2i) -> void:
	var bar := ColorRect.new()
	bar.color = Tuning.TEMPLE_SURGE_SEAL_COLOR
	bar.position = rect.position
	bar.size = rect.size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = RoomTheme.GROUND_FX_Z
	bar.modulate.a = 0.0
	add_child(bar)
	_seal_nodes.append(bar)
	var pulse := bar.create_tween().set_loops()
	_seal_pulses.append(pulse)
	var alphas := Tuning.TEMPLE_SURGE_SEAL_PULSE_ALPHAS
	pulse.tween_property(bar, "modulate:a", alphas.y, Tuning.TEMPLE_SURGE_SEAL_PULSE_SECONDS)
	pulse.tween_property(bar, "modulate:a", alphas.x, Tuning.TEMPLE_SURGE_SEAL_PULSE_SECONDS)
	var horizontal := door.y != 0
	var count := int((rect.size.x if horizontal else rect.size.y) / TILE)
	for i in count:
		var prop := TempleProp.new()
		prop.kind = TempleProp.Kind.BRAZIER
		if horizontal:
			prop.position = Vector2(rect.position.x + TILE * (i + 0.5), rect.end.y)
		else:
			prop.position = Vector2(rect.get_center().x, rect.position.y + TILE * (i + 1.0) - 2.0)
		prop.modulate.a = 0.0
		room.add_child(prop)
		prop.create_tween().tween_property(prop, "modulate:a", 1.0, Tuning.TEMPLE_SURGE_SEAL_FADE_IN)
		_seal_nodes.append(prop)


func _open_doors() -> void:
	if _open:
		return
	_open = true
	for body in _seals:
		body.queue_free()
	_seals.clear()
	for pulse in _seal_pulses:
		pulse.kill()
	_seal_pulses.clear()
	for node in _seal_nodes:
		if is_instance_valid(node):
			var canvas := node as CanvasItem
			var fade := canvas.create_tween()
			fade.tween_property(canvas, "modulate:a", 0.0, Tuning.TEMPLE_SURGE_SEAL_FADE_OUT)
			fade.tween_callback(canvas.queue_free)
	_seal_nodes.clear()


# --- burning -----------------------------------------------------------------------------------------------------------
func _build_hitbox() -> void:
	_hitbox = Hitbox.new()
	_hitbox.name = "LavaHitbox"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = PLAYER_ENEMY_MASK
	_hitbox.damage = Tuning.TEMPLE_SURGE_DAMAGE
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	_hitbox.add_child(shape)
	_hitbox.hit_landed.connect(func(_hurtbox: Hurtbox) -> void: _finish_burn())
	add_child(_hitbox)


## Every interval, whoever stands on lava (a covered cell of a flooded level) and does not fly is
## queued; the hitbox visits them one by one.
func _update_burning(delta: float) -> void:
	if _covered.is_empty():
		_burn_clock = 0.0
		return
	_burn_clock += delta
	if _burn_clock < Tuning.TEMPLE_SURGE_DAMAGE_INTERVAL:
		return
	_burn_clock = 0.0
	var targets: Array[Node] = []
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		targets.append(player)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if room.is_ancestor_of(enemy):
			targets.append(enemy)
	for target in targets:
		if _burns(target) and not _burn_queue.has(target):
			_burn_queue.append(target)


func _burns(target: Node) -> bool:
	if not is_instance_valid(target) or not (target is CollisionObject2D):
		return false
	var health: Variant = target.get("health")
	if health != null and health.is_dead():
		return false
	if Heights.is_flyer(target) or target.get_node_or_null("Hurtbox") == null:
		return false
	var cell := Vector2i((room.to_local(target.global_position) / TILE).floor())
	var flooded := logic.flooded_levels()
	return _covered.has(cell) and plan.height_at(cell) < flooded and Heights.level_of(target) < flooded


func _run_hitbox() -> void:
	if _burning != null:
		_burn_frames -= 1
		if not is_instance_valid(_burning) or _burn_frames <= 0:
			_finish_burn()
		return
	while not _burn_queue.is_empty():
		var target: Node = _burn_queue.pop_front()
		if not _burns(target):
			continue
		var hurtbox := target.get_node("Hurtbox") as Node2D
		_burning = target
		_lava_victims[target.get_instance_id()] = true
		_burn_frames = Tuning.TEMPLE_SURGE_HIT_FRAMES
		_hitbox.global_position = hurtbox.global_position
		_hitbox.activate()
		return


func _finish_burn() -> void:
	_hitbox.deactivate()
	# One that survived the burn is a normal enemy again: killing it later counts.
	if is_instance_valid(_burning):
		var health: Variant = _burning.get("health")
		if health == null or not health.is_dead():
			_lava_victims.erase(_burning.get_instance_id())
	_burning = null


# --- waves -------------------------------------------------------------------------------------------------------------
func _request_wave() -> void:
	var free_slots: int = room.data.max_alive - room.enemies_alive - _incoming
	var count := mini(room.data.wave_size, free_slots)
	if roster.is_empty():
		_stalled += 1
		return
	if count <= 0:
		return
	var cells := _pick_wave_cells(count)
	if cells.is_empty():
		_stalled += 1
		return
	_stalled = 0
	var picks := Room.pick_enemies(roster, cells.size(), _rng, director_plan, base_weights)
	for i in cells.size():
		_incoming += 1
		var ring := Ring.new()
		ring.radius = Tuning.TEMPLE_SURGE_RING_RADIUS
		ring.life = Tuning.TEMPLE_SURGE_SPAWN_WARN
		ring.color = Tuning.TEMPLE_SURGE_RING_COLOR
		ring.position = Vector2(cells[i] * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
		ring.z_index = RoomTheme.GROUND_FX_Z
		room.add_child(ring)
		var scene := picks[i]
		var cell := cells[i]
		# A tween of this node dies with it (a freed map never spawns).
		var wait := create_tween()
		wait.tween_interval(Tuning.TEMPLE_SURGE_SPAWN_WARN)
		wait.tween_callback(_spawn_enemy.bind(scene, cell))


## Safe cells at least `SPAWN_MIN_DISTANCE` cells from Nico and clear of other enemies and chosen cells.
func _pick_wave_cells(count: int, chosen: Array[Vector2i] = []) -> Array[Vector2i]:
	var cells := safe_spawn_cells()
	for i in range(cells.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var taken: Array[Vector2i] = chosen.duplicate()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if room.is_ancestor_of(enemy):
			taken.append(Vector2i((room.to_local(enemy.global_position) / TILE).floor()))
	var picked: Array[Vector2i] = []
	for cell in cells:
		if picked.size() >= count:
			break
		if player != null:
			var nico := room.to_local(player.global_position) / TILE
			if Vector2(cell).distance_to(nico.floor()) < float(Tuning.TEMPLE_SURGE_SPAWN_MIN_DISTANCE):
				continue
		if taken.any(func(t: Vector2i) -> bool: return maxi(absi(t.x - cell.x), absi(t.y - cell.y)) <= 1):
			continue
		picked.append(cell)
		taken.append(cell)
	return picked


func _spawn_enemy(scene: PackedScene, cell: Vector2i) -> void:
	_incoming = maxi(_incoming - 1, 0)
	if not is_inside_tree() or logic.state != LavaSurgeLogic.State.FIGHT:
		return
	# Nico may have walked up to the ring: look for another cell, or let this one go.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and Vector2(cell).distance_to((room.to_local(player.global_position) / TILE).floor()) \
			< float(Tuning.TEMPLE_SURGE_SPAWN_MIN_DISTANCE):
		var other := _pick_wave_cells(1)
		if other.is_empty():
			return
		cell = other[0]
	var enemy: Node2D = scene.instantiate()
	enemy.position = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	if director_plan != null:
		director_plan.apply_to_enemy(enemy)
	room.add_child(enemy)
	Placement.reset(enemy)
	room.register_enemy(enemy)
	var puff := Ring.new()
	puff.bubble = true
	puff.radius = Tuning.TEMPLE_SURGE_PUFF_RADIUS
	puff.life = Tuning.TEMPLE_SURGE_PUFF_LIFE
	puff.color = Tuning.TEMPLE_SURGE_RING_COLOR
	puff.position = enemy.position
	puff.z_index = RoomTheme.GROUND_FX_Z
	room.add_child(puff)


# --- steam -------------------------------------------------------------------------------------------------------------
## Smoke over a cell the lava just left, for `STEAM_SECONDS`.
func _steam(cell: Vector2i) -> void:
	var steam := CPUParticles2D.new()
	steam.position = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	steam.amount = Tuning.TEMPLE_SURGE_STEAM_AMOUNT
	steam.lifetime = Tuning.TEMPLE_SURGE_STEAM_LIFETIME
	steam.direction = Vector2.UP
	steam.spread = 30.0
	steam.gravity = Vector2(0, -Tuning.TEMPLE_SURGE_STEAM_RISE)
	steam.initial_velocity_min = Tuning.TEMPLE_SURGE_STEAM_SPEED.x
	steam.initial_velocity_max = Tuning.TEMPLE_SURGE_STEAM_SPEED.y
	steam.scale_amount_min = Tuning.TEMPLE_SURGE_STEAM_SCALE.x
	steam.scale_amount_max = Tuning.TEMPLE_SURGE_STEAM_SCALE.y
	steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	steam.emission_rect_extents = Vector2(6, 4)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Tuning.TEMPLE_SURGE_STEAM_COLOR, Tuning.TEMPLE_SURGE_STEAM_FADE])
	steam.color_ramp = fade
	steam.z_index = RoomTheme.GROUND_FX_Z + 1
	room.add_child(steam)
	# The steam's own tween, so it goes with the particles if the map is freed.
	var life := steam.create_tween()
	life.tween_interval(Tuning.TEMPLE_SURGE_STEAM_SECONDS)
	life.tween_callback(steam.set.bind("emitting", false))
	life.tween_interval(steam.lifetime + 0.1)
	life.tween_callback(steam.queue_free)


# --- small drawings ----------------------------------------------------------------------------------------------------
## A glow over the cells that flood first.
class Glow extends Node2D:
	var cells: Array[Vector2i] = []
	var alpha := 0.0
	var tint := Color.WHITE

	func _draw() -> void:
		for cell in cells:
			draw_rect(Rect2(Vector2(cell * TemplePlan.TILE), Vector2.ONE * TemplePlan.TILE),
					Color(tint, alpha))


## A ring that closes in on the spot where an enemy will appear, or a bubble that bursts.
class Ring extends Node2D:
	var radius := 12.0
	var life := 0.8
	var color := Color.WHITE
	var bubble := false
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_age / life, 0.0, 1.0)
		if bubble:
			draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * t), Color(color, color.a * (1.0 - t)))
			return
		var r := radius * lerpf(Tuning.TEMPLE_SURGE_RING_SPAN.x, Tuning.TEMPLE_SURGE_RING_SPAN.y, t)
		var flicker := 0.7 + 0.3 * sin(_age * 40.0)
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.18 * t))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(color, color.a * flicker), 2.0)
