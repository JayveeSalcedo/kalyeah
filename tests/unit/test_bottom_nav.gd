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
	assert_eq(texts, ["Characters", "Weapons", "Battle", "History", "Settings"])
	assert_eq(screen.nav.current, &"battle")
	assert_true(screen.pages[&"battle"].visible)
	for id: StringName in [&"characters", &"weapons", &"history", &"settings"]:
		assert_false(screen.pages[id].visible, "%s is closed" % id)


func test_the_bar_is_flat_dark_blue_cement_edge_to_edge_with_no_margin_and_no_top_line() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	var bar: Rect2 = screen.nav.get_global_rect()
	assert_almost_eq(bar.position.x, 0.0, 0.5, "no margin on the left")
	assert_almost_eq(bar.end.x, 720.0, 0.5, "or the right")
	assert_almost_eq(bar.end.y, 1280.0, 0.5, "or the bottom")
	assert_almost_eq(bar.size.y, BottomNav.HEIGHT, 0.5, "the bar keeps its height")
	assert_true(screen.nav.get_theme_stylebox("panel") is StyleBoxEmpty, "no card, border or top line")
	var stone: ColorRect = screen.nav.find_child("Stone", true, false) as ColorRect
	assert_true(stone.material is ShaderMaterial, "dark blue cement from a shader")
	assert_gt(stone.color.b, stone.color.r * 2.0, "blue")
	assert_lt(stone.color.v, 0.5, "dark")
	assert_eq((stone.material as ShaderMaterial).get_shader_parameter("rect_size"), stone.size, "the cement is sized to the bar")
	for tab: Dictionary in BottomNav.TABS:
		var button: Button = screen.nav.buttons[tab["id"]]
		assert_gte(button.get_global_rect().size.y, 88.0, "%s is tall enough for a thumb" % tab["label"])
		assert_almost_eq(button.get_global_rect().size.x, (720.0 - 2.0 * TitleScreen.SIDE_MARGIN) / 5.0, 2.0, "five equal tabs inside the side margins")


func test_the_tabs_respect_the_side_margins_with_a_partition_closing_each_end() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	var first: Rect2 = screen.nav.buttons[&"characters"].get_global_rect()
	var last: Rect2 = screen.nav.buttons[&"settings"].get_global_rect()
	assert_almost_eq(first.position.x, TitleScreen.SIDE_MARGIN, 1.0, "the strip starts at the left margin")
	assert_almost_eq(last.end.x, 720.0 - TitleScreen.SIDE_MARGIN, 1.0, "and ends at the right margin")
	var stone: ColorRect = screen.nav.find_child("Stone", true, false) as ColorRect
	var inner: Vector2 = (stone.material as ShaderMaterial).get_shader_parameter("inner") as Vector2
	assert_almost_eq(inner.x, TitleScreen.SIDE_MARGIN, 1.0, "the partition lines are drawn there")
	assert_almost_eq(inner.y, 720.0 - TitleScreen.SIDE_MARGIN, 1.0)
	assert_almost_eq(screen.nav.get_global_rect().size.x, 720.0, 0.5, "the bar itself still runs edge to edge")


func test_tabs_are_icons_and_only_the_open_one_is_big_named_and_past_the_bar() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	var bar: Rect2 = screen.nav.get_global_rect()
	for tab: Dictionary in BottomNav.TABS:
		var id: StringName = tab["id"]
		var button: Button = screen.nav.buttons[id]
		var icon: NavIcon = screen.nav._icons[id]
		assert_eq(button.text, "", "no text on the button itself: an icon and a caption")
		var lit: bool = id == &"battle"
		assert_eq(screen.nav._labels[id].visible, lit, "%s name" % id)
		assert_eq(icon.color, BottomNav.LIT if lit else BottomNav.IDLE)
		if lit:
			assert_almost_eq(icon.scale.x, BottomNav.LIT_SCALE, 0.01, "bigger")
			assert_lt(icon.get_global_rect().position.y, bar.position.y, "it goes past the bar's top edge")
		else:
			assert_eq(icon.scale.x, 1.0)
			assert_gte(icon.get_global_rect().position.y, bar.position.y, "inside the bar")
	screen.nav.select(&"history")
	await wait_seconds(0.4)
	assert_true(screen.nav._labels[&"history"].visible)
	assert_false(screen.nav._labels[&"battle"].visible, "the old tab loses its name")
	assert_almost_eq(screen.nav._icons[&"history"].scale.x, BottomNav.LIT_SCALE, 0.01)
	assert_almost_eq(screen.nav._icons[&"battle"].scale.x, 1.0, 0.01, "and shrinks back")
	assert_eq(screen.nav.get_global_rect().size.y, BottomNav.HEIGHT, "the bar never changes height")


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


func test_the_settings_page_has_profile_sound_server_and_quit() -> void:
	var screen: TitleScreen = _phone_screen()
	screen.nav.select(&"settings")
	await wait_frames(2)
	var page: SettingsPage = screen.settings_page
	assert_true(page.visible)
	assert_not_null(page.find_child("VolumeSlider", true, false), "sound")
	assert_not_null(page.find_child("ServerField", true, false), "the online server")
	assert_not_null(page.profile_button, "profile")
	var saved: String = Settings.server_url
	page.server_field.text = "wss://example.test"
	page.save_server()
	assert_eq(Settings.server_url, "wss://example.test", "the server is remembered")
	Settings.save_server_url(saved)
	page.quit_button.pressed.emit()
	assert_not_null(screen.dialog, "quit asks first")


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
