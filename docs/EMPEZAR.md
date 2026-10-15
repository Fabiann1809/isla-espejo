# Guía de arranque (para quien se une al proyecto)

Lee esto primero. En 15 minutos deberías tener el juego abierto y saber por dónde empezar.

## 1. Preparar el equipo
1. Instala **Git** y **Godot 4.7.2** (versión estándar, no .NET): https://godotengine.org/download
2. Clona el repo:
   ```
   git clone https://github.com/Fabiann1809/isla-espejo.git
   cd isla-espejo
   ```
3. Configura tu identidad (cada persona firma con su nombre):
   ```
   git config user.name "Tu nombre"
   git config user.email "tu-correo@ejemplo.com"
   ```
4. Abre Godot → **Importar** → selecciona `project.godot` → **Importar y editar**.
5. Pulsa **F5**. Verás el Bosque de la Aurora generado (pasto, pinos, estanques, caminos de tierra): Nico (cuadro amarillo) empieza en la sala verde (inicio) y los soldados rojos están repartidos por las salas. Con `R` se genera otro mapa. La sala morada es la del jefe (arriba).

Controles: `WASD` mover · `Espacio` esquivar · `J` atacar · `R` mapa nuevo. `1 2 3` habilidades (en el nivel de prueba ya vienen desbloqueadas). `E` interactuar aún no hace nada.

## 2. Leer, en este orden
1. `docs/JUEGO.md`: qué es el juego, alcance y personajes. **Lo que no está ahí no se construye sin preguntar.**
2. `docs/TAREAS.md`: lista de tareas. Cada una tiene responsable (A o B).
3. `CLAUDE.md`: reglas de trabajo. Tu Claude Code las lee solo, pero léelas tú también.

## 3. Flujo de trabajo
- Se trabaja directo en `main`, sin pull requests.
- Antes de cada push: `git pull --rebase`, ejecutar el juego, y pasar las pruebas con un solo comando:
  ```
  ./tools/run_tests.sh                    # todas
  ./tools/run_tests.sh test_skills        # solo una
  ```
  En Windows se usa Git Bash y se indica dónde está Godot (la versión `_console.exe`):
  ```
  export GODOT="C:/ruta/a/Godot_v4.7.2-stable_win64_console.exe"
  ```
  El script falla si una prueba termina con error, se cuelga o imprime un `SCRIPT ERROR` (GDScript sigue ejecutando tras un error, así que el código de salida solo no basta). GitHub lo repite en cada push (pestaña Actions); si sale en rojo, se arregla antes de seguir.
- Un commit por tarea, en inglés y con formato `tipo(ámbito): resumen`, por ejemplo `feat(enemies): add fog beast`. Sin atribución de IA.
- Marca la tarea como `[x]` en `docs/TAREAS.md` en el mismo commit.
- **No pisarse:** antes de editar una escena `.tscn`, avisa si la otra persona la está tocando. Los archivos compartidos (`project.godot`, `data/`, `scripts/core/events.gd`) se cambian en commits pequeños y avisando.
- No se crean etiquetas `v*` sin acordarlo: publican una Release pública.

## 4. Qué hay hecho (no lo rehagas)
| Pieza | Dónde | Para qué |
|---|---|---|
| Nico | `scenes/player/`, `scripts/player/player.gd` | Movimiento, esquiva con invulnerabilidad, ataque, vida, muerte |
| Vida / daño | `scripts/components/` | `HealthComponent`, `Hitbox`, `Hurtbox`: **toda la lógica de daño pasa por aquí** |
| Bus de eventos | `scripts/core/events.gd` (autoload `Events`) | Aquí se publica lo que pasa; la IA y el HUD lo escuchan |
| Enemigo base | `scripts/enemies/enemy.gd`, `enemy_data.gd`, `scenes/enemies/enemy.tscn` | Estados, detección, persecución, ataque con aviso |
| Menús, pausa, guardado y opciones | `scenes/ui/main_menu.tscn`, `pause_menu.tscn`, autoloads `SaveGame` y `Settings`, textos en `data/ui/texts.json` | Hechos (tarea 13). Textos de menús: se editan en el JSON |
| Plantilla de enemigo | `scenes/enemies/grunt.tscn`, `data/enemies/grunt.tres` | Ejemplo a copiar |
| Enemigo con arte animado | `scenes/enemies/sombra_errante.tscn`, `data/enemies/sombra_errante*.tres`, `tools/make_sombra_errante.gd` | Ejemplo de sprites: la hoja PNG (celdas 48x48, una fila por animación idle/walk/run/attack/hurt/death, mirando a la derecha) se vuelve `SpriteFrames` y se asigna en `EnemyData.sprite_frames`; `enemy.gd` anima solo según el estado |
| HUD | `scenes/ui/hud.tscn` | Corazones de vida |
| El director (IA capa 2) | `scripts/ai/director*.gd`, `data/ai/director_rules.tres` | Lee el perfil y adapta enemigos y salas del siguiente mapa. Reglas editables en el `.tres`. El HUD muestra la frase de la isla y la pantalla de muerte lista lo que cambiará |
| Perfil del jugador (IA capa 1) | `scripts/ai/`, `data/ai/profile_config.tres` | Aprende si juegas agresivo o sigiloso y lo guarda entre partidas. El director leerá `PlayerProfile.live_scores()` |
| Habilidades | `scripts/skills/`, `data/skills/` | Raíces, Corriente y Sombra. Teclas `1 2 3`; se desbloquean con `player.skills.unlock(...)` |
| Jefe y recompensas | `scripts/enemies/boss.gd`, `boss_data.gd`, `scripts/world/fragment_pickup.gd`, `exit_portal.gd` | El Guardián del bosque (dos ataques con aviso, segunda fase). Al vencerlo suelta el fragmento, que enseña la habilidad y abre la salida |
| Interacción y diálogos | `scripts/world/interactable.gd`, `npc.gd`, `chest.gd`, `scripts/core/dialogue.gd`, `game_state.gd`, `data/dialogues/` | `E` interactúa con cofres y NPC. Los diálogos son archivos JSON (formato abajo). El progreso de la historia vive en `GameState` |
| Escenario 1: Bosque de la Aurora | `data/scenarios/forest.tres`, `scenes/levels/forest_level.tscn`, `scenes/levels/rooms/forest/` | Es la escena que abre F5. 10 salas con tileset de Kenney (CC0). Se editan con `python tools/make_forest_rooms.py` |
| Generador de mapas | `scripts/world/map_generator.gd`, `level.gd`, `room.gd` | Mapas distintos en cada partida con salas hechas a mano (ver `CLAUDE.md`) |
| Nivel de prueba | `scenes/levels/test_level.tscn` | Genera un mapa; `R` crea otro. Es la escena que abre F5 |
| Sala de pruebas | `scenes/levels/test_room.tscn` | Banco de pruebas del combate (lo usan los tests) |

Capas de colisión: 1 mundo · 2 jugador · 3 enemigo · 4 ataque del jugador · 5 ataque enemigo.

## 5. Cómo crear un enemigo nuevo (tarea 4)
1. Copia `data/enemies/grunt.tres` a `data/enemies/<nombre>.tres` y cambia los valores (vida, velocidades, rangos, ataque, color provisional).
2. Crea `scenes/enemies/<nombre>.tscn` heredando de `enemy.tscn` (como `grunt.tscn`) y asigna tu `.tres` en `data`.
3. Si su comportamiento es distinto, crea un script que extienda `Enemy` y sobrescribe solo `_process_chase`, `_start_attack`, `_process_attack`… Nunca copies `enemy.gd`.
4. Añade una comprobación en `tests/test_enemy.gd` (o un test nuevo `tests/test_<nombre>.gd`).
5. Pruébalo en la sala de pruebas (puedes instanciarlo ahí temporalmente, sin subir ese cambio).

### Cómo escribir el diálogo de un NPC (Viajera, Mercader...)
1. Crea `data/dialogues/<id>.json` (copia `elder.json`). Cada NPC necesita **tres estados**: `first` (primer encuentro), `again` (ya lo conoces) y `final` (después de vencer al jefe de su capítulo).
2. Las líneas son texto, o `{"speaker": "Nico", "text": "..."}` si habla otra persona.
3. `rules` decide qué estado suena: la primera regla cuyas banderas (`requires`) están todas puestas. La **última regla debe ser un valor por defecto sin `requires`**.
4. `on_finish` pone banderas al terminar un estado (por ejemplo `first` marca `met_elder`, y así la próxima vez sale `again`).
5. Crea la escena del NPC heredando de `scenes/npcs/npc.tscn` (como `elder.tscn`), con su `dialogue_id`, y asígnala a `npc_scene` del escenario (`data/scenarios/*.tres`).
6. Las banderas de jefes derrotados se llaman `<escenario>_boss_defeated` (por ejemplo `forest_boss_defeated`); la prueba `tests/test_dialogues.gd` valida el formato de todos los archivos.

### Cómo construir los escenarios 2 y 3 (siguiendo el bosque)
Todo el escenario 1 es el molde. Para las Ruinas de la Montaña y el Templo del Eclipse:
1. **Arte:** elige/descarga un pack (CC0), cópialo a `assets/tilesets/<pack>/` **con su `License.txt`** y añádelo a `CREDITS.md`. Rotula la hoja con `tools/atlas_preview.gd` (necesita ventana) y añade los tiles nombrados a `scripts/world/tile_art.gd` (o crea un catálogo propio). Genera el `TileSet` y el tema copiando `tools/make_forest_tileset.gd`.
2. **Salas:** copia `tools/make_forest_rooms.py` (10 salas: inicio, jefe, 5 de combate con etiquetas `standard`/`ambush`/`watch`, evento, recompensa y especial). El script valida que ningún objeto bloquee las puertas. Comprueba con `./tools/run_tests.sh test_room_designs`.
3. **Datos:** copia `tools/make_forest_data.gd` → `data/scenarios/<id>.tres` y `data/rooms/*.tres`. Pon el tema, el `enemy_pool` (los enemigos del escenario), `npc_scene`, `chest_scenes`, `boss_scene`, `exit_scene`, `chapter_title` y `completion_text`.
4. **Jefe:** crea un `BossData` (copia `tools/make_forest_boss.gd`), una escena que herede de `enemy.tscn` con el script `boss.gd` (copia `forest_guardian.tscn`) y un fragmento (`fragment_green.tscn` con otro `fragment_id`/`skill_id`/color). La bandera de derrota es `<escenario>_boss_defeated`, y el portal (`exit_portal.tscn`) necesita esa bandera en `required_flag`. Si quieres otros patrones de ataque, extiende `Boss` y sobrescribe `_start_attack`, `_process_attack` y `_strike`.
5. **Cadena de capítulos:** en el `.tres` del escenario anterior pon `next_scenario` apuntando al nuevo. Al cruzar el portal el nivel pasa al siguiente.
6. **Diálogo:** el NPC del capítulo (`data/dialogues/<id>.json`, ver arriba).
7. **Habilidad:** crea el `SkillData` del jefe (`tools/make_skill_data.gd`) si aún no existe (Corriente y Sombra ya existen) y ponlo en `skill_id` del fragmento.
8. **Escena jugable:** copia `scenes/levels/forest_level.tscn` cambiando el `scenario`. Añade pruebas copiando `tests/test_forest.gd` y `tests/test_boss.gd`.

### Para que el director controle tus enemigos
- El **nombre del archivo de la escena** es el id del enemigo (`bestia_de_la_niebla.tscn` → `bestia_de_la_niebla`). El director usa ese id en `enemy_weights` para decidir cuáles aparecen más.
- Hereda de `enemy.tscn` y **no sobrescribas** los multiplicadores `health_multiplier`, `speed_multiplier`, `damage_multiplier`, `vision_multiplier` y `patrol_multiplier`: el director los fija antes de colocar al enemigo. Si tu enemigo tiene movimiento propio, escálalo con `_speed_scale()`.
- Para que un enemigo **vea más lejos o menos**, usa `can_see()` (ya aplica `vision_multiplier` y la visibilidad del jugador, que baja con Sombra). No hagas detecciones propias.
- Añade el enemigo al `enemy_pool` del escenario (`data/scenarios/*.tres`) y, si quieres que la IA lo favorezca para un estilo, a `enemy_weights` en `data/ai/director_rules.tres`.

## 6. Reparto actual: qué hace cada persona
**Ya está hecho (no lo rehagas):** Nico, combate, menús, pausa y guardado, vida y daño, habilidades (Raíces, Corriente, Sombra), generador de mapas, **la IA completa** (perfil del jugador y director), sistema de diálogo, interacción (cofres, NPC), jefe base, **y el escenario 1 jugable de principio a fin** (Bosque de la Aurora). Detalle en la tabla de la sección 4 y en `docs/TAREAS.md` (sección "Estado actual").

### Persona B, por dónde empezar
1. **Tarea 4: los 6 enemigos.** Empezar por **Bestia de la niebla** (embiste) y **Murciélago** (picado rápido), que son los más simples; entregar en tandas de 2 o 3. Sigue las convenciones de abajo ("Para que el director controle tus enemigos") y copia `scenes/enemies/grunt.tscn` + `data/enemies/grunt.tres`. Cuando existan los del bosque (Bestia de la niebla y Sombra errante), cámbialos en el `enemy_pool` de `data/scenarios/forest.tres` (hoy usa el soldado de plantilla). Añade una prueba por enemigo (copia `tests/test_enemy.gd`).
2. **Tarea 12: los textos.** El sistema de diálogo ya existe; falta escribir `data/dialogues/viajera.json` y `mercader.json` (copia `elder.json`; mira el formato arriba) y los textos de la historia (prólogo, final).
3. **Tarea 13: ya está hecha** (menú principal, pausa, guardado, opciones y créditos; ver la tabla de la sección 4). Si quieres mejorar algo de los menús, los textos están en `data/ui/texts.json` y el aspecto en `scripts/ui/ui_kit.gd`.
4. **Tarea 14: sonido y música.** Elegir packs gratuitos y registrarlos en `CREDITS.md` (con su licencia).

### Persona A, lo que sigue
Escenarios 2 y 3 (tareas 10 y 11): tilesets, salas y jefes, siguiendo la guía de arriba. Eso toca `scripts/world/`, `data/scenarios/` y `data/rooms/`.

### Para no pisarse
- **B** trabaja en `scripts/enemies/`, `scenes/enemies/`, `data/enemies/`, `data/dialogues/`, `scripts/ui/` (menús) y `assets/audio/`.
- **A** trabaja en `scripts/world/`, `scenes/levels/`, `data/scenarios/`, `data/rooms/`, `data/themes/` y `assets/tilesets/`.
- Si necesitas tocar algo del otro (por ejemplo, el `enemy_pool` de un escenario), hazlo en un commit pequeño y avisa.
- Los archivos compartidos (`project.godot`, `scripts/core/events.gd`, `data/ai/`) se cambian con commits pequeños y se avisa antes.

## 7. Arte (Pixelorama)
- Personajes en **32x32**, una paleta única de 16 a 24 colores, tilesets de **16x16**.
- Guarda el archivo fuente (`.pxo`) junto al PNG exportado en `assets/sprites/<nombre>/`.
- Animaciones mínimas: quieto, caminar, ataque, daño, muerte.
- Primero se prueba el flujo completo con un sprite de prueba (último punto pendiente de la tarea 1): dibujar → exportar PNG → importar en Godot → animar con `AnimatedSprite2D`.
- Los diseños de `docs/referencias/` son una guía, no sprites finales.

## 8. Mensaje para pegarle a tu Claude Code
> Lee `CLAUDE.md`, `docs/JUEGO.md`, `docs/TAREAS.md` y `docs/EMPEZAR.md` de este repositorio. Soy la persona B. Empieza por la tarea 4 (enemigos): primero la Bestia de la niebla y el Murciélago, heredando de `scenes/enemies/enemy.tscn` (mira `grunt.tscn` y las convenciones de `docs/EMPEZAR.md`, sección 5), con una prueba por enemigo. Sigue las reglas de `CLAUDE.md`: una tarea a la vez, commits convencionales en inglés sin atribución de IA, `./tools/run_tests.sh` antes de cada push (en Windows con `GODOT` apuntando a la versión `_console.exe`) y `git pull --rebase`. Tu zona de trabajo está en la sección 6 de `docs/EMPEZAR.md`; no modifiques `scripts/world/` sin avisarme. Si algo es ambiguo o toca el alcance, pregúntame antes de decidir.
