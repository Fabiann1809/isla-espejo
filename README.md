# Isla Espejo

> Título provisional. Roguelike de exploración en pixel art, vista superior, hecho con **Godot 4.7**.

Nico queda atrapado en una isla que lo refleja y aprende de él. Para volver a casa debe cruzar tres escenarios, derrotar a sus guardianes y reunir los fragmentos de su brújula.

**Tres ideas centrales**
- Cada partida es distinta: mapas procedurales armados con salas diseñadas a mano.
- Una habilidad por jefe: cada fragmento de la brújula otorga un poder.
- La isla aprende: una IA adaptativa observa cómo juegas (agresivo o sigiloso) y reacciona.

## Documentación
- [`docs/JUEGO.md`](docs/JUEGO.md): de qué trata el juego, alcance, personajes, historia y diálogos.
- [`docs/TAREAS.md`](docs/TAREAS.md): lista de tareas con checklist.
- [`CLAUDE.md`](CLAUDE.md): reglas de trabajo del proyecto (para el equipo y para Claude Code).
- [`CREDITS.md`](CREDITS.md): créditos de recursos de terceros.

## Cómo ejecutarlo
1. Instala [Godot 4.7.2](https://godotengine.org/download) (versión estándar, no .NET).
2. Abre el proyecto con `project.godot`.
3. Pulsa **F5**.

Controles provisionales: `WASD` mover, `Espacio` esquivar, `J` atacar, `1 2 3` habilidades, `E` interactuar.

## Verificación local
```
godot --headless --path . --script res://tests/run_checks.gd
```
Debe terminar con código 0. Es la misma comprobación que ejecuta CI en cada pull request.

## Equipo
Proyecto de portafolio desarrollado por dos personas en unos 2 meses.

## Licencia
Código bajo licencia MIT (ver [`LICENSE`](LICENSE)). Los recursos de terceros conservan su propia licencia (ver [`CREDITS.md`](CREDITS.md)).
