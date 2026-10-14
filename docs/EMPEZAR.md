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
5. Pulsa **F5**. Verás un mapa generado: Nico (cuadro amarillo) empieza en la sala verde (inicio) y los soldados rojos están repartidos por las salas. Con `R` se genera otro mapa. La sala morada es la del jefe (arriba).

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
| Plantilla de enemigo | `scenes/enemies/grunt.tscn`, `data/enemies/grunt.tres` | Ejemplo a copiar |
| HUD | `scenes/ui/hud.tscn` | Corazones de vida |
| El director (IA capa 2) | `scripts/ai/director*.gd`, `data/ai/director_rules.tres` | Lee el perfil y adapta enemigos y salas del siguiente mapa. Reglas editables en el `.tres`. El HUD muestra la frase de la isla y la pantalla de muerte lista lo que cambiará |
| Perfil del jugador (IA capa 1) | `scripts/ai/`, `data/ai/profile_config.tres` | Aprende si juegas agresivo o sigiloso y lo guarda entre partidas. El director leerá `PlayerProfile.live_scores()` |
| Habilidades | `scripts/skills/`, `data/skills/` | Raíces, Corriente y Sombra. Teclas `1 2 3`; se desbloquean con `player.skills.unlock(...)` |
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

### Para que el director controle tus enemigos
- El **nombre del archivo de la escena** es el id del enemigo (`bestia_de_la_niebla.tscn` → `bestia_de_la_niebla`). El director usa ese id en `enemy_weights` para decidir cuáles aparecen más.
- Hereda de `enemy.tscn` y **no sobrescribas** los multiplicadores `health_multiplier`, `speed_multiplier`, `damage_multiplier`, `vision_multiplier` y `patrol_multiplier`: el director los fija antes de colocar al enemigo. Si tu enemigo tiene movimiento propio, escálalo con `_speed_scale()`.
- Para que un enemigo **vea más lejos o menos**, usa `can_see()` (ya aplica `vision_multiplier` y la visibilidad del jugador, que baja con Sombra). No hagas detecciones propias.
- Añade el enemigo al `enemy_pool` del escenario (`data/scenarios/*.tres`) y, si quieres que la IA lo favorezca para un estilo, a `enemy_weights` en `data/ai/director_rules.tres`.

## 6. Qué puede empezar ya la persona B
Las tareas de B cuyas dependencias están listas:
1. **Tarea 4: los 6 enemigos.** La base ya existe. Empezar por **Bestia de la niebla** (embiste) y **Murciélago** (picado rápido), que son los más simples. Se entregan en tandas de 2 o 3.
2. **Tarea 13: menús, pausa, guardado y créditos.** Depende solo del combate, que ya está.
3. **Tarea 14: sonido y música.** Elegir packs gratuitos y registrarlos en `CREDITS.md`.
4. **Tarea 12 (parte del sistema de diálogo).** La caja de texto se puede hacer ya, leyendo de `data/dialogues/`.
5. Las tareas **8 (perfil del jugador)** y **9 (la isla reacciona)** ya están hechas: no las rehagas. Si quieres cambiar cómo reacciona la isla, edita `data/ai/director_rules.tres` (o `tools/make_director_data.gd` y regenera).

Mientras tanto la persona A avanza con las tareas 5 (habilidades) y 6 (generador de mapas).

## 7. Arte (Pixelorama)
- Personajes en **32x32**, una paleta única de 16 a 24 colores, tilesets de **16x16**.
- Guarda el archivo fuente (`.pxo`) junto al PNG exportado en `assets/sprites/<nombre>/`.
- Animaciones mínimas: quieto, caminar, ataque, daño, muerte.
- Primero se prueba el flujo completo con un sprite de prueba (último punto pendiente de la tarea 1): dibujar → exportar PNG → importar en Godot → animar con `AnimatedSprite2D`.
- Los diseños de `docs/referencias/` son una guía, no sprites finales.

## 8. Mensaje para pegarle a tu Claude Code
> Lee `CLAUDE.md`, `docs/JUEGO.md`, `docs/TAREAS.md` y `docs/EMPEZAR.md` de este repositorio. Soy la persona B. Empieza por la tarea 4 (enemigos): primero la Bestia de la niebla y el Murciélago, usando la base de `scripts/enemies/enemy.gd`. Sigue las reglas de `CLAUDE.md`: una tarea a la vez, commits convencionales en inglés sin atribución de IA, pruebas antes de cada push y `git pull --rebase`. Si algo es ambiguo o toca el alcance, pregúntame antes de decidir.
