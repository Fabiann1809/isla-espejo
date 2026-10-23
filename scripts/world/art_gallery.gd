extends Node2D
## Debug scene, outside the game flow: every character with its real art in one labeled row.
## Open scenes/levels/art_gallery.tscn in Godot and press F6. Left/right (move_left / move_right)
## pick a character, up/down (move_up / move_down) step through its animations, interact (E)
## replays the current one. The art is read from the game's own data (SpriteFrames, sprite_scale,
## sprite_offset, NPC scenes); nothing is copied here.

const SPACING := 72.0
## Animations listed first, in this order; any other one the SpriteFrames has follows alphabetically.
const ANIMATION_ORDER: Array[StringName] = [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"]
## Pause before a one-shot animation (attack, hurt, death) plays again.
const REPLAY_DELAY := 0.8
const SELECTED := Color(1.0, 0.95, 0.4)
const UNSELECTED := Color(0.75, 0.75, 0.75)

## `label` and where the art comes from: `data` (an EnemyData/BossData .tres), `npc` (an NPC scene),
## `npc_frames` (SpriteFrames shown on a plain NPC), `scene` + `node` (an AnimatedSprite2D inside a
## scene, read without running the scene) or `frames` (SpriteFrames with no game data yet: scale 1).
const ENTRIES := [
	{"label": "Nico", "scene": "res://scenes/player/player.tscn", "node": "Sprite"},
	{"label": "Anciano", "npc": "res://scenes/npcs/elder.tscn"},
	{"label": "Viajera", "npc_frames": "res://data/npcs/traveler_frames.tres"},
	{"label": "Mercader", "npc": "res://scenes/npcs/merchant.tscn"},
	{"label": "Murciélago", "data": "res://data/enemies/murcielago.tres"},
	{"label": "Sombra errante", "data": "res://data/enemies/sombra_errante.tres"},
	{"label": "Bestia de la niebla", "data": "res://data/enemies/bestia_de_la_niebla.tres"},
	{"label": "Guardián del bosque", "data": "res://data/enemies/forest_guardian.tres"},
	{"label": "Guardián antiguo", "data": "res://data/enemies/ancient_guardian.tres"},
	{"label": "Serpiente", "frames": "res://data/enemies/serpiente_frames.tres"},
	{"label": "Guardián de la isla", "frames": "res://data/enemies/guardian_de_la_isla_frames.tres"},
]

## The sprite of each entry, in the order of ENTRIES.
var sprites: Array[AnimatedSprite2D] = []
var selected := 0
## Index into the selected character's animation list.
var animation_index := 0

var _labels: Array[Label] = []

@onready var _camera: Camera2D = $Camera
@onready var _info: Label = $Hud/Info


func _ready() -> void:
	for i in ENTRIES.size():
		_add_character(i)
	select(0)
	_camera.position.x = 0.0


func _process(delta: float) -> void:
	_camera.position.x = lerpf(_camera.position.x, selected * SPACING, minf(1.0, delta * 8.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		select(selected - 1)
	elif event.is_action_pressed("move_right"):
		select(selected + 1)
	elif event.is_action_pressed("move_up"):
		step_animation(-1)
	elif event.is_action_pressed("move_down"):
		step_animation(1)
	elif event.is_action_pressed("interact"):
		_play_current()


## Picks a character (clamped to the row); everyone goes back to idle.
func select(index: int) -> void:
	selected = clampi(index, 0, sprites.size() - 1)
	animation_index = 0
	for i in sprites.size():
		_labels[i].modulate = SELECTED if i == selected else UNSELECTED
		sprites[i].play(&"idle")
	_refresh_info()


func step_animation(direction: int) -> void:
	animation_index = posmod(animation_index + direction, animation_names(sprites[selected]).size())
	_play_current()


func current_animation() -> StringName:
	return animation_names(sprites[selected])[animation_index]


## The animations of a sprite, the usual ones first.
func animation_names(sprite: AnimatedSprite2D) -> Array[StringName]:
	var names: Array[StringName] = []
	for anim in ANIMATION_ORDER:
		if sprite.sprite_frames.has_animation(anim):
			names.append(anim)
	var others: Array[StringName] = []
	for anim in sprite.sprite_frames.get_animation_names():
		if not names.has(anim):
			others.append(anim)
	others.sort()
	return names + others


func _play_current() -> void:
	sprites[selected].play(current_animation())
	_refresh_info()


func _refresh_info() -> void:
	var sprite := sprites[selected]
	var anim := current_animation()
	_info.text = "%s  |  %s (%d/%d): %d cuadros, %.0f fps  |  escala %.2f\n← → personaje   ↑ ↓ animación   E repetir" % [
			ENTRIES[selected].label, anim, animation_index + 1, animation_names(sprite).size(),
			sprite.sprite_frames.get_frame_count(anim), sprite.sprite_frames.get_animation_speed(anim), sprite.scale.x]


func _add_character(index: int) -> void:
	var entry: Dictionary = ENTRIES[index]
	var slot := Node2D.new()
	slot.name = "Slot%d" % index
	slot.position = Vector2(index * SPACING, 0.0)
	add_child(slot)
	var sprite := _build(entry, slot)
	sprites.append(sprite)
	# One-shot animations stop on their last cell: show them again after a short pause.
	sprite.animation_finished.connect(func() -> void:
		var finished := sprite.animation
		await get_tree().create_timer(REPLAY_DELAY).timeout
		if sprite.animation == finished and not sprite.is_playing():
			sprite.play(finished))

	var label := Label.new()
	label.text = entry.label
	label.position = Vector2(index * SPACING - SPACING / 2.0, 14.0)
	label.size = Vector2(SPACING, 12.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 6)
	add_child(label)
	_labels.append(label)


## Adds the character to `slot` exactly as the game shows it and returns its AnimatedSprite2D.
func _build(entry: Dictionary, slot: Node2D) -> AnimatedSprite2D:
	if entry.has("npc") or entry.has("npc_frames"):
		var npc: Node2D
		if entry.has("npc"):
			npc = (load(entry.npc) as PackedScene).instantiate()
		else:
			npc = (load("res://scenes/npcs/npc.tscn") as PackedScene).instantiate()
			npc.set("sprite_frames", load(entry.npc_frames))
		slot.add_child(npc)
		# The gallery labels everyone itself (a plain NPC would show another speaker's name).
		npc.get_node("Name").visible = false
		return npc.get_node("Sprite")
	var sprite := AnimatedSprite2D.new()
	if entry.has("data"):
		var data: Resource = load(entry.data)
		sprite.sprite_frames = data.get("sprite_frames")
		sprite.scale = Vector2.ONE * float(data.get("sprite_scale"))
		sprite.position = data.get("sprite_offset")
	elif entry.has("scene"):
		_copy_node_properties(load(entry.scene), entry.node, sprite)
	else:
		sprite.sprite_frames = load(entry.frames)
	slot.add_child(sprite)
	return sprite


## Reads a node's saved properties from a scene file without instancing it (the player scene would
## run its own logic and camera).
func _copy_node_properties(scene: PackedScene, node_name: String, target: AnimatedSprite2D) -> void:
	var state := scene.get_state()
	for i in state.get_node_count():
		if state.get_node_name(i) != node_name:
			continue
		for p in state.get_node_property_count(i):
			var property := state.get_node_property_name(i, p)
			if property in [&"sprite_frames", &"scale", &"position"]:
				target.set(property, state.get_node_property_value(i, p))
