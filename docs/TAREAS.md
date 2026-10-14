# Isla Espejo — Tareas

Cada tarea grande tiene su checklist, un criterio **Hecho cuando** y un responsable sugerido.
- **A (sistemas):** combate, habilidades, generador de mapas.
- **B (contenido e IA):** perfil del jugador, director, enemigos, NPCs, arte e interfaz.
- **A+B:** se reparte dentro de la tarea.

Reglas: una tarea a la vez, en orden (salvo las que son independientes), push directo a `main` con el juego funcionando y el chequeo en verde, y marcar `[x]` en este archivo en el mismo commit. Alcance en `docs/JUEGO.md`.

## Estado actual
- **Hecho:** tareas 2 (Nico), 3 (vida, daño y bus de eventos), 5 (habilidades), 6 (generador de mapas), 8 (perfil del jugador, IA capa 1), 9 (la isla reacciona, IA capa 2) y la base de la tarea 4 (clase de enemigo y detección). CI y CD configurados.
- **La IA ya está completa** (capas 1 y 2). Quien haga los enemigos y escenarios solo debe respetar las convenciones de `docs/EMPEZAR.md` (sección 5) para que el director los controle.
- **Persona A, siguiente:** el escenario 1 (tarea 7). Necesita los enemigos y el jefe de la tarea 4 (persona B).
- **Persona B puede empezar ya:** 4 (los 6 enemigos), 13 (interfaz y guardado), 14 (sonido) y el sistema de diálogo de la 12. Las tareas 8 y 9 ya las adelantó la persona A: **no hay que rehacerlas**. Ver `docs/EMPEZAR.md`.

Leyenda de dependencias: `←` indica qué tarea debe estar lista antes.

---

## 1. Base del proyecto y flujo de arte — A+B
- [x] Repo público en GitHub con licencia, `.gitignore`, `.gitattributes`
- [x] Proyecto Godot 4.7 configurado (640x360, escalado entero, filtro nearest, acciones de entrada)
- [x] `CLAUDE.md`, `docs/JUEGO.md`, `docs/TAREAS.md`, `README.md`
- [x] CI de GitHub Actions (`godot-check`) y plantilla de PR
- [x] CI en cada push; `main` sin protección estricta (push directo, como los demás repos)
- [ ] Compañero invitado como colaborador y con Godot 4.7.2 instalado
- [ ] Probar el flujo de arte completo con un cuadro de prueba: dibujar en Pixelorama, exportar PNG, importar a Godot y animar con `AnimatedSprite2D`
- [ ] Definir y guardar la paleta única (16–24 colores) en `assets/palette/`

**Hecho cuando:** ambos pueden clonar el repo, abrir el proyecto, ejecutar F5 y el chequeo local sin errores, y un sprite de prueba hecho en Pixelorama se anima dentro de Godot.

## 2. Nico: movimiento, esquiva y ataque — A  ← 1
- [x] Movimiento en 8 direcciones (base inicial)
- [x] Esquiva (dash) con recarga (base inicial)
- [x] Ataque con espada con hitbox, dirección y tiempo de recarga
- [x] Estados del jugador (idle, mover, esquivar, atacar, dañado, muerto) con máquina de estados simple
- [x] Invulnerabilidad breve durante la esquiva
- [x] Valores ajustables desde el inspector (`@export`)
- [x] Cámara que sigue a Nico con suavizado y límites por escenario

**Hecho cuando:** Nico se mueve, esquiva y ataca con fluidez en una sala de prueba y la cámara lo sigue sin saltos.

## 3. Vida, daño y muerte — A  ← 2
- [x] Componente reutilizable de vida (`HealthComponent`) para jugador y enemigos
- [x] Hitbox / hurtbox con capas de colisión definidas y documentadas
- [x] Daño, retroceso (knockback) y parpadeo al recibir daño
- [x] Muerte del jugador con señal `player_died`
- [x] HUD básico: barra de vida
- [x] Bus de eventos (autoload) para que otros sistemas escuchen lo que pasa (la IA lo usará)

**Hecho cuando:** jugador y enemigos de prueba se hacen daño y mueren, y los eventos de combate se emiten por el bus.

## 4. Enemigos base — B  ← 3
- [x] Clase base de enemigo con vida, daño, estados (idle, patrulla, persecución, ataque, muerte) y datos en `data/enemies/` (`scripts/enemies/enemy.gd`, plantilla `scenes/enemies/grunt.tscn`)
- [x] Detección del jugador (rango de visión, cono, línea de visión y señal `player_detected`)
- [ ] **Bestia de la niebla** (embiste)
- [ ] **Sombra errante** (teletransporte)
- [ ] **Murciélago** (picado rápido)
- [ ] **Gólem menor** (ataque lento y fuerte)
- [ ] **Elemental de fuego** (proyectil y zona de fuego)
- [ ] **Esqueleto guardián** (cuerpo a cuerpo con bloqueo)
- [ ] Cada enemigo con patrón de ataque distinto y sprite provisional
- [ ] Animaciones de cada enemigo (idle, caminar, ataque, daño, muerte)

**Hecho cuando:** los 6 enemigos funcionan en una sala de prueba con comportamiento claramente distinto entre sí. *(Puede entregarse en tandas de 2–3 enemigos.)*

## 5. Sistema de habilidades (3 fijas, modular) — A  ← 3
- [x] Recurso `SkillData` en `data/skills/` (nombre, recarga, daño, alcance, efecto)
- [x] Gestor de habilidades del jugador (desbloqueo, recarga, teclas `1`, `2`, `3`)
- [x] **Raíces**: traba enemigos en una zona
- [x] **Corriente**: empuja y ralentiza
- [x] **Sombra**: teletransporte corto y menor detección
- [x] HUD de habilidades con indicador de recarga
- [x] Cada habilidad emite eventos al bus (la IA los usa)
- [x] Diseñar el sistema para que añadir una habilidad nueva sea solo agregar datos y un efecto

**Hecho cuando:** las 3 habilidades se pueden usar desde una sala de prueba, cada una con efecto visible y recarga, y se desbloquean por código.

## 6. Generador de salas y mapas — A  ← 2
- [x] Definir el formato de sala (tamaño, puertas/salidas, tipo, enemigos posibles) en `data/rooms/`
- [x] Crear 3 salas de prueba a mano
- [x] Algoritmo que coloca salas y las conecta con pasillos desde el inicio hasta el jefe
- [x] Sala de inicio y arena del jefe fijas
- [x] Semilla (seed) para reproducir y depurar un mapa
- [x] Verificación: todas las salas son alcanzables y no se superponen
- [x] Carga de salas y transición entre ellas con la cámara siguiendo a Nico
- [x] Parámetros por escenario (número de salas, tipos permitidos)

**Hecho cuando:** cada ejecución genera un escenario distinto, siempre completable de inicio a jefe, y se puede reproducir con la misma semilla.

## 7. Escenario 1: Bosque de la Aurora — A+B  ← 4, 5, 6
- [x] Tileset del bosque (pack gratuito, con créditos) y `TileSet` configurado (Kenney Roguelike/RPG, CC0)
- [x] 6–10 salas del bosque (claros, río con puente, cofre, evento): 10 salas en `scenes/levels/rooms/forest/`
- [ ] Enemigos del bosque colocados en las salas (hoy usa el soldado de plantilla como relleno; cambiar el `enemy_pool` de `data/scenarios/forest.tres` por la Bestia de la niebla y la Sombra errante cuando existan)
- [ ] **Jefe: Guardián del bosque** (golpes de área, invocación de raíces)
- [ ] Al derrotarlo: fragmento verde y habilidad **Raíces**
- [ ] NPC **Anciano** con 3 estados de diálogo
- [ ] Cofres y recompensas básicas
- [ ] Salida al escenario 2

**Hecho cuando:** se puede jugar el escenario 1 de principio a fin (inicio, salas, Anciano, jefe, fragmento) y cada partida genera un recorrido distinto.

## 8. Perfil del jugador (IA capa 1) — B (adelantada por A)  ← 3, 5
- [x] Autoload `PlayerProfile` que escucha los eventos del bus de combate
- [x] Registrar métricas: ataques cuerpo a cuerpo, esquivas, uso de habilidades, daño recibido, tiempo por sala, salas evadidas, detecciones
- [x] Calcular `aggression` y `stealth` (0–1) con media móvil
- [x] Clasificar el perfil: agresivo, sigiloso o equilibrado
- [x] Guardar y cargar `user://profile.json` con `"version": 1`
- [x] Pruebas con perfiles simulados (valores de ejemplo) para validar la clasificación
- [x] Pantalla de resumen de perfil al morir

**Hecho cuando:** tras jugar, el perfil refleja el estilo (probado con una partida agresiva y otra sigilosa), se guarda y se recupera al reiniciar el juego.

## 9. La isla reacciona (IA capa 2) — B (adelantada por A)  ← 6, 8
- [x] Director (`scripts/ai/`) que lee el perfil y produce ajustes
- [x] Ajustar composición y cantidad de enemigos por sala según el perfil
- [x] Ajustar parámetros de enemigos (visión, velocidad, vida) según el perfil
- [x] Influir en la selección de salas del generador
- [x] Reacciones visibles para el jugador (diálogo de la isla, resumen al morir)
- [x] Tabla de reglas en `data/ai/` para ajustar sin tocar código
- [x] Registro de depuración que muestre qué decidió el director y por qué

**Hecho cuando:** jugando de forma agresiva y luego sigilosa se ven diferencias claras en las salas y enemigos, y el cambio se puede explicar con el registro de depuración.

## 10. Escenario 2: Ruinas de la Montaña — A+B  ← 7
- [ ] Tileset de ruinas y cuevas
- [ ] Salas del escenario (pasadizos, agua, zonas oscuras)
- [ ] Enemigos del escenario colocados
- [ ] **Jefe: Serpiente de piedra** (embestida, veneno / proyectiles)
- [ ] Al derrotarlo: fragmento azul y habilidad **Corriente**
- [ ] NPC **Viajera** con 3 estados de diálogo
- [ ] Transición desde el escenario 1 y hacia el 3

**Hecho cuando:** el escenario 2 es completable de inicio a jefe con la IA funcionando.

## 11. Escenario 3: Templo del Eclipse — A+B  ← 10
- [ ] Tileset del templo y lava (caminos de piedra sobre lava, sin plataformas flotantes)
- [ ] Salas con trampas
- [ ] Enemigos del escenario colocados
- [ ] **Jefe: Guardián antiguo** (proyectiles, golpes, escudo / invocación)
- [ ] Al derrotarlo: fragmento violeta y habilidad **Sombra**
- [ ] NPC **Mercader** con 3 estados de diálogo (solo diálogo, sin tienda)
- [ ] Cierre de la historia

**Hecho cuando:** el escenario 3 es completable y se obtiene el último fragmento.

## 12. Diálogos, historia y final — B  ← 7
- [ ] Sistema de diálogo (caja de texto, avance, retratos opcionales) leyendo de `data/dialogues/`
- [ ] Redactar los 3 estados de diálogo de Anciano, Viajera y Mercader
- [ ] Prólogo y textos de inicio de capítulo
- [ ] Diálogos de jefes (antes y después)
- [ ] Textos de muerte y reinicio ("La isla vuelve a empezar…")
- [ ] Final: brújula completa y regreso a casa
- [ ] Mensajes de interfaz (objetivo, objeto, puerta cerrada, cofre, guardado)
- [ ] Revisar ortografía y coherencia con la historia

**Hecho cuando:** la historia se puede seguir de principio a fin con todos los textos en `data/` y ninguno escrito en los scripts.

## 13. Interfaz, menús, guardado y créditos — B  ← 3
- [ ] Menú principal ("Comenzar viaje", "Retomar el camino", "Configuración", "Abandonar la isla")
- [ ] HUD completo (vida, habilidades, objetivo, fragmentos)
- [ ] Menú de pausa
- [ ] Pantalla de muerte con resumen del perfil
- [ ] Guardado y carga de progreso (fragmentos, habilidades, escenario) junto al perfil
- [ ] Opciones básicas (volumen, pantalla completa)
- [ ] Pantalla de créditos alimentada desde `CREDITS.md`

**Hecho cuando:** se puede iniciar, pausar, morir, continuar y salir del juego sin errores, y el progreso se conserva al cerrarlo.

## 14. Sonido y música — B  ← 3
- [ ] Elegir packs gratuitos de música y efectos y registrarlos en `CREDITS.md`
- [ ] Música por escenario, menú y jefe
- [ ] Efectos: golpes, esquiva, habilidades, daño, muerte, UI, pasos
- [ ] Bus de audio y control de volumen

**Hecho cuando:** cada acción principal tiene su sonido y cada escenario su música, con créditos completos.

## 15. Pulido, balance y entrega — A+B  ← 11, 12, 13
- [ ] Balance de vida, daño y dificultad de enemigos y jefes
- [ ] Jugar completo varias veces con estilos distintos y ajustar la IA
- [ ] Corregir errores y revisar la consola de Godot sin errores ni avisos importantes
- [ ] Rendimiento estable en un equipo normal
- [x] Preset de exportación para Windows y build jugable (`export_presets.cfg` y `.github/workflows/release.yml`, probado)
- [ ] Publicar la build como *release* en GitHub
- [ ] Capturas, GIFs y vídeo corto para el portafolio
- [ ] Revisar `CREDITS.md` y el `README.md` finales
- [ ] Decidir el título definitivo

**Hecho cuando:** existe un ejecutable jugable de principio a fin, una release publicada y el material para el portafolio.

---

## Extras opcionales (solo si todo lo anterior está completo y se pide)
- [ ] Combinaciones de habilidades equipadas de a dos
- [ ] IA capa 3: bandido multibrazo para elegir composiciones de enemigos
- [ ] Cuarto escenario
- [ ] Guardián de la isla como jefe final separado
- [ ] Mini-jefe adicional
- [ ] Tienda del Mercader

## Punto de control
Cuando las tareas 1 a 7 estén listas, **el escenario 1 debe poder jugarse completo**. Si no es así, se recorta contenido del escenario 3, **no** la IA.
