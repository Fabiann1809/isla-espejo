# Cómo agregar un tileset nuevo

El juego no usa coordenadas de la hoja de tiles: pide cada tile por su **rol** («pasto», «pino», «estanque»…) y un **perfil de tileset** (`TilesetProfile`, en `data/tilesets/`) dice qué tile de qué hoja cumple cada rol. Para cambiar el arte de un escenario se escribe un perfil nuevo; no hace falta tocar código ni salas.

- Perfil actual: `data/tilesets/kenney_forest.tres` (Kenney Roguelike/RPG, 16x16, 1 px entre tiles). Lo genera `tools/make_tileset_profile.gd`.
- Lista de roles y para qué sirve cada uno: constantes de `scripts/world/tile_art.gd` (`TileArt.ROLES` y `TileArt.PATTERNS`).
- Qué perfil usa cada escenario: el campo `tileset` de su tema (`data/themes/<escenario>.tres`). Vacío = el perfil por defecto.

## 1. Qué imágenes necesita

- **Una hoja PNG** con todos los tiles en cuadrícula. Si el pack viene en varias hojas (terreno, árboles, objetos), júntalas en una sola con cualquier editor (o pide un script que lo haga) y guarda el original.
- Tiles **cuadrados**, todos del mismo tamaño. Lo ideal es 16x16 (la cuadrícula del juego). Si son de 32x32, mira el apartado 4.
- Fondo **transparente** en árboles, arbustos, rocas, hongos, flores y bordes de caminos: se dibujan sobre el pasto.
- Copia la carpeta del pack a `assets/tilesets/<pack>/` **con su archivo de licencia** y añádelo a `CREDITS.md` en el mismo commit.

## 2. Qué roles hay que mapear

Todos son obligatorios (la prueba avisa si falta alguno). Un rol puede repetir el tile de otro si el pack no tiene uno propio (por ejemplo, las cuatro flores pueden ser la misma).

| Grupo | Roles | Notas |
|---|---|---|
| Suelo | `grass`, `grass_textured`, `dirt` | `grass`: suelo de las salas. `grass_textured`: suelo del bosque de fondo y centro de las manchas. `dirt`: caminos y puertas (debe ser un tile distinto de todos los demás). |
| Detalles del suelo | `flowers_red`, `flowers_white`, `flowers_blue`, `tuft_a`, `tuft_b`, `pebbles`, `rock_small`, `rock_mossy`, `stump`, `mushroom_brown`, `mushroom_orange`, `mushroom_red`, `mushroom_pale`, `flower_purple`, `flower_yellow` | Sin colisión, sobre el pasto. |
| Árboles y arbustos | `pine`, `round_tree`, `bush`, `pine_tall_top`/`pine_tall_base`, `round_tree_tall_top`/`round_tree_tall_base` | Los «tall» son dos tiles: copa arriba y tronco abajo. El tronco ocupa la parte baja del tile (ahí está la colisión). |
| Bosque de fondo | `tree_dark`, `pine_dark`, `tree_dark_tall_top`/`_base`, `pine_dark_tall_top`/`_base`, `bush_dark`, `bush_berries`, `rock`, `bush_orange` | Versiones oscuras para el bosque que rodea el mapa. Si el pack no las tiene, usa las normales: el fondo ya se oscurece con un tinte. |
| Objetos | `planks` (puente), `campfire`, `logs`, `chest_closed`, `chest_open` | |
| Áreas (patrones) | `pond` (9), `grass_patch` (9), `dirt_patch` (9), `grass_patch_inner` (4), `dirt_patch_inner` (4) | Ver abajo. |

**Patrones de 9** (nueve partes): fila por fila, *arriba-izquierda, arriba, arriba-derecha, izquierda, centro, derecha, abajo-izquierda, abajo, abajo-derecha*. Son el agua con su orilla (`pond`), una mancha de pasto con bordes (`grass_patch`) y una mancha de tierra con bordes (`dirt_patch`, que también redondea los bordes de los caminos).

**Esquinas interiores (4)**: donde un camino o una mancha gira hacia dentro (un cruce, una T). Orden: *SE, SO, NE, NO*, nombradas por la diagonal que **no** es camino. Si el pack no las trae, repite el centro del patrón: se verá en escuadra, pero funciona.

## 3. Pasos

1. Rotula la hoja para leer las coordenadas (columna, fila) de cada tile (necesita ventana):
   `godot --path . --script res://tools/atlas_preview.gd -- <hoja.png> <salida.png> <col0> <fila0> <columnas> <filas> [escala] [tile] [separación]`
   (por ejemplo `... -- sheet.png out.png 10 8 15 8 4 16 1` para un trozo de la hoja actual).
2. Copia `tools/make_tileset_profile.gd` a `tools/make_tileset_<pack>.gd`. Cambia `SHEET`, `OUT` (`res://data/tilesets/<pack>.tres`), `tile_size`, `separation` (píxeles entre tiles) y `margin` (píxeles antes del primero), y escribe las coordenadas de cada rol en `TILES` y `PATTERNS`.
3. Ejecútalo: `godot --headless --path . --script res://tools/make_tileset_<pack>.gd`. Si falta un rol o un tile cae fuera de la hoja, lo dice y no guarda nada.
4. En el tema del escenario (`data/themes/<escenario>.tres`, o en el inspector) pon el perfil nuevo en `tileset`.
5. Si quieres pintar con ese pack en el editor, guarda su TileSet como hace `tools/make_forest_tileset.gd`. El juego no lo necesita: construye el suyo.

## 4. Si el pack es de 32x32

El mundo está hecho en una cuadrícula de 16 px: salas de 30x18 celdas (480x288 px), puertas, colisión de árboles, props y pasillos. **No se cambia.** Opciones:

| Opción | Qué hace | Riesgo |
|---|---|---|
| **A. Ajustar a la cuadrícula** (implementada) | Cada tile de 32 px se dibuja a la mitad, en su celda de 16 px. Se activa con `Tuning.TILESET_FIT_TO_GRID = true`. | Bajo: no cambia salas, colisión ni generador (lo comprueba `tests/test_tileset_profile.gd`). Pero el arte se ve a la mitad de resolución: los detalles de 1 px de un pack de 32 desaparecen, así que se pierde parte de lo que se ganaba con ese pack. |
| B. Celda lógica de 2x2 | Un tile de 32 px ocupa 2x2 celdas de 16: el suelo se pinta por cuartos y cada árbol cubre 2x2 celdas. | Medio: el suelo queda a resolución completa, pero árboles y arbustos pasan a ocupar 32x32 y hay que rehacer la colisión de los props y revisar todas las salas (`tools/make_forest_rooms.py`) para que no tapen puertas. |
| C. Regenerar todo a 32 | Cuadrícula de 32 px, salas de 960x576 px. | Alto: cambia el generador, la cámara (que con 640x360 vería la cuarta parte de una sala), la velocidad relativa de todo y las pruebas. Descartada. |

Recomendación: buscar el pack en **16x16** (la mayoría lo ofrece) o, si solo existe en 32, empezar con la opción A para ver cómo queda y decidir entonces si vale la pena la B.

## 5. Cómo probarlo

- `./tools/run_tests.sh test_tileset_profile test_forest test_forest_look`: roles completos, patrones con las piezas que tocan y caminos con esquinas.
- `godot --path . --script res://tools/screenshot_map.gd -- 4242 <carpeta>` (necesita ventana): vistas del mapa con la semilla 4242. Mira sobre todo los cruces de caminos, las orillas del estanque y los árboles altos.
- `godot --headless --path . --script res://tools/dump_tiles.gd`: un hash por mapa de todo lo que se dibuja. Si cambias cómo se buscan los tiles y quieres comprobar que el juego se ve **idéntico**, el hash debe ser el mismo antes y después.
