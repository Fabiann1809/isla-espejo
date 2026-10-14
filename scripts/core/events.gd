extends Node
## Global event bus (autoload "Events"). Gameplay code emits, other systems listen.
## The adaptive AI and the HUD only read from here, never from combat code directly.

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
