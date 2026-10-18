extends GutTest
## The main screen: the K! logo and settings on top, a vertical map carousel on the left, the map's details and the action buttons on the right.

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
	Session.menu_map = 0


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


func _phone_screen() -> TitleScreen:
	var phone: Control = autofree(Control.new()) as Control
	phone.custom_minimum_size = Vector2(720.0, 1280.0)
	phone.size = Vector2(720.0, 1280.0)
	add_child(phone)
	var screen: TitleScreen = autofree(TITLE_SCENE.instantiate()) as TitleScreen
	phone.add_child(screen)
	return screen


func test_the_screen_has_everything_the_owner_asked_for() -> void:
	var screen: TitleScreen = _screen()
	assert_not_null(screen.logo, "the K! logo")
	assert_not_null(screen.settings_button, "settings")
	assert_not_null(screen.carousel, "the map carousel")
	assert_eq(screen.map_name_label.text, "AGAWAN BASE", "agawan base is the default map")
	assert_eq(screen.hotspot_button.text, "HOTSPOT")
	assert_eq(screen.online_button.text, "ONLINE")
	assert_eq(screen.practice_button.text, "PRACTICE")
	assert_null(screen.quit_button, "quit stays out of the main action area")
	assert_null(screen.find_child("ModeCard", true, false), "the mode cards are gone: the buttons are the modes")


func test_logo_top_left_settings_top_right_carousel_left_details_right() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	var logo: Rect2 = screen.logo.get_global_rect()
	var gear: Rect2 = screen.settings_button.get_global_rect()
	var strip: Rect2 = screen.carousel.get_global_rect()
	var buttons: Rect2 = screen.hotspot_button.get_global_rect()
	assert_lt(logo.position.x, 120.0, "the logo is on the left")
	assert_gt(gear.end.x, 720.0 - 120.0, "settings is on the right")
	assert_almost_eq(logo.position.y, gear.position.y, 8.0, "one top row")
	assert_gt(strip.position.y, logo.end.y, "the middle is under the top row")
	assert_lt(strip.end.x, buttons.position.x, "the carousel is left of the details")
	assert_lt(screen.map_name_label.get_global_rect().position.x, buttons.end.x)
	assert_lt(buttons.end.x, 720.0)
	assert_lt(screen.practice_button.get_global_rect().end.y, 1280.0)
	assert_lt(screen.hotspot_button.get_global_rect().position.y, screen.online_button.get_global_rect().position.y, "hotspot first, not online")
	assert_lt(screen.online_button.get_global_rect().position.y, screen.practice_button.get_global_rect().position.y)


func test_the_carousel_keeps_the_chosen_card_in_front_and_the_others_behind_and_fainter() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	var strip: MapCarousel = screen.carousel
	assert_eq(strip.cards.size(), 3)
	var middle: Button = strip.cards[0]
	var next: Button = strip.cards[1]
	assert_almost_eq(middle.size.x / middle.size.y, 2.0, 0.01, "2:1 cards")
	assert_eq(middle.modulate.a, 1.0)
	assert_lt(next.modulate.a, 1.0, "the next card is see-through")
	assert_lt(next.scale.x, middle.scale.x, "and smaller")
	assert_lt(next.z_index, middle.z_index, "and behind")
	assert_gt(next.position.y + next.size.y / 2.0, middle.position.y + middle.size.y / 2.0, "and below it")
	strip.select(1, false)
	assert_eq(strip.cards[1].modulate.a, 1.0, "the chosen card comes forward")
	assert_lt(strip.cards[0].modulate.a, 1.0)
	assert_eq(screen.map_name_label.text, "TUMBANG PRESO", "the details follow the chosen card")
	assert_true(screen.hotspot_button.disabled, "only agawan base can be played yet")
	strip.select(0, false)
	assert_false(screen.hotspot_button.disabled)


func test_scrolling_and_tapping_the_carousel_changes_the_card() -> void:
	var screen: TitleScreen = _phone_screen()
	await wait_frames(3)
	var strip: MapCarousel = screen.carousel
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	strip._gui_input(wheel)
	assert_eq(strip.index, 1, "the wheel moves to the next card")
	await wait_seconds(0.4)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(150.0, strip.size.y / 2.0 + 300.0)
	press.pressed = true
	strip._gui_input(press)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.position = Vector2(150.0, strip.size.y / 2.0 + 300.0 - MapCarousel.STEP * 1.1)
	strip._gui_input(drag)
	press.pressed = false
	press.position = drag.position
	strip._gui_input(press)
	assert_eq(strip.index, 2, "dragging up scrolls on to the third card")
	await wait_seconds(0.4)
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = Vector2(150.0, strip.size.y / 2.0 - MapCarousel.STEP)
	tap.pressed = true
	strip._gui_input(tap)
	tap.pressed = false
	strip._gui_input(tap)
	assert_eq(strip.index, 1, "tapping the card above brings it to the middle")


func test_the_action_buttons_open_their_modes() -> void:
	var screen: TitleScreen = _screen()
	screen.hotspot_button.pressed.emit()
	assert_not_null(screen.dialog, "hotspot opens its create / join card")
	assert_null(screen.dialog.find_child("AddressField", true, false), "a hotspot room needs no address or code")
	screen.online_button.pressed.emit()
	assert_null(screen.dialog.find_child("AddressField", true, false), "online has no address field")


func test_the_screen_shows_no_version_online_caption_or_server_line() -> void:
	var screen: TitleScreen = _screen()
	var text: String = _all_text(screen)
	assert_false(text.contains("ONLINE  "), "no ONLINE caption")
	assert_false(text.contains("Server"), "no server line")
	assert_false(text.contains("No server"), "no server hint")
	assert_eq(text.count("v0."), 0, "no version")
	assert_null(screen.find_child("VersionLabel", true, false))
	assert_null(screen.find_child("Wordmark", true, false), "the game name was removed")


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
	for button: Button in [screen.hotspot_button, screen.online_button, screen.practice_button, screen.settings_button]:
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
	screen.open_settings()
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
	assert_eq((_find(card, "QuitButton") as Button).text, "QUIT GAME")
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
	assert_eq(stay.text, "CANCEL")
	assert_eq(leave.text, "QUIT")
	stay.pressed.emit()
	assert_eq(quit_calls[0], 0, "CANCEL keeps playing")
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


func test_online_offers_create_and_join_on_the_game_server() -> void:
	var screen: TitleScreen = _screen()
	var card: MenuDialog = screen.open_online()
	assert_not_null(_find(card, "CreateRoomButton"))
	assert_not_null(_find(card, "JoinRoomButton"))
	assert_null(_find(card, "AddressField"), "the server is set in Settings")
	card.close(false)


func test_hotspot_opens_the_lobby_with_no_address_to_type() -> void:
	var screen: TitleScreen = _screen()
	var opened: Array = []
	screen.open_lobby_action = func(intent: int) -> void: opened.append(intent)
	var card: MenuDialog = screen.open_hotspot()
	(_find(card, "JoinRoomButton") as Button).pressed.emit()
	assert_true(Session.lobby_hotspot, "the lobby is in hotspot mode")
	assert_eq(Session.lobby_intent, LobbyScreen.Intent.JOIN)
	assert_eq(opened.size(), 1)
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
