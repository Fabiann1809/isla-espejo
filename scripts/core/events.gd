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

# Enemies
signal enemy_damaged(enemy: Node, amount: int)
signal enemy_killed(enemy: Node)
