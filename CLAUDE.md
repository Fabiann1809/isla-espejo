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
   - `godot --headless --path . --script res://tests/run_checks.gd` and every `tests/test_*.gd` exit with code 0 (add a `tests/test_<system>.gd` for each new gameplay system; in tests never `preload` scenes or reference `class_name` types of scripts that use autoloads: load at runtime and use untyped variables),
   - its "Hecho cuando" criterion is verified,
   - a short explanation of what was done and why is given to the user (in Spanish).
3. If anything is ambiguous or touches the scope, **ask the user** before assuming. Never expand the scope: anything marked as out of scope or as an extra in the docs is not built unless the user says so.
4. Never break what already works. If a change could affect another system, run the project and check that system before committing.

## Git and collaboration
5. Work directly on `main` and push to it (no pull requests needed). Before every push: `git pull --rebase`, run the project, and run `godot --headless --path . --script res://tests/run_checks.gd` and the `tests/test_*.gd` files (all must exit 0). Never push something that does not open or breaks what already worked. CI (`godot-check`) runs on every push; if it fails, fix it first.
   - Optional: use a short-lived branch `feature/<short-name>` for a big or risky change, then merge it into `main`.
6. One commit per task or fix. Tick the task checkbox (`[x]`) in `docs/TAREAS.md` in the same commit.
7. Commit format: [Conventional Commits](https://www.conventionalcommits.org/) in English: `type(scope): imperative summary`.
   - Types: `feat`, `fix`, `refactor`, `test`, `docs`, `build`, `chore`, `style`.
   - Scopes: `player`, `combat`, `skills`, `enemies`, `bosses`, `world`, `ai`, `npc`, `dialogue`, `ui`, `audio`, `art`, `save`, `ci`.
   - Summary ≤ 72 chars, imperative, no trailing period. Example: `feat(player): add dash with cooldown`.
8. Each person commits with **their own name and email**. **Never** add `Co-Authored-By` trailers or any AI/tool attribution to commits, PRs or files.
9. Avoid merge conflicts in Godot: do not edit a `.tscn` scene that the other person is currently working on, and `git pull --rebase` often. Shared files (`project.godot`, autoloads, `data/`) are changed in small commits, announced first. Prefer many small scenes over one big scene.
10. Releases: pushing a tag `v*` publishes a public GitHub Release (CD). Never create or push tags unless the user explicitly asks. Never commit: `.godot/`, builds, secrets, personal files, or huge unused assets. Never force-push to shared branches.

## Code
11. Everything in **English** (identifiers, comments, commits, filenames) **except player-facing text** (dialogues, UI, item names), which is **Spanish** and lives in `data/` files, never hardcoded in scripts.
12. GDScript style: `snake_case` for files, variables and functions; `PascalCase` for classes and nodes; static typing everywhere possible (`var hp: int = 10`); small functions; comment only the non-obvious "why".
13. Structure: one scene per entity and one script per scene.
    - `scenes/` (player, enemies, bosses, npcs, levels, ui), `scripts/` (same subfolders plus `skills/`, `ai/`, `world/`), `assets/` (`sprites/`, `tilesets/`, `audio/`), `data/` (JSON/Resources), `tests/`.
14. Game data is data, not code: skills, enemies, rooms and dialogues are defined in `data/` (JSON or Godot Resources) and read by generic systems. Adding a new enemy or skill must not require changing the core systems.
15. The adaptive AI lives in `scripts/ai/` and is separated from combat code. Combat code only **emits events** (e.g. "player dashed", "player hit enemy", "enemy detected player"); the AI listens. Use signals or a small event bus autoload.
16. The player profile is saved to `user://profile.json`. Keep the format versioned (`"version": 1`).
17. Resolution is 640x360 with integer scaling and *nearest* filtering. Do not change display settings without asking.
18. Combat uses the reusable components in `scripts/components/`: `HealthComponent` (health), `Hitbox` (deals damage, once per activation) and `Hurtbox` (receives damage). Never write ad-hoc damage code; a new enemy or trap reuses them.
    - Hitboxes and hurtboxes are `Area2D` nodes. Keep `monitorable = true` on them (turning it off makes the area blind).
    - Collision layers (named in `project.godot`): 1 `world`, 2 `player` (body + Hurtbox), 3 `enemy` (body + Hurtbox), 4 `player_attack`, 5 `enemy_attack`. Player Hitbox: layer 4, mask 3. Enemy/trap Hitbox: layer 5, mask 2.
    - Bodies only collide with `world` (and the player body also with `enemy`); damage is decided only by Hitbox vs Hurtbox.
    - Combat code publishes what happens on the `Events` autoload (`scripts/core/events.gd`); the AI and HUD listen there. Add a signal there when a new gameplay fact must be observable.
    - **Enemies**: inherit `scenes/enemies/enemy.tscn` (see `grunt.tscn`), create an `EnemyData` `.tres` in `data/enemies/` and set it as `data`. Only override the `_process_*` / `_start_attack` hooks of `scripts/enemies/enemy.gd` (in a script extending `Enemy`) when the behaviour differs. Never copy `enemy.gd`. The AI director tunes enemies through the `*_multiplier` properties before adding them to the tree.
19. Use the input actions defined in `project.godot` (`move_*`, `dash`, `attack`, `skill_1..3`, `interact`). Never hardcode keys.
20. Placeholders: until real sprites exist, use `ColorRect`/simple shapes. Never block a task waiting for art.

## Art and assets
21. Characters are made by the team in **Pixelorama**: 32x32 sprites, one shared palette of 16–24 colors, minimum animations idle / walk / attack / hurt / die (8 directions for Nico and bosses, 4 for the rest).
22. Tilesets are 16x16 (a free pack may be used; record it in `CREDITS.md`). Every third-party asset must be listed in `CREDITS.md` **in the same commit** that adds it, with its license.
23. Keep source art (`.pxo`) next to exported PNGs under `assets/sprites/<name>/`.

## Safety
24. No API keys, tokens or personal data in code, docs, logs or commits.
25. The repository is public: do not publish anything that is not meant to be public.
