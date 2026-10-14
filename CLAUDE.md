# Isla Espejo — project rules

Top-down pixel-art roguelike made in **Godot 4.7 (GDScript)** by two developers. Working title: "Isla Espejo" (may change).
Game design: `docs/JUEGO.md` and task list: `docs/TAREAS.md` (both written in Spanish). **Read both before starting any task.**
Visual references: `docs/referencias/` (concept images only; they are NOT game sprites).

## Core idea (do not lose sight of it)
Nico is stuck on an island that mirrors and learns from him. He crosses 3 scenarios, defeats 3 bosses (each gives a compass fragment and a skill) and goes home. Three pillars:
1. **Every run is different**: procedural maps built from hand-made rooms.
2. **Fixed skills, one per boss** (no combos for now, but keep the system data-driven so combos can be added later).
3. **The island learns**: adaptive AI in two layers — player profile (layer 1) and island reaction (layer 2). Both are mandatory.

## Workflow
1. Work on **one task at a time**, in the order of `docs/TAREAS.md`, and only on tasks assigned to you (A or B) unless told otherwise. Do not add anything that is not in the docs.
2. A task is done only when:
   - the project opens and runs with no errors in the Godot console,
   - `godot --headless --path . --script res://tests/run_checks.gd` exits with code 0,
   - its "Hecho cuando" criterion is verified,
   - a short explanation of what was done and why is given to the user (in Spanish).
3. If anything is ambiguous or touches the scope, **ask the user** before assuming. Never expand the scope: anything marked as out of scope or as an extra in the docs is not built unless the user says so.
4. Never break what already works. If a change could affect another system, run the project and check that system before committing.

## Git and collaboration
5. `main` is protected: **no direct pushes**. Work in a branch `feature/<short-name>` (or `fix/<short-name>`) and open a pull request. CI (`godot-check`) must pass before merging.
6. One commit per task or fix. Tick the task checkbox (`[x]`) in `docs/TAREAS.md` in the same commit/PR.
7. Commit format: [Conventional Commits](https://www.conventionalcommits.org/) in English: `type(scope): imperative summary`.
   - Types: `feat`, `fix`, `refactor`, `test`, `docs`, `build`, `chore`, `style`.
   - Scopes: `player`, `combat`, `skills`, `enemies`, `bosses`, `world`, `ai`, `npc`, `dialogue`, `ui`, `audio`, `art`, `save`, `ci`.
   - Summary ≤ 72 chars, imperative, no trailing period. Example: `feat(player): add dash with cooldown`.
8. Each person commits with **their own name and email**. **Never** add `Co-Authored-By` trailers or any AI/tool attribution to commits, PRs or files.
9. Avoid merge conflicts in Godot: do not edit a `.tscn` scene that another person is changing in their branch. Shared files (`project.godot`, autoloads, `data/`) are changed in small PRs, announced first. Prefer many small scenes over one big scene.
10. Never commit: `.godot/`, builds, secrets, personal files, or huge unused assets. Never force-push to shared branches.

## Code
11. Everything in **English** (identifiers, comments, commits, filenames) **except player-facing text** (dialogues, UI, item names), which is **Spanish** and lives in `data/` files, never hardcoded in scripts.
12. GDScript style: `snake_case` for files, variables and functions; `PascalCase` for classes and nodes; static typing everywhere possible (`var hp: int = 10`); small functions; comment only the non-obvious "why".
13. Structure: one scene per entity and one script per scene.
    - `scenes/` (player, enemies, bosses, npcs, levels, ui), `scripts/` (same subfolders plus `skills/`, `ai/`, `world/`), `assets/` (`sprites/`, `tilesets/`, `audio/`), `data/` (JSON/Resources), `tests/`.
14. Game data is data, not code: skills, enemies, rooms and dialogues are defined in `data/` (JSON or Godot Resources) and read by generic systems. Adding a new enemy or skill must not require changing the core systems.
15. The adaptive AI lives in `scripts/ai/` and is separated from combat code. Combat code only **emits events** (e.g. "player dashed", "player hit enemy", "enemy detected player"); the AI listens. Use signals or a small event bus autoload.
16. The player profile is saved to `user://profile.json`. Keep the format versioned (`"version": 1`).
17. Resolution is 640x360 with integer scaling and *nearest* filtering. Do not change display settings without asking.
18. Use the input actions defined in `project.godot` (`move_*`, `dash`, `attack`, `skill_1..3`, `interact`). Never hardcode keys.
19. Placeholders: until real sprites exist, use `ColorRect`/simple shapes. Never block a task waiting for art.

## Art and assets
20. Characters are made by the team in **Pixelorama**: 32x32 sprites, one shared palette of 16–24 colors, minimum animations idle / walk / attack / hurt / die (8 directions for Nico and bosses, 4 for the rest).
21. Tilesets are 16x16 (a free pack may be used; record it in `CREDITS.md`). Every third-party asset must be listed in `CREDITS.md` **in the same commit** that adds it, with its license.
22. Keep source art (`.pxo`) next to exported PNGs under `assets/sprites/<name>/`.

## Safety
23. No API keys, tokens or personal data in code, docs, logs or commits.
24. The repository is public: do not publish anything that is not meant to be public.
