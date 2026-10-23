# Isla Espejo — Documento de juego

> Título provisional (antes "Camino a casa"). Inspirado en el juego "El camino a casa", con alcance ajustado y una propuesta propia: **la isla aprende cómo juegas**.
> Este documento es la fuente de verdad del alcance. Si algo no está aquí, no se construye sin preguntar.

## 1. Resumen
Roguelike de exploración y combate en **pixel art, vista superior (top-down)**, para **escritorio (Windows)**, hecho con **Godot 4.7** en GDScript. Un equipo de **2 personas**, unos **2 meses**, como proyecto de portafolio.

Nico queda atrapado en una isla desconocida tras una tormenta. Su brújula se rompió y los fragmentos están repartidos en tres escenarios custodiados por un jefe cada uno. Al derrotar a un jefe, Nico recupera un fragmento y obtiene una habilidad. Al reunirlos puede volver a casa.

### Pilares
1. **Cada partida es distinta.** Los escenarios se generan combinando salas diseñadas a mano.
2. **Una habilidad por jefe.** Habilidades fijas, simples y distintas entre sí.
3. **La isla aprende.** Una IA adaptativa de dos capas registra cómo juegas y modifica el juego en respuesta.

### ¿Qué es un roguelike?
Un juego de exploración y combate donde los escenarios cambian en cada partida y morir reinicia el intento (total o parcialmente), por lo que cada decisión importa y se puede rejugar muchas veces. El nombre viene de *Rogue* (1980).

## 2. Alcance

### Dentro del alcance (MVP)
| Área | Contenido |
|---|---|
| Jugador | Nico: movimiento en 8 direcciones, ataque con espada, esquiva (dash), vida, 3 habilidades obtenidas de los jefes |
| Escenarios | 3: Bosque de la Aurora, Ruinas de la Montaña, Templo del Eclipse |
| Cámara | Sigue a Nico (los escenarios son más grandes que la pantalla) |
| Mapas | Procedurales: el algoritmo coloca y conecta salas diseñadas a mano. Inicio y arena del jefe son fijos |
| Enemigos | 6 con patrones distintos (ver sección 6) |
| Jefes | 3 (ver sección 7) |
| NPCs | 3: Anciano, Viajera, Mercader. **Solo diálogo** (sin tienda) |
| Habilidades | 3 fijas, una por jefe, **sin combinaciones** |
| IA | Capa 1 (perfil del jugador) y capa 2 (la isla reacciona). Ambas obligatorias |
| Historia | Prólogo, 3 capítulos, final, con diálogos en el juego |
| Interfaz | Menú principal, HUD, pausa, pantalla de muerte con resumen de perfil, créditos |
| Guardado | Perfil del jugador y progreso básico |
| Sonido | Música y efectos básicos (packs gratuitos con créditos) |
| Arte | Personajes y animaciones propios (Pixelorama). Tilesets de un pack gratuito si hace falta |

### Fuera del alcance
- Recolección y construcción.
- Multijugador.
- Tienda del Mercader (es solo diálogo).
- Combinaciones de habilidades (extra opcional, ver sección 5).
- Plataformas flotantes y niveles de altura (se reemplazan por caminos de piedra sobre lava).
- Aprendizaje automático / redes neuronales (capa 3 de IA, extra opcional).
- Un cuarto escenario y un Guardián de la isla como jefe separado (extras opcionales).

### Decisiones de diseño tomadas
- La cámara **sigue a Nico**.
- Los mapas son **mixtos**: salas a mano más generación por algoritmo.
- Las habilidades son **fijas**, una por jefe. El sistema se programa de forma modular para poder añadir combos después.
- El Guardián del bosque es el **jefe del capítulo 1**.
- El Guardián de la isla se **fusiona con el último jefe** o queda como cinemática (extra).
- **Muerte (provisional, a confirmar):** al morir Nico reaparece al inicio del escenario actual con un mapa nuevo. Conserva fragmentos y habilidades ya obtenidos y el perfil del jugador. La partida completa no se reinicia.

## 3. Historia

### Prólogo — La tormenta
Nico viaja por mar cuando una tormenta destruye su ruta. Despierta en una playa desconocida con la brújula rota y sin varios fragmentos.

### Capítulo 1 — Bosque de la Aurora
Nico entra en un bosque antiguo siguiendo una señal de la brújula. Conoce al **Anciano**, que le explica que la isla guarda a quienes intentan marcharse. El primer fragmento (verde) está protegido por el **Guardián del bosque**.

### Capítulo 2 — Ruinas de la Montaña
El segundo fragmento (azul) está en unas ruinas antiguas. Nico encuentra a la **Viajera**, que no recuerda cómo llegó. Descubren que otros viajeros estuvieron allí antes. Las ruinas sugieren que la isla tiene voluntad propia. Lo protege la **Serpiente de piedra**.

### Capítulo 3 — Templo del Eclipse
El último fragmento (violeta) está en un templo. El **Mercader** ofrece ayuda a cambio de "precios". Nico descubre que los fragmentos funcionan como **llaves que mantienen el vínculo entre la isla y quienes quedan atrapados**. Lo protege el **Guardián antiguo**.

### Clímax y final
Al reunir los fragmentos, Nico abre el camino de regreso. Reconstruye la brújula y vuelve a casa. Antes de irse mira atrás y comprende que la isla no solo lo había atrapado: también lo había obligado a enfrentar el miedo de no encontrar el camino de regreso. La isla lo había estado reflejando todo el tiempo.

### Vínculo con la IA
La isla "aprende" a Nico. Cuando Nico muere, la isla recuerda: *"La isla vuelve a empezar. Pero Nico recuerda."* El perfil guardado es la memoria de la isla.

## 4. Mapas

| # | Escenario | Ambiente | Fragmento | Jefe | NPC | Elementos clave |
|---|---|---|---|---|---|---|
| 1 | Bosque de la Aurora | Naturaleza, agua, árboles, caminos | Verde | Guardián del bosque | Anciano | Caminos entre árboles, puentes, zonas de agua |
| 2 | Ruinas de la Montaña | Piedra, cuevas, cascadas | Azul | Serpiente de piedra | Viajera | Pasadizos estrechos, agua, zonas oscuras |
| 3 | Templo del Eclipse | Templo antiguo, lava, trampas | Violeta | Guardián antiguo | Mercader | Caminos de piedra sobre lava, trampas |

### Cómo se genera un escenario (mixto)
1. Se diseñan a mano entre 6 y 10 **salas** por escenario (claro con enemigos, río con puente, sala de evento, sala de recompensa, sala especial).
2. El algoritmo las **coloca y conecta con pasillos** en cada partida, siempre desde el **inicio hasta el jefe**.
3. La sala de **inicio** (zona segura) y la **arena del jefe** son fijas.
4. La capa 2 de la IA influye en qué salas aparecen y cuántos enemigos tienen.

### Estructura de un escenario
Entrada (zona segura) → salas normales (combate y exploración) → sala de evento (NPC, pista) → sala de recompensa (cofre) → sala especial (mecánica única) → ruta al jefe (dificultad creciente) → arena del jefe → salida al siguiente escenario.

Referencia visual: `docs/referencias/mapas_concepto.png` (concepto, no es arte final).

## 5. Sistema de juego

### Jugador
- Movimiento en 8 direcciones, ataque cuerpo a cuerpo con espada, esquiva (dash) con tiempo de recarga.
- Vida, daño y muerte.
- Habilidad especial de Nico: la **brújula** revela el camino / interactúa con fragmentos (se concreta en la tarea correspondiente).

### Habilidades (fijas, una por jefe)
| Jefe | Fragmento | Habilidad | Efecto |
|---|---|---|---|
| Guardián del bosque | Verde | **Raíces** | Traba a los enemigos en una zona pequeña |
| Serpiente de piedra | Azul | **Corriente** | Empuja y ralentiza a los enemigos |
| Guardián antiguo | Violeta | **Sombra** | Teletransporte corto que dificulta la detección |

Cada habilidad tiene su tecla (`1`, `2`, `3`), tiempo de recarga y sus datos en `data/`. Los nombres y efectos pueden ajustarse sin cambiar el sistema.

**Extra opcional (no se hace por ahora):** combinaciones de habilidades equipadas de a dos.

### Muerte y progreso
Ver "Decisiones de diseño tomadas". Al morir se muestra un resumen del **perfil** que la isla ha aprendido.

## 6. IA adaptativa

El objetivo es que la isla **reaccione al estilo de juego** (sigilo vs. agresión) y que este aprendizaje **se guarde entre partidas**. Dos capas obligatorias:

### Capa 1 — Perfil del jugador
El juego registra eventos mientras se juega:
| Métrica | Ejemplo de evento |
|---|---|
| Ataques cuerpo a cuerpo | Cada golpe de espada |
| Uso de esquiva | Cada dash |
| Uso de habilidades | Cuál y cuántas veces |
| Daño recibido | Cantidad y origen |
| Tiempo por sala | Segundos hasta salir o limpiar |
| Evasión | Salas atravesadas sin combatir |
| Detección | Veces que un enemigo detecta al jugador |

Con estas métricas se calcula un **perfil** con valores entre 0 y 1 (por ejemplo `aggression` y `stealth`), suavizados con una media móvil para que cambien gradualmente. Se clasifica como **agresivo**, **sigiloso** o **equilibrado**. Se guarda en `user://profile.json` (con `"version": 1`) y persiste entre partidas.

### Capa 2 — La isla reacciona
Según el perfil, un "director" ajusta el juego:
| Perfil | Reacción |
|---|---|
| Agresivo | Enemigos con más resistencia, emboscadas, menos espacio para huir, más salas de combate |
| Sigiloso | Enemigos con mayor rango de visión y patrullas, sombras que detectan, más salas con vigilancia |
| Equilibrado | Mezcla de ambos |

Qué se modifica: composición y cantidad de enemigos por sala, parámetros de los enemigos (visión, velocidad, vida), y la selección de salas del generador. El jugador debe **poder notar el cambio** (por ejemplo con el resumen de perfil al morir y diálogos de la isla).

**Extra opcional (no se hace por ahora):** capa 3 con aprendizaje real (bandido multibrazo que aprende qué composiciones de enemigos mantienen el reto adecuado).

## 7. Personajes

### Protagonista
| | |
|---|---|
| **Nico** | Viajero perdido. Determinado, curioso, resistente. Espada corta y brújula rota. Mochila y bufanda roja. Es el personaje con más animaciones (3 vistas + volteo; idle, caminar, ataque, daño, muerte). |

### NPCs (solo diálogo)
| Personaje | Concepto | Personalidad | Función |
|---|---|---|---|
| **El Anciano** | Conoce la isla | Sabio, misterioso, tranquilo. Bastón | Da pistas y explica las reglas de la isla (capítulo 1) |
| **La Viajera** | Perdió la memoria | Enigmática, amable, desconfiada | Aporta información sobre las ruinas y otros viajeros (capítulo 2) |
| **El Mercader** | Comerciante atrapado | Ambicioso, reservado, oportunista | Habla de "precios" y esconde por qué la isla retiene a la gente (capítulo 3) |

Cada NPC tiene 3 estados de diálogo: primer encuentro, información después de avanzar y diálogo final. Animaciones: idle y una de interacción.

### Enemigos (6)
| Enemigo | Escenario | Concepto | Ataque / rasgo | Dificultad |
|---|---|---|---|---|
| Bestia de la niebla | Bosque | Lobo oscuro | Embiste; velocidad, ataque en manada | ⭐⭐ |
| Sombra errante | Bosque / Ruinas | Espíritu encapuchado | Aparece y desaparece (teletransporte) | ⭐⭐ |
| Murciélago | Ruinas | Criatura voladora | Picado rápido, ataque en grupo | ⭐ |
| Gólem menor | Ruinas | Roca animada | Ataque lento y fuerte; resistencia | ⭐⭐ |
| Elemental de fuego | Templo | Criatura de llama | Proyectil corto, zona de fuego | ⭐⭐ |
| Esqueleto guardián | Templo | Guerrero antiguo | Cuerpo a cuerpo con bloqueo | ⭐⭐ |

Cada uno debe tener un **patrón de ataque realmente distinto** al de los demás.

### Jefes (3)
| Jefe | Cap. | Concepto | Ataques | Dificultad |
|---|---|---|---|---|
| Guardián del bosque | 1 | Ser de raíces | Golpes de área, invocación de raíces. Territorial | ⭐⭐⭐ |
| Serpiente de piedra | 2 | Criatura ancestral | Embestida, veneno / proyectiles, se desplaza por zonas | ⭐⭐⭐ |
| Guardián antiguo | 3 | Estatua viviente | Proyectiles y golpes, escudo / invocación | ⭐⭐⭐⭐ |

**Extra opcional:** Guardián de la isla (entidad sobrenatural), jefe final separado o secuencia narrativa.

Referencia visual: `docs/referencias/personajes_concepto.png`.

### Plantilla para nuevas fichas
Nombre · Rol · Concepto visual · Personalidad · Arma / ataque · Habilidad especial · Debilidad · Patrón de movimiento · Animaciones necesarias · Escenario · Función narrativa · Dificultad (⭐ a ⭐⭐⭐⭐⭐).

## 8. Reglas de arte
- Pixel art con formas simples y siluetas reconocibles a tamaño pequeño.
- Personajes en **32x32** (Nico y enemigos pequeños); jefes, enemigos grandes y NPCs pueden ser **64x64**. Una **paleta única** de 16 a 24 colores, tilesets en **16x16**.
- Herramienta: **Pixelorama**. Se guarda el archivo fuente (`.pxo`) junto al PNG exportado.
- Animaciones mínimas de enemigos y Nico: idle, caminar, ataque, daño y muerte. Para NPC: idle e interacción.
- Nico: 3 vistas (frente, espalda, lado) + volteo; enemigos y jefes: un lado + volteo; NPC: frente. (Nico se sigue moviendo en 8 direcciones; solo el arte se reduce a 3 vistas.)
- Los personajes deben contrastar con el escenario donde aparecen.
- Mientras no existan sprites, se usan cuadros de color como provisional.
- Los diseños de las imágenes de referencia son una **guía**, no sprites finales; hay que simplificarlos.

## 9. Diálogos

### Narrativa principal
| Momento | Personaje | Texto |
|---|---|---|
| Pantalla inicial | Nico | "No sé dónde estoy… pero tengo que volver a casa." |
| Prólogo | Narrador | "La tormenta llegó sin aviso. Cuando Nico abrió los ojos, el mar ya no estaba a su alrededor." |
| Primer despertar | Nico | "Mi brújula… está rota. ¿Qué es este lugar?" |
| Primer encuentro | Anciano | "Si buscas el camino de regreso, primero tendrás que aprender a escuchar a la isla." |
| Pista | Anciano | "El bosque guarda algo que te pertenece. Pero no todo lo que protege quiere ser encontrado." |
| Mercader | Mercader | "¿Quieres seguir avanzando? Todo tiene un precio, viajero." |
| Viajera | Viajera | "Sé que he estado aquí antes… pero no recuerdo cómo llegué." |
| Antes del jefe | Nico | "Así que tú eres quien guarda el fragmento…" |
| Jefe | Guardián | "Nadie abandona la isla." |
| Victoria | Nico | "Uno menos. Solo necesito encontrar los otros fragmentos." |
| Muerte | Nico | "No… todavía no. Tengo que volver." |
| Reinicio | Narrador | "La isla vuelve a empezar. Pero Nico recuerda." |
| Último fragmento | Nico | "Ya está… la brújula está completa." |
| Final | Narrador | "El camino de regreso estaba frente a él. Pero ahora Nico sabía que algunas islas no aparecen en ningún mapa." |

### Menú principal
Jugar — "Comenzar viaje" · Continuar — "Retomar el camino" · Opciones — "Configuración" · Salir — "Abandonar la isla".

### Pantallas de carga
- "Cada intento te acerca un poco más a casa."
- "Observa los patrones de los enemigos."
- "La isla cambia, pero tus recuerdos permanecen."

### Inicio de capítulo
- Capítulo 1 — "El bosque despierta."
- Capítulo 2 — "Las ruinas guardan respuestas."
- Capítulo 3 — "El templo conoce tu destino."

### Exploración
"Hay algo extraño en este lugar." · "La brújula reacciona…" · "Este camino parece llevar hacia las ruinas."

### Interacción con NPC
Hablar — "¿Qué sabes sobre esta isla?" · Continuar — "Cuéntame más." · Despedida — "Volveré cuando encuentre el fragmento."

### Combate y jefe
- Combate: "¡Cuidado!" · "¡Eso estuvo cerca!" · "Puedo hacerlo."
- Jefe: "Has llegado hasta aquí…" · "Entonces demuéstrame que mereces volver."

### Derrota y victoria
- Derrota: "La isla te devuelve al comienzo." · "Pero ahora sabes un poco más."
- Victoria: "Fragmento recuperado." · "La brújula vuelve a señalar el camino."
- Final: "Por fin… casa." · "Pero nunca olvidaré la isla."

### Mensajes de interfaz
| Situación | Texto |
|---|---|
| Nuevo objetivo | "Nuevo objetivo: encuentra el fragmento de la brújula." |
| Objeto | "Fragmento de brújula obtenido." |
| Puerta cerrada | "Necesitas algo para abrirla." |
| Cofre | "Has encontrado una mejora." |
| Mapa nuevo | "Un nuevo camino se revela." |
| Jefe derrotado | "El guardián ha caído." |
| Guardado | "Progreso guardado." |
| Fin de partida | "El viaje termina… por ahora." |

> Los diálogos son ejemplos de tono y estructura. Los diálogos propios de cada NPC (3 estados) se redactan en la tarea de historia (ver `docs/TAREAS.md`).

## 10. Riesgos
1. **Carga de arte:** personajes, jefes y animaciones hechos por el equipo. Mitigación: empezar con Nico y probar todo el flujo de Pixelorama a Godot antes de dibujar el resto; usar un pack para tilesets.
2. **IA + generador de mapas** son las piezas más difíciles. Mitigación: versión simple primero, pulido después.
3. **6 enemigos y 3 jefes con patrones distintos.** Mitigación: empezar con 3 enemigos y subir.
4. **Que la IA se note.** Mitigación: resumen de perfil visible al morir y reacciones claras.
5. **Conflictos de Git en escenas de Godot.** Mitigación: reglas de colaboración en `CLAUDE.md`.

## 11. Decisiones abiertas
- Título definitivo (hoy: Isla Espejo).
- Qué pack gratuito se usa para tilesets y sonido.
- Regla exacta de muerte (ver sección 2).
- Si el profesor exige aprendizaje automático (capa 3).

## 12. Referencias
- `docs/referencias/mapas_concepto.png` y `personajes_concepto.png`: conceptos visuales.
- `docs/referencias/concepto_original.docx` y `personajes_dialogos_original.docx`: documentos originales.
