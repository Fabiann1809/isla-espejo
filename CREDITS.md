# Créditos

Todo recurso de terceros (arte, música, efectos, fuentes) debe listarse aquí **en el mismo commit** que lo añade.

| Recurso | Autor | Licencia | Enlace | Dónde se usa |
|---|---|---|---|---|
| Roguelike/RPG Pack (tileset de 16x16: terreno, árboles, agua, cofres...) | Kenney | CC0 1.0 | https://kenney.nl/assets/roguelike-rpg-pack | `assets/tilesets/kenney_roguelike_rpg/` (escenario 1, Bosque de la Aurora) |
| Atlas de Bosque de Fantasía (árboles compuestos, arbustos, rocas, troncos, borde oscuro) | Atlas de referencia proporcionado para Isla Espejo | Uso interno del proyecto | Referencia directa | `assets/art_forest/` (props de salas, árboles exteriores) |
| Enemigos del templo, isla 3 (centinela, carcelero, acólito, verdugo, duelista, salamandra, gusano, caracol, carnero, manta) | Equipo de Isla Espejo (bestiario de referencia recortado y animado; reducido a la escala del juego con `tools/make_temple_enemy_art.py`) | Uso interno del proyecto | Arte propio | `assets/sprites/<enemigo>/` (fuente de 128 px en `source/`) |
| Enemigos del templo antiguo, segundo paquete (araña, baldosa, campanero, custodio, forjador, manos, máscara, monje, núcleo, ojo, oráculo, relojero, rueda, vasija) y animaciones nuevas del carcelero y el centinela | Equipo de Isla Espejo (láminas propias recortadas y animadas; escaladas con `tools/make_temple_enemy_art.py`) | Uso interno del proyecto | Arte propio | `assets/sprites/<enemigo>/` (fuente de 128 px en `source/`) |
| Kenney Fonts (fuentes pixel "Kenney Pixel" y "Kenney Mini") | Kenney | CC0 1.0 | https://kenney.nl/assets/kenney-fonts | `assets/fonts/` (números de daño y textos pequeños) |
| Impact Sounds (golpes, pasos en hierba, impactos de madera y metal) | Kenney | CC0 1.0 | https://kenney.nl/assets/impact-sounds | `assets/audio/sfx/` (flechas, daño, muertes, pasos, golpe del jefe) |
| Interface Sounds (clics, selección, gotas) | Kenney | CC0 1.0 | https://kenney.nl/assets/interface-sounds | `assets/audio/sfx/` (menús, diálogos, habilidad Corriente) |
| RPG Audio (tela, monedas, puertas, hacha) | Kenney | CC0 1.0 | https://kenney.nl/assets/rpg-audio | `assets/audio/sfx/` (esquiva, oro, cofre, raíces del jefe) |
| Digital Audio (power-ups, tonos) | Kenney | CC0 1.0 | https://kenney.nl/assets/digital-audio | `assets/audio/sfx/` (corazón, habilidad Sombra) |
| Iremos Forest Theme Loop (música) | beardalaxy | CC0 1.0 | https://opengameart.org/content/iremos-forest-theme-loop | `assets/audio/music/menu.ogg` (menú principal) |
| Beautiful Forest [Orchestra] (música) | nene | CC0 1.0 | https://opengameart.org/content/beautiful-forest-orchestra | `assets/audio/music/forest.ogg` (Bosque de la Aurora) |
| RPG Battle Theme II (música) | cleytonkauffman | CC0 1.0 | https://opengameart.org/content/rpg-battle-theme-ii | `assets/audio/music/boss.ogg` (pelea contra el jefe) |

Los personajes y animaciones son originales del equipo (hechos con Pixelorama). Los sonidos `*.wav` de `assets/audio/sfx/` (arco, portal, fragmento, trueno, aviso del jefe...) son propios, generados con `tools/make_synth_sfx.py`.

