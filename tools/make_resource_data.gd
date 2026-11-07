extends SceneTree
## Writes the basic run resources (data/resources/*.tres): heart, gold and the temporary buffs (arrow fan,
## pierce, frost, haste, shield). Tune drops,
## durations and texts here or in the .tres files.
## Run: godot --headless --path . --script res://tools/make_resource_data.gd


func _initialize() -> void:
	var heart := ResourceData.new()
	heart.id = &"heart"
	heart.display_name = "Corazón"
	heart.kind = ResourceData.Kind.HEAL
	heart.color = Color(0.9, 0.25, 0.3)
	heart.amount = 1
	heart.drop_chance = 0.16
	heart.hurt_chance_multiplier = 2.0
	heart.pity_kills = 12
	heart.max_on_floor = 2
	heart.lifetime = 14.0
	_save(heart)

	var arrows := ResourceData.new()
	arrows.id = &"arrows"
	arrows.display_name = "Lluvia de flechas"
	arrows.message = "¡Tus disparos salen triples!"
	arrows.kind = ResourceData.Kind.ARROWS
	arrows.color = Color(0.35, 0.8, 0.95)
	arrows.duration = 12.0
	arrows.extra_arrows = 2
	arrows.spread_degrees = 14.0
	arrows.drop_chance = 0.04
	arrows.max_on_floor = 1
	arrows.lifetime = 10.0
	_save(arrows)

	var pierce := _buff(&"pierce", "Flechas perforantes", "¡Tus flechas atraviesan enemigos!", Color(0.75, 0.55, 0.95), 12.0)
	pierce.effect = ResourceData.Effect.PIERCE
	pierce.pierce_count = 3
	_save(pierce)

	var frost := _buff(&"frost", "Flechas de escarcha", "¡Tus flechas congelan a quien tocan!", Color(0.55, 0.9, 1.0), 12.0)
	frost.effect = ResourceData.Effect.FROST
	frost.slow_factor = 0.5
	frost.slow_seconds = 2.0
	_save(frost)

	var haste := _buff(&"haste", "Viento veloz", "¡Corres y disparas más rápido!", Color(0.5, 0.95, 0.55), 10.0)
	haste.effect = ResourceData.Effect.HASTE
	haste.speed_bonus = 0.35
	haste.cooldown_cut = 0.4
	_save(haste)

	var shield := _buff(&"shield", "Escudo de eco", "¡Un escudo de eco absorbe los próximos 2 golpes!", Color(0.95, 0.85, 0.4), 20.0)
	shield.effect = ResourceData.Effect.SHIELD
	shield.shield_charges = 2
	shield.shield_invulnerability = 0.6
	_save(shield)

	var gold := ResourceData.new()
	gold.id = &"gold"
	gold.display_name = "Oro"
	gold.kind = ResourceData.Kind.GOLD
	gold.color = Color(1.0, 0.8, 0.25)
	gold.amount = 1
	gold.amount_max = 3
	gold.drop_chance = 0.5
	gold.max_on_floor = 6
	gold.lifetime = 20.0
	gold.magnet_radius = 48.0
	_save(gold)
	quit()


## A rare temporary buff: at most one on the floor, gone after 10 s.
func _buff(id: StringName, display_name: String, message: String, color: Color, duration: float) -> ResourceData:
	var buff := ResourceData.new()
	buff.id = id
	buff.display_name = display_name
	buff.message = message
	buff.kind = ResourceData.Kind.BUFF
	buff.color = color
	buff.duration = duration
	buff.drop_chance = 0.025
	buff.max_on_floor = 1
	buff.lifetime = 10.0
	return buff


func _save(resource: ResourceData) -> void:
	ResourceSaver.save(resource, "res://data/resources/%s.tres" % resource.id)
	print("resource written: ", resource.id)
