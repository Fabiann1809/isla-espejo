# Templo del Eclipse — escala, composición y pasillos (anexo al diseño del 2026-11-06)

Fecha: 2026-11-07 · Rama: `auto/mejoras-noche`

## Por qué
Al jugarlo, el templo se ve pequeño y amontonado comparado con `docs/referencias/templo_mapa.jpg`. La referencia
está casi a la escala del juego (Nico mide unos 30 px en ambas), así que se puede medir en baldosas de 16 px:
- patio central de pilares: unas 34 × 26 baldosas;
- explanada superior con la puerta con cara: unas 42 × 16;
- salas laterales (cofre, trampas): unas 20–22 × 22–36;
- puentes y calzadas entre zonas: 5–7 baldosas, algunos más largos y con quiebres.

Hoy todas las salas miden 30 × 18 (con su pared) y los pasillos 3 baldosas. Además, la composición tiene demasiados
objetos sueltos y las luces saturan la imagen.

Este anexo cubre solo código, datos y diseño de salas. El arte (dibujos de baldosas y sprites) lo lleva otra
persona y no se toca aquí, salvo perillas de `Tuning` que no cambian ningún píxel dibujado.

## Decisiones (de Claude, el usuario puede cambiarlas)
1. **Tamaño por sala.** `RoomData` declara el tamaño de su sala en baldosas (`size_tiles`, por defecto 30 × 18 para
   que el bosque y las Ruinas no cambien). El templo usa tres tamaños:
   - grande 42 × 28 (patio de pilares, jefe, marea de 2 etapas);
   - mediana 34 × 24;
   - chica 26 × 20.
   Todas las medidas son pares, para centrar puertas y salas.
2. **Celda de la cuadrícula por escenario.** `ScenarioData.cell_tiles` (por defecto 30 × 18) y
   `ScenarioData.corridor_tiles` (por defecto 3). El templo usa una celda de 48 × 32. Cada sala se centra en su
   celda, así que el pasillo entre dos salas vecinas mide el hueco real entre sus puertas:
   - entre dos grandes, 6 de ancho y 4 de alto;
   - entre dos chicas, hasta 22 y 12.
   Las puertas de dos vecinas quedan alineadas, porque las dos están en el centro de su celda.
3. **Pasillos largos como puentes.** En el templo, un pasillo es un puente o calzada de piedra sobre la lava.
   - Si mide más de `Tuning.TEMPLE_LANDING_MIN_TILES` (10), tiene un descanso a mitad de camino: una pequeña
     isla con cara de acantilado, un par de braseros y, a veces, un quiebre de altura con escalera.
   - Los puentes no llevan postes en sus orillas, solo barandas bajas.
   - Entre salas de distinta altura, la escalera ocupa un tramo del puente, no el pasillo entero.
4. **Mapa.** El templo usa una cuadrícula de 5 × 5 y un camino principal de 6 a 9 salas. Las salas son más grandes,
   así que el recorrido total no debe crecer demasiado.
5. **Composición de salas**, como en la referencia:
   - un punto focal por sala (la puerta con cara, el altar, el cofre, la colmena);
   - pares simétricos de pilares con braseros enmarcando el camino principal;
   - una runa o símbolo central donde aplique;
   - caminos claros de puerta a punto focal;
   - pocas piezas. Fuera los postes sueltos, las urnas repartidas y las plantas por todas partes;
   - el musgo y las lianas van en las caras de los acantilados, no en el piso.
6. **Luces y lava (solo `Tuning`, sin tocar píxeles):**
   - sin tinte global del mundo en el templo;
   - las luces aditivas más suaves y con un tope a cuánto se suman en un mismo punto;
   - un `modulate` opcional para oscurecer y aplanar la lava y los pisos (`TEMPLE_LAVA_MODULATE`,
     `TEMPLE_FLOOR_MODULATE`), por si el arte lo necesita mientras se rehace.
7. **Cámara.** No se cambia: el proyecto pide preguntar antes de tocar la pantalla. Una cámara más alejada en el
   templo ayudaría a ver salas más grandes; queda como pregunta para el usuario.
8. **Escala de personajes.** No se toca en este anexo. Los pilares más altos son trabajo de arte. Escalar sprites
   de pixel art por un factor no entero se ve mal.

## Lo que no cambia
- El bosque y las Ruinas: mismos tamaños, mismos mapas para la misma semilla y mismos dibujos.
- Las mecánicas: alturas, marea, elenco de enemigos, trampas y Director.
- Todas las validaciones (`TemplePlan`, reachability con props, `spawn_ok`) siguen valiendo con salas de cualquier
  tamaño.
