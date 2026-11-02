extends Node2D
## Sandbox to try the temple enemies (island 3) one at a time while their scenario is being built:
## a closed stone floor with Nico and one enemy. N (debug_next_enemy) brings the next one, R
## (debug_regenerate) brings the current one back; if Nico dies the arena starts again.
## Not part of the game: run the scene from the editor (F6).

const ENEMIES := [
	"res://scenes/enemies/centinela_obsidiana.tscn",
	"res://scenes/enemies/carcelero_cadenas.tscn",
	"res://scenes/enemies/acolito_brasero.tscn",
	"res://scenes/enemies/verdugo_piedra.tscn",
	"res://scenes/enemies/duelista_maldito.tscn",
	"res://scenes/enemies/salamandra_cristal.tscn",
	"res://scenes/enemies/gusano_puentes.tscn",
	"res://scenes/enemies/caracol_escoria.tscn",
	"res://scenes/enemies/carnero_basalto.tscn",
	"res://scenes/enemies/manta_hollin.tscn",
	"res://scenes/enemies/eco_espejo.tscn",
	"res://scenes/enemies/monje_sin_rostro.tscn",
	"res://scenes/enemies/mascara_parasita.tscn",
	"res://scenes/enemies/oraculo_ceniza.tscn",
	"res://scenes/enemies/custodio_sello.tscn",
	"res://scenes/enemies/ojo_sol.tscn",
	"res://scenes/enemies/campanero_bronce.tscn",
	"res://scenes/enemies/rueda_devoradora.tscn",
	"res://scenes/enemies/arana_talladora.tscn",
	"res://scenes/enemies/forjador_condenado.tscn",
	"res://scenes/enemies/baldosa_hambrienta.tscn",
	"res://scenes/enemies/manos_abismo.tscn",
	"res://scenes/enemies/vasija_poseida.tscn",
	"res://scenes/enemies/relojero_trampas.tscn",
	"res://scenes/enemies/nucleo_cria.tscn",
]
## Enemies that work on other enemies (the mask rides one, the seal guardian shields them) come with
## company: these scenes stand at both sides of them.
const COMPANIONS := {
	"res://scenes/enemies/mascara_parasita.tscn": ["res://scenes/enemies/esqueleto.tscn", "res://scenes/enemies/slime.tscn"],
	"res://scenes/enemies/custodio_sello.tscn": ["res://scenes/enemies/esqueleto.tscn", "res://scenes/enemies/slime.tscn"],
}
const COMPANION_SPREAD := 80.0
const SIZE := Vector2(560, 352)
const WALL := 16.0
const FLOOR_COLOR := Color(0.2, 0.17, 0.16)
const WALL_COLOR := Color(0.1, 0.08, 0.08)
const ENEMY_SPOT := Vector2(0.5, 0.3)
const PLAYER_SPOT := Vector2(0.5, 0.8)
## Seconds after Nico dies before the arena starts again.
const RESTART_DELAY := 1.5

## Index in ENEMIES of the enemy being tried (kept when the arena restarts).
static var current := 0

var _enemy: Node2D
var _companions: Array[Node2D] = []
var _player: Node2D

@onready var _name_label: Label = $Info/Name


func _ready() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.size = SIZE
	floor_rect.z_index = RoomTheme.FLOOR_Z
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)
	var walls: Array[Rect2] = [
		Rect2(-WALL, -WALL, SIZE.x + WALL * 2.0, WALL), Rect2(-WALL, SIZE.y, SIZE.x + WALL * 2.0, WALL),
		Rect2(-WALL, 0, WALL, SIZE.y), Rect2(SIZE.x, 0, WALL, SIZE.y)]
	WallBuilder.add_walls(self, walls, WALL_COLOR)
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = SIZE * PLAYER_SPOT
	add_child(_player)
	_player.set_camera_limits(Rect2(-WALL, -WALL, SIZE.x + WALL * 2.0, SIZE.y + WALL * 2.0))
	add_child(GameFeel.new())
	Events.player_died.connect(func() -> void:
		get_tree().create_timer(RESTART_DELAY).timeout.connect(get_tree().reload_current_scene))
	_spawn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_next_enemy"):
		current = (current + 1) % ENEMIES.size()
		_spawn()
	elif event.is_action_pressed("debug_regenerate"):
		_spawn()


func _spawn() -> void:
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.queue_free()
	for companion in _companions:
		if is_instance_valid(companion):
			companion.queue_free()
	_companions.clear()
	for hazard in get_tree().get_nodes_in_group(&"ground_hazards"):
		hazard.queue_free()
	var path: String = ENEMIES[current]
	if not ResourceLoader.exists(path):
		_name_label.text = "%d/%d  (falta %s)" % [current + 1, ENEMIES.size(), path.get_file()]
		return
	_enemy = load(path).instantiate()
	_enemy.position = SIZE * ENEMY_SPOT
	# The arena is its room: it patrols, hunts and runs its edges inside it, like in a real room.
	_enemy.home_area = Rect2(Vector2.ZERO, SIZE)
	add_child(_enemy)
	var side := -1.0
	for companion_path: String in COMPANIONS.get(path, []):
		var companion: Node2D = load(companion_path).instantiate()
		companion.position = _enemy.position + Vector2(COMPANION_SPREAD * side, 0)
		companion.home_area = _enemy.home_area
		add_child(companion)
		_companions.append(companion)
		side = -side
	_name_label.text = "%d/%d  %s   ·   N: siguiente   R: otra vez" % [
			current + 1, ENEMIES.size(), _enemy.data.display_name]
