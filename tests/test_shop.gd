extends SceneTree
## The Mercader's shop: the catalog data, buying (gold spent, each kind applied), refusals, upgrades that
## last the journey (new map, save, death), old saves, the merchant opening it and the menu pausing.
## Run: godot --headless --path . --script res://tests/test_shop.gd

var _ok := true
var _state: Node
var _events: Node
var _shop: GDScript
var _result: Dictionary


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_state = root.get_node("GameState")
	_events = root.get_node("Events")
	_shop = load("res://scripts/world/shop.gd")
	_result = _shop.Result
	_state.reset()

	var catalog: Resource = load("res://data/shop/items.tres")
	_test_catalog(catalog)
	_test_placement()
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)
	var player = room.get_node("Player")
	_test_buying(catalog, player)
	_test_refusals(catalog, player)
	await _test_new_map_and_death(catalog, player, room)
	_test_saves(catalog, player)
	await _test_menu_and_merchant(catalog, player)

	_state.reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _test_catalog(catalog: Resource) -> void:
	_check(catalog != null and catalog.items.size() == 5, "the catalog loads its five items")
	var ids: Array = catalog.items.map(func(item: Resource) -> StringName: return item.id)
	_check(ids == [&"potion", &"elixir", &"taut_string", &"hawk_eye", &"stone_heart"], "items in the shop order")
	var complete := true
	for item in catalog.items:
		complete = complete and item.display_name != "" and item.description != "" and item.price > 0 and item.icon_path != ""
	_check(complete, "every item has a Spanish name and description, a price and an icon path in data")
	_check(catalog.find(&"hawk_eye").upgrade_id == &"crit_chance" and catalog.find(&"hawk_eye").max_level == 3
			and catalog.find(&"stone_heart").max_level == 2, "upgrade ids and maximum levels come from the data")
	_check(catalog.find(&"taut_string").price_at(0) == 12 and catalog.find(&"taut_string").price_at(1) == 18,
			"an upgrade's price rises 50% of its base per level")
	_check(catalog.find(&"potion").icon() == null or catalog.find(&"potion").icon() is Texture2D,
			"a missing icon is just null (the menu draws a colored square)")


func _test_placement() -> void:
	var merchant: PackedScene = load("res://scenes/npcs/merchant.tscn")
	var temple: Resource = load("res://data/scenarios/temple.tres")
	var forest: Resource = load("res://data/scenarios/forest.tres")
	_check(temple.start_npc_scene == merchant and temple.special_npc_scene == merchant and temple.npc_scene == null,
			"the temple's start and special rooms use merchant.tscn; its event room stays empty")
	_check(forest.special_npc_scene == merchant, "the forest's special room uses the same merchant.tscn")
	var start: Resource = load("res://scenes/levels/rooms/temple/start.tscn")
	var names: Array = []
	var state: SceneState = start.get_state()
	for i in state.get_node_count():
		names.append(state.get_node_name(i))
	_check(names.has(&"NpcSpawn"), "the temple's start room has its NpcSpawn marker")


func _test_buying(catalog: Resource, player: Node) -> void:
	var gold_events: Array[int] = []
	_events.player_gold_changed.connect(func(total: int) -> void: gold_events.append(total))
	player.add_gold(100)
	_check(player.gold == 100, "the test player has gold")
	player.health.take_damage(3)
	var before: int = player.health.current
	var bought: Array = []
	var denied: Array = []
	var events: Node = root.get_node("Events")
	events.shop_bought.connect(func(id: StringName) -> void: bought.append(id))
	events.shop_denied.connect(func(reason: StringName) -> void: denied.append(reason))
	_check(_shop.buy(catalog.find(&"potion"), player) == _result.BOUGHT, "a potion is bought")
	_check(bought == [&"potion"], "buying announces the item on Events.shop_bought (for its sound) (%s)" % [bought])
	_check(player.gold == 96 and player.health.current == before + 1, "it cost 4 gold and healed 1 heart")
	_check(gold_events.back() == 96, "Events.player_gold_changed announces the new total")
	_check(_shop.buy(catalog.find(&"elixir"), player) == _result.BOUGHT, "an elixir is bought")
	_check(player.gold == 86 and player.health.current == player.health.max_health, "it cost 10 gold and healed everything")
	var denied_before := denied.size()
	_check(_shop.buy(catalog.find(&"potion"), player) == _result.FULL_HEALTH and player.gold == 86,
			"healing at full health is refused and costs nothing")

	var max_before: int = player.health.max_health
	_check(denied.size() == denied_before + 1 and denied.back() == &"full_health",
			"a refused purchase is announced on Events.shop_denied (%s)" % [denied])
	_check(_shop.buy(catalog.find(&"taut_string"), player) == _result.BOUGHT, "the bow upgrade is bought")
	_check(_state.upgrade_level(&"bow_damage") == 1 and player.bonus_damage == 1 and player.arrow_damage() == player.attack_damage + 1,
			"+1 arrow damage per level, written in GameState")
	_check(_shop.buy(catalog.find(&"hawk_eye"), player) == _result.BOUGHT, "the crit upgrade is bought")
	_check(_state.upgrade_level(&"crit_chance") == 1 and is_equal_approx(player.crit_bonus, 0.05)
			and is_equal_approx(player.total_crit_chance(), player.crit_chance + 0.05), "+5% crit chance per level")
	_check(_shop.buy(catalog.find(&"stone_heart"), player) == _result.BOUGHT, "the heart upgrade is bought")
	_check(player.health.max_health == max_before + 1 and player.health.current == player.health.max_health,
			"+1 maximum heart, and it comes full")
	_check(player.gold == 86 - 12 - 10 - 18, "the upgrades cost 12 + 10 + 18 gold")


func _test_refusals(catalog: Resource, player: Node) -> void:
	player.add_gold(-player.gold)
	var level: int = _state.upgrade_level(&"bow_damage")
	_check(_shop.buy(catalog.find(&"taut_string"), player) == _result.NO_GOLD, "with no gold an upgrade is refused")
	_check(_state.upgrade_level(&"bow_damage") == level and player.gold == 0, "a refusal changes nothing")
	player.health.take_damage(1)
	_check(_shop.buy(catalog.find(&"potion"), player) == _result.NO_GOLD, "with too little gold a potion is refused")
	player.add_gold(3)
	_check(_shop.buy(catalog.find(&"potion"), player) == _result.NO_GOLD and player.gold == 3, "3 gold is not enough for 4")

	player.add_gold(500)
	_check(_shop.buy(catalog.find(&"taut_string"), player) == _result.BOUGHT, "bow level 2")
	_check(_shop.buy(catalog.find(&"taut_string"), player) == _result.BOUGHT, "bow level 3")
	var gold: int = player.gold
	_check(_shop.is_maxed(catalog.find(&"taut_string")), "the bow upgrade is at its maximum")
	_check(_shop.buy(catalog.find(&"taut_string"), player) == _result.MAXED, "a maxed upgrade is refused")
	_check(player.gold == gold and _state.upgrade_level(&"bow_damage") == 3, "no gold is spent at the maximum")
	_shop.buy(catalog.find(&"stone_heart"), player)
	_check(_shop.buy(catalog.find(&"stone_heart"), player) == _result.MAXED and player.health.max_health == 7,
			"hearts stop at +2")


func _test_new_map_and_death(catalog: Resource, player: Node, room: Node) -> void:
	# A new map re-applies GameState to the same player: nothing is added twice.
	var max_health: int = player.health.max_health
	_state.apply_to_player(player)
	_state.apply_to_player(player)
	_check(player.health.max_health == max_health and player.bonus_damage == 3, "applying twice adds nothing twice")
	# A new player (the next journey after dying with the save kept, or a resumed save) gets them all.
	var fresh: Node = load("res://scenes/player/player.tscn").instantiate()
	room.add_child(fresh)
	await _frames(2)
	_check(fresh.bonus_damage == 0 and fresh.health.max_health < max_health, "a new player starts without upgrades")
	_state.apply_to_player(fresh)
	_check(fresh.bonus_damage == 3 and fresh.health.max_health == max_health - 0 and is_equal_approx(fresh.crit_bonus, 0.05),
			"apply_to_player gives the new player every upgrade")
	fresh.queue_free()
	# Dying wipes them with the rest of GameState.
	_state.reset()
	_check(_state.upgrades.is_empty() and _state.upgrade_level(&"bow_damage") == 0, "GameState.reset wipes the upgrades")
	var after: Node = load("res://scenes/player/player.tscn").instantiate()
	room.add_child(after)
	await _frames(2)
	_state.apply_to_player(after)
	_check(after.bonus_damage == 0 and is_zero_approx(after.crit_bonus) and after.health.max_health == 5,
			"after dying a new player has none")
	after.queue_free()
	_state.reset()


func _test_saves(catalog: Resource, player: Node) -> void:
	_state.add_upgrade(&"bow_damage")
	_state.add_upgrade(&"bow_damage")
	_state.add_upgrade(&"max_health")
	var json: Variant = JSON.parse_string(JSON.stringify(_state.to_dict()))
	_state.reset()
	_check(_state.from_dict(json), "a save with upgrades loads")
	_check(_state.upgrade_level(&"bow_damage") == 2 and _state.upgrade_level(&"max_health") == 1
			and _state.upgrade_level(&"crit_chance") == 0, "its upgrade levels come back as integers")
	_state.reset()
	var old_save := {"version": 1, "fragments": ["green"], "skills": [], "flags": ["met_merchant"]}
	_check(_state.from_dict(old_save), "an old save without upgrades loads")
	_check(_state.upgrades.is_empty() and _state.has_fragment(&"green") and _state.has_flag(&"met_merchant"),
			"it comes with no upgrades and the rest intact")
	_check(_state.from_dict({"version": 1, "upgrades": "broken"}) and _state.upgrades.is_empty(), "a broken upgrades field is ignored")
	_state.reset()


func _test_menu_and_merchant(catalog: Resource, player: Node) -> void:
	_state.reset()
	player.add_gold(-player.gold)
	player.add_gold(30)
	var menu: Node = load("res://scripts/ui/shop_menu.gd").new()
	root.add_child(menu)
	await _frames(2)
	_check(not menu.is_open() and not paused, "the shop starts closed")
	menu.open(player)
	await _frames(2)
	_check(menu.is_open() and paused, "opening the shop pauses the game")
	_check(menu.item_buttons.size() == 5 and menu.gold_label.text == "Oro: 30", "it lists the five items and the gold")
	_check(menu.get_viewport().gui_get_focus_owner() == menu.item_buttons[0], "the first item has the focus (keyboard and pad)")
	var panel: Control = menu._panel
	_check(panel.get_rect().size.x <= 480.0 and panel.get_rect().size.y <= 270.0,
			"the panel fits the 480x270 screen (%s)" % panel.get_rect().size)
	menu.item_buttons[2].pressed.emit()
	_check(player.gold == 18 and menu.gold_label.text == "Oro: 18" and menu.message_label.text == "Comprado: Cuerda tensa",
			"pressing an item buys it and shows the confirmation")
	menu.item_buttons[4].pressed.emit()
	_check(menu.message_label.text == "No te alcanza el oro." or player.gold == 0, "a short purse gets a message")
	player.add_gold(-player.gold)
	menu.item_buttons[3].pressed.emit()
	_check(menu.message_label.text == "No te alcanza el oro.", "refusal for lack of gold shows its message")
	# Esc closes it.
	var key := InputEventAction.new()
	key.action = &"pause"
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	_check(not menu.is_open() and not paused, "Esc (pause) closes the shop and the game goes on")
	menu.open(player)
	await _frames(1)
	menu.close_button.pressed.emit()
	_check(not menu.is_open() and not paused, "the close button closes it and unpauses")
	menu.queue_free()

	# The merchant: his conversation ends, then the shop opens.
	var merchant: Node = load("res://scenes/npcs/merchant.tscn").instantiate()
	root.add_child(merchant)
	await _frames(2)
	_check(merchant.opens_shop and merchant.get_node("Talk").prompt != "", "the Mercader is a merchant with an E prompt")
	var dialogue: Node = root.get_node("Dialogue")
	merchant.get_node("Talk").interact(player)
	_check(dialogue.active and not paused, "talking to him starts his dialogue first, with no shop yet")
	_events.dialogue_finished.emit(&"elder", &"first")
	_check(not paused, "another character's dialogue does not open his shop")
	dialogue._finish()
	await _frames(2)
	var opened: Array = get_nodes_in_group("shop_menu").filter(func(m: Node) -> bool: return m.is_open())
	_check(opened.size() == 1 and paused, "when his dialogue ends the shop opens and pauses")
	opened[0].close()
	merchant.queue_free()
	await _frames(2)
	_check(not paused, "the game is running again")
