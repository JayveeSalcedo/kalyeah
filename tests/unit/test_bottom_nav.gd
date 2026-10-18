extends GutTest
## The main screen's bottom nav bar and the pages behind its tabs.

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")

var _saved_avatar: String
var _saved_history: String


func before_each() -> void:
	_saved_avatar = Session.avatar_id
	_saved_history = MatchHistory.path
	MatchHistory.path = "user://history_test.cfg"
	MatchHistory.clear()


func after_each() -> void:
	MatchHistory.clear()
	MatchHistory.path = _saved_history
	Session.avatar_id = _saved_avatar
	Session.save()


func _phone_screen() -> TitleScreen:
	var phone: Control = autofree(Control.new()) as Control
	phone.custom_minimum_size = Vector2(720.0, 1280.0)
	phone.size = Vector2(720.0, 1280.0)
	add_child(phone)
	var screen: TitleScreen = autofree(TITLE_SCENE.instantiate()) as TitleScreen
	phone.add_child(screen)
	return screen


func test_the_bar_has_the_five_tabs_in_order_with_battle_open() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	var texts: Array[String] = []
	for tab: Dictionary in BottomNav.TABS:
		texts.append(String(tab["label"]))
	assert_eq(texts, ["Characters", "Weapons", "Battle", "History", "Menu"])
	assert_eq(screen.nav.current, &"battle")
	assert_true(screen.pages[&"battle"].visible)
	for id: StringName in [&"characters", &"weapons", &"history", &"menu"]:
		assert_false(screen.pages[id].visible, "%s is closed" % id)


func test_the_bar_is_a_flat_gray_strip_edge_to_edge_with_no_margin() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	var bar: Rect2 = screen.nav.get_global_rect()
	assert_almost_eq(bar.position.x, 0.0, 0.5, "no margin on the left")
	assert_almost_eq(bar.end.x, 720.0, 0.5, "or the right")
	assert_almost_eq(bar.end.y, 1280.0, 0.5, "or the bottom")
	var style: StyleBoxFlat = screen.nav.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.corner_radius_top_left, 0, "not a rounded card")
	assert_eq(style.shadow_size, 0, "no card shadow")
	var cement: ColorRect = screen.nav.find_child("Cement", true, false) as ColorRect
	assert_true(cement.material is ShaderMaterial, "light gray cement from a shader")
	assert_almost_eq(cement.color.r, cement.color.g, 0.03, "gray, not tinted")
	assert_between(cement.color.v, 0.55, 0.8, "slightly light")
	for tab: Dictionary in BottomNav.TABS:
		var button: Button = screen.nav.buttons[tab["id"]]
		assert_gte(button.get_global_rect().size.y, 88.0, "%s is tall enough for a thumb" % tab["label"])
		assert_almost_eq(button.get_global_rect().size.x, 144.0, 2.0, "five equal tabs")
	assert_lt(screen.carousel.get_global_rect().end.y, bar.position.y, "the battle page ends above the bar")


func test_tabs_are_icons_and_only_the_open_one_shows_its_name() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	for tab: Dictionary in BottomNav.TABS:
		var id: StringName = tab["id"]
		var button: Button = screen.nav.buttons[id]
		assert_eq(button.text, "", "no text on the button itself: an icon and a caption")
		assert_not_null(button.find_child("*", true, false))
		var label: Label = screen.nav._labels[id]
		assert_eq(label.modulate.a, 1.0 if id == &"battle" else 0.0, "%s caption" % id)
		assert_eq(screen.nav._icons[id].color, BottomNav.LIT if id == &"battle" else BottomNav.IDLE)
	screen.nav.select(&"history")
	assert_eq(screen.nav._labels[&"history"].modulate.a, 1.0)
	assert_eq(screen.nav._labels[&"battle"].modulate.a, 0.0, "the old tab loses its name")


func test_tapping_a_tab_shows_only_its_page() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(2)
	for tab: Dictionary in BottomNav.TABS:
		var id: StringName = tab["id"]
		screen.nav.buttons[id].pressed.emit()
		for other: StringName in screen.pages:
			assert_eq(screen.pages[other].visible, other == id, "%s page while %s is open" % [other, id])
	screen.nav.buttons[&"battle"].pressed.emit()
	assert_true(screen.pages[&"battle"].visible)


func test_the_characters_page_picks_your_face() -> void:
	var screen: TitleScreen = _phone_screen()
	screen.nav.select(&"characters")
	await wait_frames(2)
	var page: CharactersPage = screen.characters_page
	assert_eq(page.cards.size(), Session.AVATARS.size())
	page.cards["toni"].pressed.emit()
	assert_eq(Session.avatar_id, "toni")
	page.cards["popoy"].pressed.emit()
	assert_eq(Session.avatar_id, "popoy")


func test_the_weapons_page_lists_every_weapon_with_its_text() -> void:
	var screen: TitleScreen = _phone_screen()
	screen.nav.select(&"weapons")
	await wait_frames(2)
	var rules: GameRules = load("res://data/rules/game_rules.tres") as GameRules
	var page: WeaponsPage = screen.weapons_page
	assert_eq(page.rows.size(), rules.weapons.size())
	for i: int in rules.weapons.size():
		assert_eq((page.rows[i].find_child("Name", true, false) as Label).text, rules.weapons[i].display_name.to_upper())
		assert_eq((page.rows[i].find_child("About", true, false) as Label).text, rules.weapons[i].description)


func test_history_starts_empty_and_lists_battles_newest_first() -> void:
	var screen: TitleScreen = _phone_screen()
	screen.nav.select(&"history")
	await wait_frames(2)
	assert_not_null(screen.history_page.find_child("Empty", true, false), "nothing played yet")
	MatchHistory.record("practice", true, 2, 1)
	MatchHistory.record("hotspot", false, 0, 2)
	screen.history_page.refresh()
	await wait_frames(2)
	var results: Array[String] = []
	for label: Node in screen.history_page.find_children("Result", "Label", true, false):
		if not label.is_queued_for_deletion():
			results.append((label as Label).text)
	assert_eq(results, ["DEFEAT", "VICTORY"], "the newest battle is first")


func test_the_history_keeps_the_last_thirty_and_words_the_age() -> void:
	for i: int in MatchHistory.MAX_ENTRIES + 5:
		MatchHistory.record("online", i % 2 == 0, i, 0)
	var found: Array[Dictionary] = MatchHistory.entries()
	assert_eq(found.size(), MatchHistory.MAX_ENTRIES)
	assert_eq(int(found[0]["mine"]), MatchHistory.MAX_ENTRIES + 4, "newest first")
	assert_eq(MatchHistory.ago(100, 130), "just now")
	assert_eq(MatchHistory.ago(0, 300), "5 min ago")
	assert_eq(MatchHistory.ago(0, 7300), "2 h ago")
	assert_eq(MatchHistory.ago(0, 200000), "2 days ago")


func test_the_menu_page_has_profile_settings_and_quit() -> void:
	var screen: TitleScreen = _phone_screen()
	screen.nav.select(&"menu")
	await wait_frames(2)
	screen.menu_page.settings_button.pressed.emit()
	assert_not_null(screen.dialog, "settings opened")
	screen.menu_page.quit_button.pressed.emit()
	assert_not_null(screen.dialog.find_child("*", true, false))


func test_winning_a_battle_is_written_to_the_history() -> void:
	var practice: PracticeMatch = autofree((load("res://scenes/match/practice.tscn") as PackedScene).instantiate()) as PracticeMatch
	add_child(practice)
	practice.finish_pick()
	practice.skip_intro()
	practice.sim.match_won.emit(practice.local_team)
	var found: Array[Dictionary] = MatchHistory.entries()
	assert_eq(found.size(), 1)
	assert_true(bool(found[0]["won"]))
	assert_eq(found[0]["mode"], "practice")
