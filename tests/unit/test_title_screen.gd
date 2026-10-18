extends GutTest
## The main screen: profile, map model, Practice / Hotspot / Online / Quit (2x2), Settings and the dialogs.

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")

var _saved_name: String
var _saved_avatar: String
var _saved_volume: float
var _saved_url: String
var _saved_hotspot: String
var _saved_vibration: bool


func before_each() -> void:
	_saved_name = Session.player_name
	_saved_avatar = Session.avatar_id
	_saved_volume = Settings.volume
	_saved_url = Settings.server_url
	_saved_hotspot = Settings.hotspot_url
	_saved_vibration = Settings.vibration


func after_each() -> void:
	Session.player_name = _saved_name
	Session.avatar_id = _saved_avatar
	Session.save()
	Settings.set_volume(_saved_volume)
	Settings.set_vibration(_saved_vibration)
	Settings.save_server_url(_saved_url)
	Settings.save_hotspot_url(_saved_hotspot)
	Session.lobby_hotspot = false


func _screen() -> TitleScreen:
	var screen: TitleScreen = autofree(TITLE_SCENE.instantiate()) as TitleScreen
	add_child(screen)
	return screen


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)


func test_a_normal_run_is_not_the_server() -> void:
	assert_false(TitleScreen.is_server_run(), "tests run without --server or the dedicated_server feature")


func test_server_scene_and_lobby_scene_exist() -> void:
	assert_true(ResourceLoader.exists(TitleScreen.SERVER_SCENE))
	assert_true(ResourceLoader.exists(TitleScreen.LOBBY_SCENE))
	assert_true(ResourceLoader.exists(TitleScreen.PRACTICE_SCENE))
	assert_true(ResourceLoader.exists(TitleScreen.PRESO_SCENE))
	assert_true(ResourceLoader.exists(TitleScreen.PATINTERO_SCENE))


func test_practice_asks_which_street_game_to_play() -> void:
	var screen: TitleScreen = _screen()
	screen.practice_button.pressed.emit()
	assert_not_null(screen.dialog)
	assert_eq(screen.dialog.title_label.text, "PRACTICE")
	var base: Button = _find(screen.dialog, "AgawanBaseButton") as Button
	var preso: Button = _find(screen.dialog, "TumbangPresoButton") as Button
	assert_not_null(base)
	assert_not_null(preso)
	assert_eq(preso.text, "TUMBANG PRESO")
	var patintero: Button = _find(screen.dialog, "PatinteroButton") as Button
	assert_not_null(patintero)
	assert_eq(patintero.text, "PATINTERO")
	assert_gte(preso.custom_minimum_size.y, 88.0, "big enough for a thumb")


func test_the_screen_has_everything_the_owner_asked_for() -> void:
	var screen: TitleScreen = _screen()
	assert_not_null(screen.profile_button, "username")
	assert_not_null(screen.settings_button, "settings")
	assert_not_null(screen.diorama, "the map model")
	assert_eq(screen.practice_button.text, "PRACTICE")
	assert_eq(screen.hotspot_button.text, "HOTSPOT")
	assert_eq(screen.online_button.text, "ONLINE")
	assert_eq(screen.quit_button.text, "QUIT")


func test_the_four_buttons_are_a_2x2_grid_at_the_bottom() -> void:
	var phone: Control = autofree(Control.new()) as Control
	phone.custom_minimum_size = Vector2(720.0, 1280.0)
	phone.size = Vector2(720.0, 1280.0)
	add_child(phone)
	var screen: TitleScreen = autofree(TITLE_SCENE.instantiate()) as TitleScreen
	phone.add_child(screen)
	await wait_frames(3)
	var p: Rect2 = screen.practice_button.get_global_rect()
	var h: Rect2 = screen.hotspot_button.get_global_rect()
	var o: Rect2 = screen.online_button.get_global_rect()
	var q: Rect2 = screen.quit_button.get_global_rect()
	assert_almost_eq(p.position.y, h.position.y, 1.0, "practice and hotspot share the top row")
	assert_almost_eq(o.position.y, q.position.y, 1.0, "online and quit share the bottom row")
	assert_almost_eq(p.position.x, o.position.x, 1.0, "practice sits over online")
	assert_almost_eq(h.position.x, q.position.x, 1.0, "hotspot sits over quit")
	assert_lt(p.position.x, h.position.x)
	assert_lt(p.end.y, o.position.y)
	assert_gt(p.size.x, 200.0)
	assert_lt(q.end.y, 1280.0)
	assert_gt(o.position.y, 1280.0 * 0.6, "in the bottom part")
	assert_gt(screen.diorama.get_global_rect().end.y, 0.0)
	assert_lte(screen.diorama.get_global_rect().end.y, p.position.y + 1.0, "the map model is above the buttons")


func test_the_screen_shows_no_version_online_caption_or_server_line() -> void:
	var screen: TitleScreen = _screen()
	var text: String = _all_text(screen)
	assert_false(text.contains("ONLINE  "), "no ONLINE caption")
	assert_false(text.contains("Server"), "no server line")
	assert_false(text.contains("No server"), "no server hint")
	assert_eq(text.count("v0."), 0, "no version")
	assert_null(screen.find_child("VersionLabel", true, false))


func _all_text(root: Node) -> String:
	var text: String = ""
	for label: Node in root.find_children("*", "Label", true, false):
		text += (label as Label).text + " "
	return text


func test_the_background_is_the_owners_diamond_picture_covering_the_screen() -> void:
	var screen: TitleScreen = _screen()
	var background: TextureRect = _find(screen, "Background") as TextureRect
	assert_eq(background.texture, TitleScreen.BACKGROUND)
	assert_eq(background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "cropped, never stretched")
	assert_eq(TitleScreen.BACKGROUND.get_size(), Vector2(941.0, 1672.0))


func test_every_tap_target_is_big_enough_for_a_thumb() -> void:
	var screen: TitleScreen = _screen()
	# 720 px design width is about 390 dp on a phone: 88 px is about 48 dp
	for button: Button in [screen.practice_button, screen.hotspot_button, screen.online_button, screen.quit_button, screen.settings_button, screen.profile_button]:
		assert_gte(button.custom_minimum_size.y, 88.0, "%s is tall enough" % button.name)
	assert_gte(screen.settings_button.custom_minimum_size.x, 88.0)


func test_a_new_player_gets_a_name_and_a_face() -> void:
	Session.player_name = ""
	Session.avatar_id = ""
	Session.ensure_profile()
	assert_false(Session.player_name.is_empty())
	assert_lte(Session.player_name.length(), Session.MAX_NAME_LENGTH)
	assert_true(Session.AVATARS.has(Session.avatar_id))
	var name_now: String = Session.player_name
	Session.ensure_profile()
	assert_eq(Session.player_name, name_now, "an existing profile is kept")


func test_the_profile_shows_your_name_and_your_character_face() -> void:
	Session.player_name = "Juan"
	Session.avatar_id = "toni"
	var screen: TitleScreen = _screen()
	var name_label: Label = screen.profile_button.find_children("*", "Label", true, false)[0] as Label
	assert_eq(name_label.text, "Juan")
	for kid: String in Session.AVATARS:
		assert_not_null(KidModel.minimap_face(StringName(kid)), "%s has a face for the avatar" % kid)


func test_renaming_saves_a_clean_name_and_refuses_an_empty_one() -> void:
	var screen: TitleScreen = _screen()
	var card: MenuDialog = screen.open_name_editor()
	var field: LineEdit = _find(card, "NameField") as LineEdit
	assert_eq(field.max_length, Session.MAX_NAME_LENGTH)
	field.text = "   "
	field.text_submitted.emit(field.text)
	assert_true(card.is_open, "an empty name is refused and the card stays open")
	field.text = "  Maria  "
	field.text_submitted.emit(field.text)
	assert_eq(Session.player_name, "Maria")
	assert_false(card.is_open)
	assert_eq(Session.clean_name("A very long name indeed"), "A very long", "cut to 12 letters, no trailing space")


func test_cancelling_the_rename_keeps_the_old_name() -> void:
	Session.player_name = "Pedro"
	var screen: TitleScreen = _screen()
	var card: MenuDialog = screen.open_name_editor()
	(_find(card, "NameField") as LineEdit).text = "Changed"
	card.close(false)
	assert_eq(Session.player_name, "Pedro")


func test_settings_change_the_volume_and_remember_the_server() -> void:
	var screen: TitleScreen = _screen()
	var card: MenuDialog = screen.open_settings()
	var slider: HSlider = _find(card, "VolumeSlider") as HSlider
	slider.value = 0.4
	assert_almost_eq(Settings.volume, 0.4, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(0), linear_to_db(0.4), 0.01, "the master volume follows")
	(_find(card, "ServerField") as LineEdit).text = "wss://example.org"
	card.close(false)
	assert_eq(Settings.server_url, "wss://example.org")
	slider.value = 0.0
	assert_true(AudioServer.is_bus_mute(0), "zero is silent")


func test_vibration_is_only_offered_on_phones() -> void:
	var screen: TitleScreen = _screen()
	var card: MenuDialog = screen.open_settings()
	assert_eq(_find(card, "VibrationToggle") != null, Settings.can_vibrate())
	assert_false(Settings.can_vibrate(), "tests do not run on a phone")


func test_quit_asks_first_and_only_quits_on_yes() -> void:
	var screen: TitleScreen = _screen()
	var quit_calls: Array[int] = [0]
	screen.quit_action = func() -> void: quit_calls[0] += 1
	var card: MenuDialog = screen.open_quit_confirm()
	assert_eq(quit_calls[0], 0, "opening the question does not quit")
	var buttons: Array[Node] = card.find_children("*", "Button", true, false)
	var stay: Button = buttons[0] as Button
	var leave: Button = buttons[1] as Button
	assert_eq(stay.text, "STAY")
	assert_eq(leave.text, "QUIT")
	stay.pressed.emit()
	assert_eq(quit_calls[0], 0, "STAY keeps playing")
	assert_false(card.is_open)
	var again: MenuDialog = screen.open_quit_confirm()
	(again.find_children("*", "Button", true, false)[1] as Button).pressed.emit()
	assert_eq(quit_calls[0], 1, "QUIT quits")


func test_only_one_dialog_is_open_at_a_time() -> void:
	var screen: TitleScreen = _screen()
	var first: MenuDialog = screen.open_settings()
	var second: MenuDialog = screen.open_quit_confirm()
	assert_false(first.is_open)
	assert_true(second.is_open)
	assert_eq(screen.dialog, second)


func test_safe_insets_are_never_negative_or_huge() -> void:
	var screen: TitleScreen = _screen()
	var inset: Vector4 = screen.safe_insets()
	for value: float in [inset.x, inset.y, inset.z, inset.w]:
		assert_between(value, 0.0, 120.0)


func test_the_map_model_is_the_play_area_alone_and_fits_its_frame() -> void:
	var screen: TitleScreen = _screen()
	var model: MenuDiorama = screen.diorama
	model.size = Vector2(690.0, 480.0)
	await wait_frames(2)
	var layout: MapLayout = model.map.layout
	assert_true(model.map.diorama)
	assert_eq(layout.lane_length, (load("res://data/rules/map_layout.tres") as MapLayout).lane_length, "the real play area")
	# the cement and its stone base in the game's exact shape, plus the corner props only
	assert_eq(model.map._posts.size(), 2, "an electric post at each base")
	var street: AABB = (model.map.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb()
	assert_almost_eq(street.size.x / street.size.z, layout.lane_width / layout.lane_length, 0.001, "the game's 1:1 ratio")
	assert_almost_eq(street.size.x, layout.lane_width, 0.01, "no sidewalks")
	assert_almost_eq(street.size.z, layout.lane_length, 0.01, "no extra space at the ends")
	var props: Array[Node] = model.map.find_children("*", "MeshInstance3D", true, false)
	assert_eq(props.size(), 1 + 2 + 2 * model.map.jail_wall_rects(layout.jail_rect(MapLayout.SIDE_OWN), MapLayout.SIDE_OWN).size(), "slab + posts + tagged-box walls and nothing else")
	assert_eq(model.viewport.find_children("*", "KidModel", true, false).size(), 0, "no characters")
	for cx: float in [-layout.lane_width / 2.0, layout.lane_width / 2.0]:
		for cz: float in [-layout.lane_length / 2.0, layout.lane_length / 2.0]:
			assert_true(model.camera.is_position_in_frustum(Vector3(cx, 0.0, cz)), "corner %s is in view" % Vector2(cx, cz))


func test_the_map_model_stands_still() -> void:
	var screen: TitleScreen = _screen()
	var model: MenuDiorama = screen.diorama
	model.size = Vector2(690.0, 480.0)
	await wait_frames(2)
	var before: Transform3D = model.camera.global_transform
	await wait_frames(30)
	assert_eq(model.camera.global_transform, before)
	assert_false(model.is_processing(), "nothing runs every frame")
	assert_false(model.is_physics_processing())


func test_online_offers_create_and_join_on_the_game_server() -> void:
	var screen: TitleScreen = _screen()
	var card: MenuDialog = screen.open_online()
	assert_not_null(_find(card, "CreateRoomButton"))
	assert_not_null(_find(card, "JoinRoomButton"))
	assert_null(_find(card, "AddressField"), "the server is set in Settings")
	card.close(false)


func test_hotspot_remembers_the_address_and_opens_the_lobby_on_it() -> void:
	var screen: TitleScreen = _screen()
	var opened: Array = []
	screen.open_lobby_action = func(intent: int) -> void: opened.append(intent)
	var card: MenuDialog = screen.open_hotspot()
	(_find(card, "AddressField") as LineEdit).text = "192.168.43.1:9080"
	(_find(card, "JoinRoomButton") as Button).pressed.emit()
	assert_eq(Settings.hotspot_url, "ws://192.168.43.1:9080")
	assert_true(Session.lobby_hotspot, "the lobby uses the hotspot address")
	assert_eq(Session.lobby_intent, LobbyScreen.Intent.JOIN)
	assert_eq(opened.size(), 1)
	assert_eq(Settings.lobby_url(true), "ws://192.168.43.1:9080")
	assert_eq(Settings.lobby_url(false), Settings.server_url, "the online server is left alone")


func test_online_opens_the_lobby_on_the_game_server() -> void:
	var screen: TitleScreen = _screen()
	var opened: Array = []
	screen.open_lobby_action = func(intent: int) -> void: opened.append(intent)
	var card: MenuDialog = screen.open_online()
	(_find(card, "CreateRoomButton") as Button).pressed.emit()
	assert_false(Session.lobby_hotspot)
	assert_eq(Session.lobby_intent, LobbyScreen.Intent.CREATE)
	assert_eq(opened.size(), 1)


func test_private_addresses_use_plain_ws_and_public_ones_wss() -> void:
	assert_eq(Settings.normalize_url("192.168.43.1:9080"), "ws://192.168.43.1:9080")
	assert_eq(Settings.normalize_url("10.0.0.5:9080"), "ws://10.0.0.5:9080")
	assert_eq(Settings.normalize_url("172.20.10.1:9080"), "ws://172.20.10.1:9080", "an iPhone hotspot")
	assert_eq(Settings.normalize_url("172.32.0.1"), "wss://172.32.0.1", "not a private range")
	assert_eq(Settings.normalize_url("example.org"), "wss://example.org")
	assert_eq(Settings.normalize_url("wss://x"), "wss://x")
