class_name PossessedVase
extends Enemy
## Vasija poseída (island 3): a temple vase with something inside. When it appears it scatters a few
## harmless decoy vases (VaseDecoy) around itself in its room, and looks just like them: the same
## still frame, it never walks, statuses do not show on it. When Nico passes near it, it shakes
## (the warning), breaks and releases a creature (its data's `creature_scene`) that hunts him; the
## broken vase is gone. A hit (or a push) on it while whole breaks it at once, like the decoys.
## The vase leaves the room's count only when its creature dies (it reports `died` then), so the
## room is not cleared while the creature lives. Everything tunable lives in its PossessedVaseData.

enum Phase { DISGUISED, SHAKE, BREAK, RELEASED }

const ENEMY_LAYER := 3
## What a decoy may not overlap: walls, ponds and bodies (other enemies, Nico).
const DECOY_BLOCKING_MASK := (1 << (WORLD_LAYER - 1)) | (1 << (WATER_LAYER - 1)) | (1 << (ENEMY_LAYER - 1)) | (1 << 1)
const DECOY_ATTEMPTS := 32
## Decoys are placed on the second physics tick: by then the room's walls are in the physics space.
const DECOY_DELAY_TICKS := 2

var phase: Phase = Phase.DISGUISED

var _vase: PossessedVaseData
var _phase_left := 0.0
var _break_clock := 0.0
var _released := false
var _creature_gone := false
var _creature: Enemy
var _decoys: Array[VaseDecoy] = []
var _decoys_placed := false
var _decoy_shadows := false
var _ticks := 0


func _ready() -> void:
	super()
	_vase = data as PossessedVaseData
	if _vase == null:
		push_error("PossessedVase '%s' needs a PossessedVaseData." % name)
		_vase = PossessedVaseData.new()


func _physics_process(delta: float) -> void:
	_ticks += 1
	if not _decoys_placed and _ticks >= DECOY_DELAY_TICKS:
		_scatter_decoys()
	_sync_decoy_shadows()
	_process_vase(delta)
	super(delta)
	var shadow := get_node_or_null(^"Shadow") as CanvasItem
	if shadow != null:
		shadow.visible = phase != Phase.RELEASED


func _exit_tree() -> void:
	for decoy in _decoys:
		if is_instance_valid(decoy) and not decoy.is_queued_for_deletion():
			decoy.queue_free()
	_decoys.clear()
	if is_instance_valid(_creature) and not _creature.is_queued_for_deletion():
		_creature.queue_free()


## True until it breaks.
func is_whole() -> bool:
	return phase in [Phase.DISGUISED, Phase.SHAKE]


## The decoy vases it scattered that are still standing.
func decoys() -> Array[VaseDecoy]:
	var standing: Array[VaseDecoy] = []
	for decoy in _decoys:
		if is_instance_valid(decoy) and not decoy.is_broken():
			standing.append(decoy)
	return standing


## The creature it released (null before it breaks or once the creature is gone).
func creature() -> Enemy:
	return _creature if is_instance_valid(_creature) else null


# A vase is not pushed, rooted, slowed, shielded or frenzied (a tint would give it away); a push
# breaks it like a hit.
func apply_knockback(_push: Vector2) -> void:
	if is_whole():
		_break()


func apply_root(_duration: float) -> void:
	pass


func apply_slow(_factor: float, _duration: float) -> void:
	pass


func apply_shield(_duration: float) -> void:
	pass


func apply_frenzy(_speed_factor: float, _cooldown_rate: float, _duration: float) -> void:
	pass


# --- Behaviour ---------------------------------------------------------------------------------

func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO


func _process_patrol(_delta: float) -> void:
	velocity = Vector2.ZERO


func _process_chase(_delta: float) -> void:
	velocity = Vector2.ZERO
	if phase == Phase.DISGUISED and _target_is_valid() \
			and global_position.distance_to(target.global_position) <= _vase.trigger_radius:
		phase = Phase.SHAKE
		_phase_left = _vase.shake_time


## The shake and the break run on their own clock, whatever the base state does meanwhile.
func _process_vase(delta: float) -> void:
	match phase:
		Phase.SHAKE:
			_phase_left -= delta
			if _phase_left <= 0.0:
				_break()
		Phase.BREAK:
			_break_clock += delta
			if not _released and _break_clock >= _vase.release_delay:
				_release()
			if _break_clock >= _break_length():
				phase = Phase.RELEASED
				if _sprite != null:
					_sprite.visible = false
				if _creature_gone:
					_finish()


func _on_hurtbox_hit(_damage: int, _from_position: Vector2) -> void:
	_interrupt_attack()
	if is_whole():
		_break()


func _break() -> void:
	if not is_whole():
		return
	phase = Phase.BREAK
	_break_clock = 0.0
	velocity = Vector2.ZERO
	set_collision_layer_value(ENEMY_LAYER, false)
	_collision.set_deferred("disabled", true)
	_hurtbox.get_node("CollisionShape2D").set_deferred("disabled", true)
	# The broken vase is no longer an enemy to aim at; its creature is.
	remove_from_group("enemies")
	Events.enemy_attacked.emit(self, &"summon")


func _release() -> void:
	_released = true
	var parent := get_parent()
	if parent == null or _vase.creature_scene == null:
		_creature_gone = true
		return
	var spirit := _vase.creature_scene.instantiate() as Enemy
	if spirit == null:
		_creature_gone = true
		return
	spirit.health_multiplier = health_multiplier
	spirit.speed_multiplier = speed_multiplier
	spirit.damage_multiplier = damage_multiplier
	spirit.vision_multiplier = vision_multiplier
	spirit.patrol_multiplier = patrol_multiplier
	spirit.home_area = home_area
	var toward := Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		toward = (player.global_position - global_position).normalized()
	spirit.position = position + toward * _vase.creature_offset
	parent.add_child(spirit)
	Placement.reset(spirit)
	if has_node(ActorShadow.NODE_NAME):
		ActorShadow.attach(spirit)
	spirit.died.connect(_on_creature_died)
	_creature = spirit


func _on_creature_died() -> void:
	_creature = null
	_creature_gone = true
	if phase == Phase.RELEASED:
		_finish()


## Only now does the vase leave its room's count.
func _finish() -> void:
	died.emit()
	queue_free()


func _break_length() -> float:
	if _sprite == null:
		return _vase.release_delay
	var length := 0.0
	for anim: StringName in [&"special", &"death"]:
		if _sprite.sprite_frames.has_animation(anim):
			length += _animation_length(anim)
	return maxf(length, _vase.release_delay)


# --- Decoys ------------------------------------------------------------------------------------

func _scatter_decoys() -> void:
	_decoys_placed = true
	var parent := get_parent()
	if parent == null or _vase.decoy_scene == null:
		return
	var probe := CircleShape2D.new()
	probe.radius = _vase.decoy_clearance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = DECOY_BLOCKING_MASK
	query.exclude = [get_rid()]
	var count := randi_range(_vase.decoy_count_min, _vase.decoy_count_max)
	var spots: Array[Vector2] = []
	for attempt in DECOY_ATTEMPTS:
		if spots.size() >= count:
			break
		var spot := global_position + Vector2.from_angle(randf() * TAU) \
				* randf_range(_vase.decoy_min_distance, _vase.decoy_max_distance)
		if _decoy_spot_ok(spot, spots, query):
			spots.append(spot)
	for spot in spots:
		var decoy := _vase.decoy_scene.instantiate() as VaseDecoy
		if decoy == null:
			return
		decoy.dress(data.sprite_frames, data.sprite_offset, data.sprite_scale)
		decoy.position = (parent as Node2D).to_local(spot) if parent is Node2D else spot
		parent.add_child(decoy)
		_decoys.append(decoy)


## Inside its room, off the lanes between the doors, apart from the other vases and Nico, and on
## free floor.
func _decoy_spot_ok(spot: Vector2, taken: Array[Vector2], query: PhysicsShapeQueryParameters2D) -> bool:
	if home_area.has_area():
		if not home_area.grow(-Tuning.PATROL_MARGIN).has_point(spot):
			return false
		var center := home_area.get_center()
		if absf(spot.x - center.x) < _vase.door_lane_half_width or absf(spot.y - center.y) < _vase.door_lane_half_width:
			return false
	for other in taken:
		if other.distance_to(spot) < _vase.decoy_spacing:
			return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(spot) < _vase.decoy_spacing:
		return false
	query.transform = Transform2D(0.0, spot)
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## The level gives actors their shadows after filling the rooms; the decoys copy the real vase's,
## or the one without a shadow would be easy to spot.
func _sync_decoy_shadows() -> void:
	if _decoy_shadows or not _decoys_placed or not has_node(ActorShadow.NODE_NAME):
		return
	_decoy_shadows = true
	for decoy in _decoys:
		if is_instance_valid(decoy):
			ActorShadow.attach(decoy)


# --- Animation ---------------------------------------------------------------------------------

## Whole: the decoys' still frame (shaking from side to side during the warning); breaking: `special`
## (the creature bursting out), then `death` (the shards); then nothing.
func _update_animation() -> void:
	if _sprite == null:
		return
	_sprite.speed_scale = 1.0
	_sprite.position = data.sprite_offset
	match phase:
		Phase.DISGUISED, Phase.SHAKE:
			_sprite.flip_h = false
			if _sprite.animation != &"idle" or _sprite.frame != 0 or _sprite.is_playing():
				_sprite.play(&"idle")
				_sprite.pause()
				_sprite.frame = 0
			if phase == Phase.SHAKE:
				var side := 1.0 if posmod(Engine.get_physics_frames(), 4) < 2 else -1.0
				_sprite.position.x += side * _vase.shake_amplitude
		Phase.BREAK:
			var special_length := _animation_length(&"special") if _sprite.sprite_frames.has_animation(&"special") else 0.0
			var wanted: StringName = &"special" if _break_clock < special_length else &"death"
			if _sprite.animation != wanted and _sprite.sprite_frames.has_animation(wanted):
				_sprite.play(wanted)
