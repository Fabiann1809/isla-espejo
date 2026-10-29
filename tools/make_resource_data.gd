extends SceneTree
## Writes the basic run resources (data/resources/*.tres): heart, arrow orb and gold. Tune drops,
## durations and texts here or in the .tres files.
## Run: godot --headless --path . --script res://tools/make_resource_data.gd


func _initialize() -> void:
	var heart := ResourceData.new()
	heart.id = &"heart"
	heart.display_name = "Corazón"
	heart.kind = ResourceData.Kind.HEAL
	heart.color = Color(0.9, 0.25, 0.3)
	heart.amount = 1
	heart.drop_chance = 0.12
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
	arrows.drop_chance = 0.06
	arrows.max_on_floor = 1
	arrows.lifetime = 10.0
	_save(arrows)

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


func _save(resource: ResourceData) -> void:
	ResourceSaver.save(resource, "res://data/resources/%s.tres" % resource.id)
	print("resource written: ", resource.id)
