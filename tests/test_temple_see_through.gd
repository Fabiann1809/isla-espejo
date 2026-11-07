extends SceneTree
## The temple's tall structures turn see-through while Nico walks behind them, as the forest's trees do
## (CanopyFade): a pillar fades when Nico stands above its foot inside what it draws, and comes back when
## he walks in front of it; a low prop (a plant) never joins.
## Run: godot --headless --path . --script res://tests/test_temple_see_through.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var world := Node2D.new()
	root.add_child(world)
	var fade: Node = load("res://scripts/effects/canopy_fade.gd").new()
	world.add_child(fade)
	var prop_script: Script = load("res://scripts/world/temple_prop.gd")
	var pillar: Node2D = prop_script.new()
	pillar.kind = prop_script.Kind.PILLAR_CARVED
	pillar.position = Vector2(200, 200)
	world.add_child(pillar)
	var plant: Node2D = prop_script.new()
	plant.kind = prop_script.Kind.PLANT
	plant.position = Vector2(400, 200)
	world.add_child(plant)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	await _frames(2)

	_check(pillar.is_in_group(&"canopy"), "a carved pillar joins the see-through group")
	_check(not plant.is_in_group(&"canopy"), "a low plant does not")
	var rect: Rect2 = fade.rect_of(pillar)
	_check(rect.size.y > 64.0, "the pillar's drawn rectangle covers its full height (%.0f px)" % rect.size.y)

	# Behind: above the pillar's foot, inside what it draws.
	player.global_position = pillar.global_position + Vector2(0, -24)
	await _frames(40)
	_check(pillar.modulate.a < 0.99, "Nico behind a pillar makes it see-through (alpha %.2f)" % pillar.modulate.a)

	# In front: below its foot, it is solid again.
	player.global_position = pillar.global_position + Vector2(0, 30)
	await _frames(80)
	_check(is_equal_approx(pillar.modulate.a, 1.0), "in front of it, the pillar is solid again (alpha %.2f)" % pillar.modulate.a)

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
