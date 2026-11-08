# Nivel 3 — Templo del Eclipse: diseño

Fecha: 2026-11-06 · Rama: `auto/mejoras-noche` (repo `isla-espejo`)

## 1. Intención

El tercer capítulo es un templo antiguo construido **sobre un mar de lava**. Tiene que verse como las dos
imágenes de referencia que trajo el usuario: islas de piedra con caras de acantilado que caen a la lava,
pilares tallados, braseros, escaleras entre pisos y salas a las que solo se llega por puentes. Debe sentirse
**en capas y con alturas reales, nunca plano**, y **todo debe moverse**: nada de arte estático.

La mecánica propia del nivel es la **marea de lava**. En algunas salas la lava sube por etapas, inunda los
pisos bajos ante los ojos del jugador y lo obliga a subir mientras pelea contra los enemigos que hay ahí y
contra los que van apareciendo. Cuando mata a suficientes, la lava baja. Es el momento memorable del capítulo.

El nivel cierra el núcleo del juego (ver `CLAUDE.md`): los mapas son distintos en cada partida (generador
procedural más salas hechas a mano), y la isla aprende (el Director ajusta salas y enemigos).

## 2. Objetivos

1. **Escenario `temple` jugable** que sigue a las Ruinas (`ruins.tres` → `next_scenario`). Usa el
   generador de mapas existente (`MapGenerator`), con salas irregulares y pesos del Director.
2. **Alturas reales de 3 niveles** (bajo, medio y alto), con colisión correcta por nivel, escaleras entre
   niveles y lectura visual clara de qué está encima de qué.
3. **Salas no rectangulares** dibujadas como plantas de texto (igual que `RuinShape` en las Ruinas):
   islas de piedra rodeadas de lava, plataformas, escaleras, puentes, pilares y salas o rincones a los
   que solo se accede por un puente.
4. **Marea de lava por etapas** en salas marcadas (ver §5).
5. **Variedad de enemigos por partida** con los 25 enemigos del templo que ya existen (ver §6).
6. **Arte nítido, propio y animado**, dibujado por script a escala de juego (ver §7). El zip
   `Templo_Antiguo_TileSet_Tecnico_Godot4.zip` es **solo referencia** de piezas, paleta y composición.
7. Pruebas automáticas de cada sistema nuevo. `./tools/run_tests.sh` pasa completo.

## 3. No objetivos (fuera de este trabajo)

- Ataques propios del jefe **Guardián antiguo**. La sala del jefe usa la escena que ya existe
  (`scenes/enemies/ancient_guardian.tscn`) tal como está.
- El **Mercader** (NPC, diálogos y tienda) y el cierre de la historia. Si la sala especial necesita un
  personaje, va vacía: `special_npc_scene` queda sin asignar.
- Arte, comportamiento o balance nuevos de los 25 enemigos. Se colocan tal como existen.
- Música y sonidos nuevos. Si el banco de sonido no tiene pista `temple`, no suena música; no se inventa.
- Cambios a la resolución, a la cámara o a los controles.

## 4. Antiobjetivos (sería un fracaso aunque "funcione")

- Que se vea **plano**: pisos de distinta altura sin cara de acantilado, sin sombra proyectada o sin
  borde que los separe.
- Arte **borroso o reescalado** (el problema que ya obligó a redibujar el pack de enemigos), o baldosas
  con costuras o marcos visibles al repetirse.
- **Cosas quietas** donde el jugador espera movimiento: lava, fuego, cascadas de lava, runas brillantes,
  humo, brasas.
- **Colisiones mentirosas**: caminar sobre la lava sin efecto, quedar atrapado en un borde, flechas que
  atraviesan un acantilado visto desde abajo, enemigos que aparecen dentro de la lava o en un nivel
  inalcanzable.
- Salas **cuadradas** o con forma de caja.
- Romper el bosque o las Ruinas: sus mapas deben verse y jugarse igual que antes.

## 5. Mecánicas

### 5.1 Alturas: de 2 a 3 niveles

Hoy `Heights` tiene LOW (0) y HIGH (1), con las capas de física 8 `block_low` y 9 `block_high`. Se
generaliza a **N niveles con una capa por nivel**: la capa `block_level_k` bloquea a los actores que
están en el nivel `k`.

- Nivel 0 → capa 8 (la actual `block_low`); nivel 1 → capa 9 (la actual `block_high`); nivel 2 → capa
  10 nueva (`block_top`). Se nombra en `project.godot`.
- Una plataforma de altura `h` pone su huella en las capas de todos los niveles por debajo de `h`, para
  que no se pueda entrar desde abajo salvo por su escalera. Su borde va en la capa del nivel `h`, para
  que nadie camine fuera de ella.
- Con esto, las Ruinas (que solo usan los niveles 0 y 1) **quedan idénticas**. `tests/test_heights.gd`
  debe seguir pasando sin cambios, y se le agregan casos de 3 niveles.
- Los proyectiles siguen la regla actual: los detiene lo que bloquea su nivel visto desde abajo, y vuelan
  sobre bordes y sobre lava.
- Los actores cambian de nivel solo en una `StairZone`, que ahora sube de `k` a `k+1` en vez de LOW↔HIGH.
- `RoomData.height` pasa a admitir 0..2. Una sala del templo tiene un piso base y, dentro, plataformas
  más altas.

### 5.2 Lava

- La lava es un **piso de peligro**, no una pared. El mar de lava que rodea las islas tiene colisión de
  borde para los actores que caminan (no se puede entrar caminando, igual que el agua de las Ruinas),
  así que solo daña la lava que **sube sobre un piso**. Los voladores (murciélagos, manta, reina) la
  cruzan.
- El daño de la lava usa los componentes de siempre: un `Hitbox` de la marea con daño periódico contra el
  `Hurtbox` de quien esté en un nivel inundado. Nunca daño ad hoc.
- Los proyectiles vuelan sobre la lava.

### 5.3 Marea de lava (salas `surge`)

Una sala con la etiqueta `surge` (en su `RoomData`) tiene una marea por etapas:

1. **Disparo.** Nico entra a la sala y la cruza unos pasos. Las puertas se sellan con una reja o un
   muro de fuego animado mientras dura la marea.
2. **Aviso.** Unos 2 a 3 s antes de cada subida: temblor de cámara suave, burbujeo en los bordes, las
   grietas del piso bajo brillan y aparece un texto corto en el HUD (en español, desde `data/`).
3. **Subida, etapa 1.** La lava cubre el **nivel 0** de la sala: sube desde los bordes hacia adentro de
   forma visible (no un corte instantáneo). Quien quede en el nivel 0 recibe daño periódico. Las
   plataformas de nivel 1 y 2 quedan a salvo.
4. **Combate.** Pelean los enemigos que ya estaban en la sala más **oleadas** que aparecen en las
   plataformas a salvo (nunca en un piso inundado ni encima de Nico), con un anillo de fuego o humo antes
   de aparecer.
5. **Etapa 2 (opcional por sala).** Al matar `kills_stage_1` enemigos, la lava puede subir al **nivel 1**
   y solo queda a salvo el nivel 2. Cada sala decide en sus datos cuántas etapas tiene (1 o 2).
6. **Bajada.** Al matar `kills_to_recede` enemigos de la etapa final, la lava baja etapa por etapa, deja
   el piso humeante unos segundos (sin daño) y las puertas se abren. La sala cuenta como despejada.

Todos los números (cuántas muertes, tiempos de aviso, velocidad de subida, daño por segundo, tamaño y
ritmo de las oleadas) van en los datos de la sala o en `Tuning`, nunca en el código. El Director
puede escalar las oleadas con los multiplicadores que ya aplica a los enemigos.

Requisitos para que una sala `surge` sea justa (los valida el generador de salas, ver §8):
- Desde cualquier punto del nivel 0 hay una escalera a menos de N casillas.
- El nivel seguro tiene espacio de combate real: un área mínima y lugares de aparición para las oleadas.
- La cámara puede mostrar la subida.

Eventos nuevos en `Events`: `lava_surge_started(room, stage)`, `lava_surge_receded(room)`, y daño por
lava publicado con su origen para que `PlayerProfile` y `GameFeel` puedan escucharlo.

### 5.4 Puentes y salas aisladas

- **Dentro de una sala** la planta de texto puede tener islas separadas por lava y unidas por puentes
  (de piedra o de madera). Hay rincones a los que **solo se llega por un puente**: un cofre, una
  plataforma con un enemigo a distancia o el altar de la sala.
- **Entre salas** los pasillos del templo no son pasillos con paredes: son **puentes o calzadas de
  piedra sobre la lava**, con barandas. Si dos salas tienen distinta altura, el pasillo es una escalera
  (lo mismo que ya hacen las Ruinas, con el arte del templo).
- El agua de las Ruinas y la lava del templo comparten la idea: el puente cruza por encima y su baranda
  cercana se ordena por `y` con los actores.

## 6. Variedad de enemigos

- Hay **25 enemigos del templo** con su mecánica, arte y prueba (`CLAUDE.md`, "Temple enemies"). Todos
  entran al `enemy_pool` del escenario.
- **Elenco por partida:** al generar el mapa, `Level` elige un subconjunto de `roster_size` enemigos
  (dato del escenario, propuesta de 10). La elección depende de la semilla, así que la misma semilla da
  el mismo elenco, y se pondera con `enemy_weights` del escenario y con los pesos del Director.
  `roster_size = 0` significa usar el pool completo, para que el bosque y las Ruinas no cambien.
- **Por sala:** cada sala sortea sus enemigos del elenco con `Room.pick_enemies` (sin repetir por azar).
  Una sala puede dar preferencia a ciertos enemigos con un diccionario opcional `enemy_affinity`
  (id → multiplicador) en su `RoomData`, por ejemplo voladores en salas con mucha lava o
  `baldosa_hambrienta` en pisos de baldosas.
- **Restricciones por enemigo** (para no romper sus mecánicas): `gusano_puentes` necesita puentes, la
  `manta_hollin` vuela sobre lava, `monje_sin_rostro` necesita símbolos en el piso, `vasija_poseida`
  necesita vasijas señuelo, `manos_abismo` sale desde bordes, `nucleo_cria` trae su reina. El
  constructor revisa cada uno, y si un enemigo necesita algo de la sala, lo declara en sus datos y la
  sala lo provee o no lo recibe.
- Ningún enemigo aparece en lava ni en un nivel sin acceso desde donde está Nico. Un enemigo de una
  plataforma toma la altura de esa plataforma, no solo la de la sala.

## 7. Arte y animación

**Método:** igual que las Ruinas. Un script de Python (`tools/make_temple_tileset_art.py` más los que
hagan falta) dibuja **pixel a pixel** a la escala del juego (cuadrícula de 16 px, Nico mide 32×32), con
una paleta corta y propia, contorno de 1 px y luz desde arriba a la izquierda. Después se genera un
perfil `data/tilesets/temple.tres` y un tema `data/themes/temple.tres`. Nada se reescala del zip.

**Paleta (del zip y las referencias):** piedra rosácea y gris cálido, musgo verde amarillento, lava de
amarillo a naranja y rojo oscuro, costra de lava casi negra con grietas brillantes, bronce y oro opaco
para relieves, rojo de estandartes.

**Lectura de capas y alturas (lo más importante):**
- Orden de dibujo de abajo hacia arriba: mar de lava animado → resplandor de la lava sobre la base de
  las rocas → caras de acantilado de cada isla (más altas cuanto más alto el nivel: unos 16 px por
  nivel) → piso del nivel 0 → sombra proyectada de las plataformas sobre el piso de abajo → cara y piso
  del nivel 1 → nivel 2 → actores y objetos de pie ordenados por `y` → luces aditivas → tinte del mundo.
- Cada borde de isla tiene **costra** donde toca la lava (una franja oscura con grietas que laten) y
  algo de musgo o lianas que cuelgan de la cara del acantilado.
- Las plataformas proyectan sombra hacia el sur y sobre la lava. La lava ilumina desde abajo las caras
  de los acantilados.

**Todo animado** (cada pieza con 4 a 8 cuadros y su propio ritmo, desfasados entre sí para que no
parpadeen al unísono):
- Lava: flujo lento de la superficie, burbujas que revientan al azar, brillo que pulsa en la costra.
- Cascadas de lava que caen de las paredes y de las bocas de las estatuas, con salpicadura al pie.
- Fuego: antorchas, braseros, braseros sobre pedestal, llamas de suelo y llamas de la boca del portal.
- Runas y relieves que brillan con un pulso lento; el símbolo del piso de la sala principal gira o
  respira.
- Humo y brasas en partículas que suben desde la lava; ondas de calor suaves cerca de la lava.
- Lianas y estandartes que se mecen apenas.
- Géiseres de lava como elemento ambiental (sin daño, salvo que la sala los use como trampa).
- Los objetos del zip que sirven como guía de piezas: pilar tallado, pilar de bloques, columna baja,
  estatua guardián, arco de puerta, portal con cara del templo, urnas, vasijas, barriles, escombros,
  rocas humeantes, plantas, braseros, púas, sierra, roca rodante y placa de presión.

**Luz:** cada fuego, runa y lava lleva un resplandor aditivo que titila (como `RuinLight`). El tema
tiñe el mundo hacia un rojo anaranjado cálido.

## 8. Salas y generación de mapas

- **Plantas de texto** como `RuinShape`: 18 filas × 30 columnas, un carácter por casilla de 16 px.
  Propuesta de alfabeto (el constructor la ajusta si hace falta): `~` lava, `.` piso nivel 0, `1` piso
  nivel 1, `2` piso nivel 2, `^`/`v`/`<`/`>` escalera que sube hacia esa dirección, `=` puente, `r`
  baranda, `P` pilar, `#` roca maciza. El anillo exterior es la pared de la sala y las puertas no se
  tocan.
- **Generador de salas** `tools/make_temple_rooms.py`, igual que `make_ruins_rooms.py`: dibuja las
  plantas, **valida** que todas las puertas se conecten entre sí a pie, que cada escalera tenga casillas
  libres delante, que los puntos de aparición estén en piso accesible y no en lava, que las salas `surge`
  cumplan los requisitos de §5.3, y que ningún piso sea un rectángulo simple.
- **Tipos de sala** (propuesta de unas 10 a 12):
  - inicio;
  - jefe (fijo y elevado);
  - patio de pilares (como el centro de la referencia);
  - islas con puentes;
  - terrazas escalonadas de 3 niveles;
  - pasarela de trampas (púas, sierra, roca rodante);
  - cascadas de lava;
  - santuario del cofre (solo se llega por un puente);
  - evento;
  - especial;
  - al menos **3 salas `surge`** con plantas distintas: una de 1 etapa y dos de 2 etapas.
- **Escenario** `data/scenarios/temple.tres` y `scenes/levels/temple_level.tscn`: cuadrícula más grande
  que las Ruinas, las salas `surge` con peso alto para que salgan 1 o 2 por mapa, los cofres y recursos
  de siempre, el Guardián antiguo como jefe y el portal de salida. Las etiquetas de sala (`surge`,
  `traps`, `bridges`, etc.) dejan que el Director pondere qué salas salen según el estilo del jugador
  (`data/ai/director_rules.tres`, sin tocar el código del Director).
- Las Ruinas, al terminar, llevan al templo. El templo pasa a ser el último capítulo y muestra el final
  del viaje (`end_after_last_chapter`), como hacen hoy las Ruinas.
- El fondo entre y alrededor de las salas es **mar de lava** con islotes de roca, cascadas en los bordes
  y columnas caídas (equivalente a `RockBackdrop`), pintado por trozos.

## 9. Restricciones del proyecto (de `CLAUDE.md`)

- GDScript con tipos estáticos; identificadores, comentarios y commits en inglés; todo texto que ve el
  jugador va en español en `data/`.
- Los datos son datos: salas, escenario, tema, perfil de tiles, oleadas y valores de la marea en `data/`
  o `Tuning`. Agregar una sala o un enemigo no debe obligar a tocar los sistemas centrales.
- El daño solo con `Hitbox`/`Hurtbox`/`HealthComponent`. El combate solo emite `Events`; `GameFeel` y
  `Sound` escuchan.
- Las reglas de orden de dibujo (`FLOOR_Z`, `GROUND_FX_Z`, actores en z 0 ordenados por `y`) se
  respetan. `tests/test_draw_order.gd` debe seguir pasando.
- Cada sistema nuevo lleva su `tests/test_<sistema>.gd` (mínimo: `test_temple`, `test_temple_shape`,
  `test_lava_surge`, `test_heights` ampliado, `test_enemy_roster`). `test_room_designs.gd` y
  `test_map_generator.gd` deben cubrir el escenario nuevo.
- Commits en Conventional Commits, **sin `Co-Authored-By` ni ninguna atribución a IA** (regla 8, que
  manda sobre cualquier otra indicación). Un commit por tarea y la casilla de `docs/TAREAS.md` marcada
  en el mismo commit. Se trabaja en la rama `auto/mejoras-noche`. Nada de push ni tags sin pedirlo.
- Hay que actualizar `docs/JUEGO.md` (hoy dice que el templo es plano, sin plataformas ni niveles de
  altura: el usuario cambió esa decisión), `docs/TAREAS.md` (sección 11) y `CLAUDE.md` (sistemas
  nuevos), igual que se documentaron las Ruinas.
- Godot: en este equipo solo está la versión .NET (`Godot_v4.7.2-stable_mono_win64_console.exe` en
  Descargas). Se usa para correr las pruebas si funciona con un proyecto solo GDScript; si no, se avisa.

## 10. Decisiones tomadas tras la revisión

Marcadas como **[decisión de Claude]** las que no dijo el usuario. Él puede cambiarlas.

1. **Capas de física para 3 niveles [decisión de Claude].** Se separan huella y borde para que los
   proyectiles sigan la regla. Las capas 8 y 9 conservan su significado actual (huella que bloquea al
   nivel 0 y borde que bloquea al nivel 1), así que las Ruinas no cambian. La capa 10 es el borde de las
   plataformas de nivel 2 (bloquea a los actores del nivel 2). La capa 11 es la huella de las
   plataformas de nivel 2 (bloquea a los actores de los niveles 0 y 1, y la ven los sensores de pared de
   los proyectiles de esos niveles: un acantilado visto desde abajo). Se nombran en `project.godot`.
2. **Altura de las salas [decisión de Claude].** La altura base de una sala del templo es 0 o 1. Dentro
   de una sala, las plataformas suben como máximo hasta 2. Dos salas vecinas difieren en 1 nivel como
   máximo; el generador de mapas lo respeta y nunca une dos salas a 2 niveles de distancia. Las salas
   `surge` tienen base 0. La marea inunda niveles absolutos: primero el 0 y luego el 1.
3. **Enemigos y alturas [decisión de Claude].** No hay búsqueda de rutas entre niveles: cada enemigo vive
   en el nivel donde aparece (el de su plataforma, no solo el de la sala). En una sala `surge`, los
   enemigos iniciales y todas las oleadas aparecen solo en el nivel que queda a salvo al final, así que
   la pelea siempre es alcanzable. La lava daña a cualquier actor que camine en un nivel inundado,
   salvo a los voladores. Una muerte por lava **no** cuenta para `kills_stage_1` ni para `kills_to_recede`.
4. **Fin de una sala `surge` [decisión de Claude].** Al llegar a `kills_to_recede` dejan de salir
   oleadas y la lava baja. Las puertas se abren cuando mueren los enemigos que quedan vivos, igual que
   en cualquier sala (`Room` emite `cleared`).
5. **Cómo se llega al templo [decisión de Claude].** `ruins.tres` → `next_scenario = temple`, que
   funcionará cuando exista el jefe de las Ruinas. Mientras tanto, `scenes/levels/temple_level.tscn`
   arranca directamente en el templo (como `ruins_level.tscn`), para probarlo con F6 y desde las pruebas.
   No se abre el portal sellado de las Ruinas.
6. **Plataformas que salen de la lava.** El usuario pidió salas a las que solo se llega por puentes, así
   que una plataforma puede salir directamente de la lava y tener como único acceso un puente. La línea
   de `docs/TAREAS.md` §11 ("sin plataformas flotantes") se actualiza: lo que no hay son plataformas
   flotando en el aire, sin roca debajo.
7. **Imágenes de referencia [decisión de Claude].** Las dos imágenes que mandó el usuario en el chat
   (enemigos del nivel 3 y el mapa del templo) se copian a `docs/referencias/` como imágenes de
   concepto, igual que las de las Ruinas.
8. **Flujo de trabajo.** Lo pidió el usuario directamente, así que no importa si la tarea es de A o de
   B. Se hacen commits en `auto/mejoras-noche` sin push. El cambio sin commitear que ya había en
   `project.godot` es un reordenamiento automático de Godot (las mismas secciones en otro orden). Se
   conserva y se edita encima, sin perder nada.

## 11. Lo que queda a criterio del constructor

- El alfabeto exacto de las plantas, los nombres de los roles nuevos de tiles y cómo se reparte el arte
  en hojas.
- Los números iniciales de la marea, las oleadas y el elenco (se dejan en datos para ajustarlos jugando).
- El número exacto de salas por tipo, dentro de lo indicado en §8.
- Cómo se implementa la subida visual de la lava (máscara que crece, capa de tiles que avanza casilla a
  casilla o un shader simple), siempre que se vea subir desde los bordes y no aparezca de golpe.
- El orden de trabajo y cómo se reparte entre agentes, respetando que dos agentes nunca editan los
  mismos archivos a la vez.
