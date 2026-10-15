extends Node
## Global event bus (autoload "Events"). Gameplay code emits, other systems listen.
## The adaptive AI and the HUD only read from here, never from combat code directly.

# Story and interaction
signal dialogue_started(dialogue_id: StringName)
signal dialogue_finished(dialogue_id: StringName, state: StringName)
## Text of the nearest interactable object (empty when there is none), for the HUD.
signal interaction_prompt_changed(prompt: String)
## A line to show the player (rewards, chapter titles...).
signal message_requested(text: String)
signal chest_opened(chest: Node)
## Boss health, so the HUD can show its bar. Emitted when the fight starts and on every hit.
signal boss_health_changed(boss_id: StringName, current: int, maximum: int, boss_name: String)
signal boss_defeated(boss_id: StringName)
signal fragment_collected(fragment_id: StringName)
signal scenario_completed(scenario_id: StringName)
## What the player should do now (Spanish, from the scenario's data), for the HUD.
signal objective_changed(text: String)

# Run flow
## A map has been built and the player placed in it: a new run starts.
signal level_started(scenario_id: StringName, map_seed: int)

# Player
signal player_attacked(direction: Vector2)
signal player_dashed(direction: Vector2)
signal player_hit_enemy(enemy: Node, damage: int)
signal player_damaged(amount: int, source_position: Vector2)
signal player_health_changed(current: int, maximum: int)
signal player_died
## Sombra and similar: true when the player becomes harder to detect, false when it ends.
signal player_stealth_changed(active: bool)

# Skills
signal skill_unlocked(skill_id: StringName)
## `affected` = how many enemies the skill touched (the AI uses it to read the play style).
signal skill_used(skill_id: StringName, direction: Vector2, affected: int)

# Enemies
signal enemy_damaged(enemy: Node, amount: int)
signal enemy_killed(enemy: Node)
## An enemy noticed the player (once per detection, not every frame).
signal enemy_detected_player(enemy: Node)

# Map rooms (emitted by Room). `room` is the Room node; read room.data for its RoomData.
signal room_entered(room: Node)
signal room_exited(room: Node)
## Every enemy of the room is dead.
signal room_cleared(room: Node)
