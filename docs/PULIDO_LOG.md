# Registro de pulido del Nivel 1 (Bosque de la Aurora)

Rama `auto/pulido-nivel1-noche`. Trabajo autónomo del 25-10-2026 (hora de Bogotá).

## Resumen

(se completa al cierre)

## Punto de partida

- **13:17**: la rama `auto/pulido-nivel1-noche` no existía. Se creó desde `feature/nico-arte-nuevo`, la rama activa en ese momento, que va 36 commits por delante de `main` y tenía el árbol limpio. Es la opción más conservadora: no se toca `main` ni se pierde trabajo. **Decisión tuya:** confirmar que esa es la base correcta.
- Godot: `Godot_v4.7.2-stable_mono_win64_console.exe` (en Descargas).
- Pruebas base (`tools/run_tests.sh`): **24 de 24 suites en verde** (5 min 41 s).
- Nota: `CLAUDE.md` del proyecto prohíbe añadir líneas `Co-Authored-By` y cualquier atribución a IA, así que los commits no las llevan.

## Tareas

### 1a. Enemigos que desaparecen en pasillos y en la sala de recompensa — 13:20–13:40
- **Reproducción** (`tests/test_draw_order.gd`, nuevo): emula el orden de dibujo 2D de Godot (z, luego orden por Y, luego orden del árbol) y pasea un enemigo de la primera sala, uno de la última y a Nico por encima de cada prop y de cada celda de pasillo en 5 mapas. **Antes: 5043 de 26760 posiciones con el actor tapado.**
- **Causa real:** la hipótesis del pasillo era solo en parte cierta. Los suelos y pasillos ya estaban en `z_index = -1`. Lo que tapaba a los enemigos eran los **props de las salas construidas después**: cada enemigo es hijo de su sala, y los props (estanque, puente, parche de tierra, árboles, arbustos) estaban en z 0. Un enemigo que entraba en una sala posterior quedaba debajo. La sala de recompensa tiene un parche de tierra de 4x4 justo en el centro, por eso ahí se notaba tanto.
- **Corrección:** los props planos (estanque, tablones, tierra, matas) se dibujan con el suelo (`z_index = -1`). `Level`, `Map`, cada `Room` y `Corridors` tienen `y_sort_enabled`, así que actores y props verticales de todas las salas se ordenan juntos por Y. El origen de cada prop vertical se baja a la base de su huella (`SORT_ABOVE_BOTTOM = 4`) sin mover su dibujo ni su colisión: quien camina delante de un árbol se ve delante, y quien pasa detrás, detrás.
- **Después: 0 de 26760.** Suite completa en verde (25 suites).
- Archivos: `scripts/world/room_prop.gd`, `room.gd`, `level.gd`, `tests/test_draw_order.gd`.
- **Sin verificar en pantalla:** que el orden por Y se vea bien al rodear árboles altos, y que los círculos de aviso del jefe, ahora ordenados por Y, no tapen a Nico de forma rara. Los tests del jefe pasan.

### 1b. Enemigos repetidos en una sala — 13:40–13:48
- **Medición** (3000 salas de 2 a 6 enemigos, un solo generador): con el sorteo antiguo, con reemplazo, **1763 salas (59 %)** tenían más de un tipo de enemigo que su parte justa, y **112 salas de 3 o más eran de un solo tipo**. Con los pesos 3:1:1 del director: 1320 y 297.
- **Corrección:** `Room.pick_enemies()` usa muestreo sistemático. Cada tipo recibe su parte de los huecos según su peso, redondeada al azar hacia arriba o hacia abajo, de modo que su número esperado es exactamente esa parte. Luego se baraja el orden. No cambian los pesos ni el director.
- **Después:** 0 salas por encima de su parte y 0 salas de un solo tipo. Las proporciones globales se mantienen (error máximo 0,001 con pesos iguales y 0,004 con 3:1:1).
- Archivos: `scripts/world/room.gd`, `tests/test_enemy_mix.gd`.
- Nota: el mismo enemigo puede seguir repitiéndose en una sala cuando su parte lo pide (por ejemplo, 2 de 5 con 3 tipos). Eso es lo esperado.

### 1c. Enemigos sin sprite (cuadro rojo)
- Los tres enemigos del pool del bosque (`sombra_errante`, `murcielago`, `bestia_de_la_niebla`) tienen `sprite_frames`. **Ninguno se ve como cuadro rojo.** Solo `grunt` (soldado de plantilla) no tiene arte, y solo está en `data/scenarios/test.tres`, el escenario de pruebas. Lo vigila un check nuevo en `tests/test_enemy_mix.gd`.
- **Si algún día entra `grunt` u otro enemigo sin arte al bosque:** asignarle un `SpriteFrames` en su `EnemyData`, o sacarlo del `enemy_pool` de `forest.tres`. No hace falta arte nuevo para el bosque actual.

### 1d. Suavidad del movimiento — 13:50–13:55
- Ya estaba hecho: `snap_2d_transforms_to_pixel` e interpolación física activos, `Placement.reset()` tras cada teletransporte o cambio de mapa (cubierto por `test_interpolation`), y Nico a 120 px/s (2 px por tick) con dash a 300 px/s (5 px por tick).
- **Faltaba:** la cámara seguía a Nico en el proceso de *idle*. Ahora va en el de física (`process_callback = 0` en `player.tscn`), así que cámara y Nico se interpolan juntos. Hay un check nuevo en `test_interpolation`.
- **No cambié las velocidades de los enemigos** (55, 38, 34, 105, 78, 62 px/s; no son enteros por tick). Cambiarlas altera el balance, y el director las multiplica de todas formas (x1,1), así que nunca quedarían enteras. **Decisión tuya** si quieres redondearlas en `data/enemies/*.tres`. Nico en diagonal tampoco avanza píxeles enteros (1,41 px por tick); es inherente al movimiento en 8 direcciones.
- **Sin verificar en pantalla:** la suavidad real de la cámara con suavizado (`position_smoothing_speed = 10`) en el proceso de física.

### 1e. Otros fallos encontrados — 13:55–14:25
1. **Patrullas atascadas contra paredes y árboles.** El punto de patrulla se elegía en un círculo alrededor del spawn, sin límites. Con el x1,72 del director caía dentro de muros o fuera de la sala, y el enemigo caminaba contra la pared para siempre, porque solo paraba al llegar. Medido con `tools/measure_enemies.gd` (nuevo): **80 patrullas atascadas en 2 mapas → 0.** Corrección: cada enemigo conoce su sala (`home_area`, asignada por `Room`), el punto se limita a la sala con 24 px de margen, y la patrulla se abandona si no avanza en 0,4 s o si tarda el doble de lo esperado. Prueba nueva: `tests/test_enemy_patrol.gd` (2 mapas, patrulla x2: nadie sale de su sala ni se atasca).
2. **Raíces del jefe dentro de los muros o fuera de la arena.** Las erupciones secundarias se dispersan hasta 64 px alrededor de Nico sin límite. Con Nico junto a una pared caían en el muro o en el pasillo: **191 erupciones fuera en 200 ataques desde las esquinas → 0.** Corrección: `Boss._inside_arena()` las mantiene a 24 px del borde de la sala. Check nuevo en `test_boss_roots`.
3. **Avisos del jefe y zonas de habilidades por encima de Nico** (efecto secundario de 1a): con el orden por Y, un círculo se dibujaba sobre Nico si él estaba por encima de su centro. Ahora círculos, ondas y raíces del jefe van a nivel del suelo (`z_index = -1`), siempre debajo de los actores, como antes. Check nuevo en `test_draw_order`.
- Valores nuevos en `scripts/core/tuning.gd` (nuevo), que es el único lugar de constantes del pulido.
- **Sin verificar en pantalla:** que los círculos de aviso se sigan leyendo bien ahora que están debajo del jefe y de los enemigos (antes quedaban por encima de los enemigos de la sala).

**Push de la fase 1:** el `git push` quedó esperando credenciales (no hay sesión de GitHub en esta terminal). Como pediste, seguí en local; la rama queda lista para que hagas `git push -u origin auto/pulido-nivel1-noche`.

### Fase 2. Ambientación — 14:30–15:15
Herramienta nueva para mirar sin jugar: `tools/screenshot_map.gd` (necesita ventana). Guarda el mapa entero y vistas a zoom real (inicio, jefe, pasillo, esquinas, hueco entre salas). Lo usé en cada paso con las semillas 4242 y 31337.

**2a. De dónde venía el negro:**
1. El color de fondo del proyecto (`default_clear_color` casi negro).
2. Los límites de cámara son el rectángulo de **todas** las celdas del mapa, así que se veían las celdas vacías de la cuadrícula y las franjas de 48 px entre salas.
3. Los muros de los pasillos eran pinos con fondo transparente sin pasto debajo: negro a lo largo de los pasillos.
4. Encontrado al mirar las capturas: las piezas redondeadas del camino y los pinos de borde también tienen esquinas transparentes.

**2b. Bosque denso** (`scripts/world/forest_backdrop.gd`, nuevo): capas de tiles debajo de todos los suelos (`z = -2`) que cubren el mapa más 12 tiles de margen, excepto salas y suelos de pasillo. Pasto oscuro de base y árboles, pinos (también altos de 2 tiles), arbustos, rocas y tocones. Densidad 70 % / 50 % / 38 % y brillo en 3 franjas según la distancia al camino (más denso cerca, más oscuro lejos). Semilla = semilla del mapa. Fondo del proyecto: verde muy oscuro `Color(0.05, 0.09, 0.06)`. Cada pasillo tiene su capa de pasto debajo (`CorridorGround`). Tarda unos 150 ms por mapa.

**2c. Variedad de suelo:** manchas irregulares de un segundo pasto (ruido continuo entre salas) con bordes redondeados (nine-slice del pack). Hay 5 grupos pequeños por sala de hongos, piedras, flores o un tocón con hongos, en la capa de decoración, sin colisión. Los caminos de puertas y pasillos ahora tienen bordes suaves (nine-slice de tierra), calculados sobre todo el mapa para que empalmen sala y pasillo.
- **Cambio de datos (decisión tuya):** quité de `data/themes/forest.tres` las variantes de flores `(0,6)`, `(0,9)` y `(0,12)`. Son esquinas de un macizo con una piedra gris y se veían como cuadros. En su lugar hay flores sueltas en grupos.
- No toqué las transiciones de agua: los estanques ya usan su nine-slice.

**2d. Aspecto unificado** (`scripts/effects/ambience.gd`, `actor_shadow.gd`, nuevos):
- `CanvasModulate` muy suave `(0.95, 0.97, 0.95)`.
- Una pasada de pantalla sobre el mundo, no sobre el HUD: −12 % de saturación y viñeta 0,32 desde el 60 % del radio. Lo comprobé forzándola al máximo: el mundo cambia y el HUD no.
- Sombra elíptica bajo Nico, enemigos, jefe y NPC. Se calcula con la fila opaca más baja del primer cuadro de `idle`.
- El orden por Y ya estaba hecho en 1a.
- Todo se apaga en `Tuning` (`WORLD_TINT_ENABLED`, `SCREEN_GRADE_ENABLED`, `SHADOWS_ENABLED`, `BACKDROP_ENABLED`, `SOFT_PATH_EDGES`).

**2e.** Nueva acción `debug_toggle_info` (**F3**, solo depuración; no cambia ningún control del juego). El texto de semilla y director arranca **oculto**.

**2f.** `tests/test_forest_look.gd` (nuevo), con 30 semillas:
- Todo tile dentro de los límites de cámara tiene suelo: **0 de 484 128 sin suelo**. La primera versión encontró 4548 en pasillos por un fallo mío de nombres de capas, ya corregido.
- Los tiles no tienen colisión y la decoración no añade cuerpos.
- La misma semilla da el mismo bosque.
- Hay sombras, y tinte y pasada de pantalla por debajo del HUD.
- F3 alterna el texto de depuración.
- **Sin verificar en pantalla, jugando:** la sensación general con movimiento (viñeta y desaturación en vivo, legibilidad de enemigos oscuros sobre el bosque oscuro cuando se acercan al borde). Las capturas estáticas se ven bien.

### Fase 3. Enemigos que se juntan — 14:45–15:10
**Medición** con `tools/measure_enemies.gd`: 20 mapas. Nico, invulnerable y sin atacar, recorre todas las salas en profundidad (centro → puerta → siguiente sala, pausa de 2 s en cada una). Se mide con enemigos neutros y con la reacción sigilosa del director tal como se observó (visión x1,43, patrulla x1,72). El registro por enemigo se activa con `Tuning.ENEMY_DEBUG_LOG`. Es el peor caso: como Nico no mata a nadie, los perseguidores se acumulan.

| 20 mapas | Antes, neutro | Antes, sigilo x1,43/x1,72 | Después, neutro | Después, sigilo |
|---|---|---|---|---|
| Perseguidores a la vez (máx.) | 17 | 27 | **4** | **4** |
| Media del máximo por mapa | 12,9 | 20,8 | 4,0 | 4,0 |
| Tiempo con 4 o más persiguiendo | 86,5 % | 91,8 % | 8,0 % | 18,6 % |
| Enemigos que salen de su sala | 430/560 (77 %) | 541/560 (97 %) | 22/560 (4 %)* | 18/560 (3 %)* |
| Grupo más grande junto a Nico (64 px) | 16 | 24 | 4 | 4 |
| Murciélagos persiguiendo juntos | 11 | 13 | 3 | 3 |
| Patrullas atascadas | 0 (ya corregido en 1e) | 0 | 0 | 0 |

\* Solo pisan la puerta o el arranque del pasillo, dentro del margen permitido de 40 px.

**Hipótesis confirmada en parte:** el director amplía visión y patrulla, y eso empeora (97 % frente a 77 %). Pero la causa de fondo estaba en el enemigo base: perseguía sin límite de sala (solo dejaba de hacerlo a `lose_range`, 220–240 px) y no había tope de perseguidores. Las patrullas también salían de la sala (corregido en 1e).

**Soluciones aplicadas** (en `scripts/enemies/enemy.gd`, valores en `Tuning`):
1. **Territorio:** un enemigo solo empieza a cazar si Nico está en su sala o a menos de 40 px de su borde (`TERRITORY_MARGIN`), y si Nico sale vuelve caminando a su punto de spawn. Si Nico le pega desde fuera, reacciona igual, pero vuelve en cuanto Nico se aleja.
2. **Tope de cazadores:** como máximo 4 a la vez (`MAX_HUNTERS`) y 3 del mismo tipo (`MAX_HUNTERS_OF_A_KIND`, un grupo de murciélagos). Los demás siguen patrullando hasta que se libera un sitio. Un golpe siempre hace reaccionar al enemigo golpeado.
3. **Distancia entre spawns:** ya se cumplía (mínimo real 60 px). La vigila una prueba (`MIN_SPAWN_DISTANCE = 48`) en lugar de añadir código.
4. **Tope del multiplicador del director: no hizo falta.** Con 1 y 2 el sigilo x1,43/x1,72 da los mismos topes. **No toqué `director_rules.tres`.**
- Solo afecta a enemigos con sala (`home_area`), es decir, los de los mapas generados. Los jefes y los enemigos de las salas de prueba conservan el comportamiento libre anterior, y sus pruebas no cambian.
- Prueba nueva: `tests/test_enemy_pack.gd`. En un mapa real, con todos los enemigos viendo a todo el mapa: como máximo 4 cazadores y 3 de un tipo, y al irse Nico nadie lo sigue y todos dejan de cazar. **Sin las reglas falla** (7 cazadores, 10 siguen cazando).
- **Cambios de diseño para que los revises:**
  - Los enemigos ya no te siguen de sala en sala.
  - Un enemigo que te ve pero no tiene sitio en la caza no emite `enemy_detected_player`, así que el perfil cuenta algo menos de detecciones.
  - Ajustables en `Tuning`.
- **Sin verificar jugando:** que 4 cazadores se sientan bien de dificultad, y que el regreso a casa no se vea raro (por ejemplo, un enemigo que da la espalda en la puerta).

### Fase 4. Sensación de juego — 15:10–15:35
**4a.** `scripts/effects/game_feel.gd` (nuevo): un nodo `GameFeel` que cada nivel jugable añade. Escucha `Events` y se libera con el nivel.
- **Parón de golpe:** 3 cuadros (`HITSTOP_FRAMES`) con `Engine.time_scale = 0`, reanudado por `_process` con reloj real. Los temporizadores que ignoran la escala de tiempo disparaban a los ~6 ms en vez de a los 50 ms. Si el nodo sale del árbol, devuelve el tiempo. En headless está apagado para no alterar las pruebas que cuentan cuadros; la prueba lo fuerza.
- **Sacudida de cámara** al recibir daño: 2 px y 0,15 s, desvaneciéndose.
- **Destello al golpear:** ya existía (los enemigos se ponen blancos 0,12 s). No lo dupliqué.
- **Partículas al morir:** 10 cuadritos oscuros del color del enemigo, 0,45 s; el nodo se libera solo.
- Todo se apaga en `Tuning` con valor 0.

**4b. Legibilidad:**
- Los círculos de aviso del jefe y las zonas de habilidad tienen un anillo oscuro bajo el borde de color (`ZONE_OUTLINE_ALPHA`), y desde 1e van bajo los actores.
- Los textos del HUD tienen contorno oscuro (`HUD_TEXT_OUTLINE = 3`). Antes, el objetivo blanco y el aviso lila apenas se leían sobre el pasto claro.
- Verificado en una captura de un ataque de raíces (`tools/screenshot_map.gd` genera `map_<semilla>_boss_attack.png`).
- No cambié ningún texto.

**4c.** `tests/test_forest_maps.gd` (nuevo), con 30 semillas construidas de verdad:
- La disposición es válida y **409 de 409** conexiones son transitables por un cuerpo del tamaño de Nico.
- **247 salas de combate** tienen sus enemigos dentro del rango de la sala.
- **1038 objetos** (enemigos, jefe, NPC, cofres, portal) están dentro de su sala, sin tocar muros.
- Todas las salas caben en los límites del mapa y Nico empieza en la sala inicial.
- **No falló nada**, así que no hubo que corregir.
- Prueba de 4a y 4b: `tests/test_game_feel.gd`.
- **Sin verificar jugando:** cómo se siente el parón de 3 cuadros en combate real (puede notarse demasiado con golpes muy seguidos), y la sacudida durante el dash.
