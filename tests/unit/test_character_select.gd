extends GutTest
## The character and weapon select: six 3:4 profile cards, a tab per street game, weapon cards
## (art | name, description below), and the kid you pick is the kid you play.

const PRACTICE_SCENE: PackedScene = preload("res://scenes/match/practice.tscn")
const RULES: GameRules = preload("res://data/rules/game_rules.tres")

var _saved_avatar: String


func before_each() -> void:
	_saved_avatar = Session.avatar_id


func after_each() -> void:
	Session.avatar_id = _saved_avatar
	Session.save()


func _picking() -> PracticeMatch:
	var practice: PracticeMatch = autofree(PRACTICE_SCENE.instantiate()) as PracticeMatch
	add_child(practice)
	return practice


func _screen(practice: PracticeMatch) -> WeaponPickScreen:
	return practice.get_node("%PickScreen") as WeaponPickScreen


func test_row_one_is_six_profile_cards_in_3_by_4() -> void:
	var screen: WeaponPickScreen = _screen(_picking())
	var cards: Array[Node] = screen.find_children("Profile_*", "Button", true, false)
	assert_eq(cards.size(), 6)
	for card: Node in cards:
		var size: Vector2 = (card as Button).custom_minimum_size
		assert_almost_eq(size.x / size.y, 3.0 / 4.0, 0.001, "%s is 3:4" % card.name)
	var tops: Dictionary = {}
	for card: Node in cards:
		tops[snappedf((card as Button).global_position.y, 1.0)] = true
	assert_eq(tops.size(), 1, "all six are in one row")


func test_row_two_has_a_tab_per_street_game_and_one_page_shows() -> void:
	var screen: WeaponPickScreen = _screen(_picking())
	var tabs: Array[Node] = screen.find_children("Tab_*", "Button", true, false)
	var games: Array[String] = []
	for def: WeaponDef in RULES.weapons:
		if not games.has(def.street_game):
			games.append(def.street_game)
	assert_eq(tabs.size(), games.size())
	assert_true(games.has("Bato-bato-pik") and games.has("Tumbang preso"))
	var shown: int = 0
	for page: Node in screen.find_children("Page_*", "VBoxContainer", true, false):
		if (page as Control).visible:
			shown += 1
	assert_eq(shown, 1, "only the open tab's weapons show")
	screen.open_tab("Tumbang preso")
	assert_eq(screen.current_tab(), "Tumbang preso")
	assert_true((screen.find_child("Weapon_lata", true, false) as Control).is_visible_in_tree())
	assert_false((screen.find_child("Weapon_bato_light", true, false) as Control).is_visible_in_tree())


func test_a_weapon_card_has_art_then_the_name_with_its_description_below() -> void:
	var screen: WeaponPickScreen = _screen(_picking())
	var card: Button = screen.find_child("Weapon_lata", true, false) as Button
	var art: TextureRect = card.find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_not_null(art.texture, "painted art")
	var description: Label = card.find_child("Description", true, false) as Label
	assert_false(description.text.is_empty(), "a description")
	var name_label: Label = card.find_children("*", "Label", true, false)[0] as Label
	assert_eq(name_label.text, (load("res://data/weapons/lata.tres") as WeaponDef).display_name)
	await wait_frames(2)
	assert_lt(art.global_position.x, name_label.global_position.x, "the art is on the left")
	assert_gt(description.global_position.y, name_label.global_position.y, "the description is below the name")


func test_every_weapon_has_a_description() -> void:
	for def: WeaponDef in RULES.weapons:
		assert_false(def.description.is_empty(), "%s has a description" % def.id)


func test_your_last_kid_is_selected_first_and_tapping_changes_it() -> void:
	Session.avatar_id = "popoy"
	var practice: PracticeMatch = _picking()
	var screen: WeaponPickScreen = _screen(practice)
	assert_eq(screen.character_id, &"popoy")
	assert_true((screen.find_child("Profile_popoy", true, false) as Button).button_pressed)
	screen.pick_character(&"ligaya")
	assert_eq(screen.character_id, &"ligaya")
	assert_true((screen.find_child("Profile_ligaya", true, false) as Button).button_pressed)
	assert_false((screen.find_child("Profile_popoy", true, false) as Button).button_pressed)


func test_the_kid_you_pick_is_the_kid_you_play_and_your_main_screen_face() -> void:
	Session.avatar_id = "junjun"
	var practice: PracticeMatch = _picking()
	var screen: WeaponPickScreen = _screen(practice)
	screen.pick_character(&"inday")
	screen.tap(&"bato_light")
	screen.tap(&"lata")
	screen.press_ready()
	assert_eq(practice.sim.players[PracticeMatch.LOCAL_ID].character_id, &"inday")
	assert_eq(Session.avatar_id, "inday", "the main screen shows the kid you picked")
	var view: KidModel = practice._views[PracticeMatch.LOCAL_ID] as KidModel
	assert_eq(view.character.id, &"inday", "the 3D kid is rebuilt as the picked one")


func test_nobody_shares_your_kid() -> void:
	var practice: PracticeMatch = _picking()
	var screen: WeaponPickScreen = _screen(practice)
	screen.pick_character(&"toni")
	screen.tap(&"bato_light")
	screen.tap(&"lata")
	screen.press_ready()
	var seen: Dictionary = {}
	for id: int in practice.sim.players:
		var kid: StringName = practice.sim.players[id].character_id
		assert_false(seen.has(kid), "%s is only played once" % kid)
		seen[kid] = true
		var view: KidModel = practice._views[id] as KidModel
		assert_eq(view.character.id, kid, "every 3D kid matches its player")


func test_set_character_swaps_with_the_holder_and_refuses_unknown_kids() -> void:
	var sim: MatchSim = MatchSim.new(RULES, load("res://data/rules/map_layout.tres") as MapLayout, 1)
	sim.add_player(1, 0)
	sim.add_player(2, 1)
	sim.players[1].character_id = &"junjun"
	sim.players[2].character_id = &"toni"
	assert_true(sim.set_character(1, &"toni"))
	assert_eq(sim.players[1].character_id, &"toni")
	assert_eq(sim.players[2].character_id, &"junjun", "the holder gets the old kid")
	assert_false(sim.set_character(1, &"nobody"))
	assert_false(sim.set_character(9, &"toni"))
	assert_eq(sim.players[1].character_id, &"toni")


func test_the_respawn_swap_screen_only_changes_weapons() -> void:
	var practice: PracticeMatch = _picking()
	var screen: WeaponPickScreen = _screen(practice)
	screen.tap(&"bato_light")
	screen.tap(&"lata")
	screen.press_ready()
	practice.skip_intro()
	practice.open_swap()
	assert_true(screen.swap_mode)
	assert_false((screen.find_child("Characters", true, false) as Control).visible, "a kid is fixed for the match")
	var before: StringName = screen.character_id
	screen.pick_character(&"ligaya")
	assert_eq(screen.character_id, before, "no kid change in the box")
