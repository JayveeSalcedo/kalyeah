extends GutTest
## The main screen: profile, map model, Practice / Online / Settings / Quit, and the dialogs.

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")

var _saved_name: String
var _saved_avatar: String
var _saved_volume: float
var _saved_url: String
var _saved_vibration: bool


func before_each() -> void:
	_saved_name = Session.player_name
	_saved_avatar = Session.avatar_id
	_saved_volume = Settings.volume
	_saved_url = Settings.server_url
	_saved_vibration = Settings.vibration


func after_each() -> void:
	Session.player_name = _saved_name
	Session.avatar_id = _saved_avatar
	Session.save()
	Settings.set_volume(_saved_volume)
	Settings.set_vibration(_saved_vibration)
	Settings.save_server_url(_saved_url)


func _screen() -> TitleScreen:
	var screen: TitleScreen = autofree(TITLE_SCENE.instantiate()) as TitleScreen
	add_child(screen)
	return screen


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)


func test_version_label_matches_project_setting() -> void:
	var screen: TitleScreen = _screen()
	var label: Label = screen.get_node("%VersionLabel") as Label
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	assert_eq(label.text, "v" + version)


func test_a_normal_run_is_not_the_server() -> void:
	assert_false(TitleScreen.is_server_run(), "tests run without --server or the dedicated_server feature")


func test_server_scene_and_lobby_scene_exist() -> void:
	assert_true(ResourceLoader.exists(TitleScreen.SERVER_SCENE))
	assert_true(ResourceLoader.exists(TitleScreen.LOBBY_SCENE))
	assert_true(ResourceLoader.exists(TitleScreen.PRACTICE_SCENE))


func test_the_screen_has_everything_the_owner_asked_for() -> void:
	var screen: TitleScreen = _screen()
	assert_not_null(screen.profile_button, "username")
	assert_not_null(screen.settings_button, "settings")
	assert_not_null(screen.practice_button, "practice (offline)")
	assert_not_null(screen.create_button, "online: create a room")
	assert_not_null(screen.join_button, "online: join a room")
	assert_not_null(screen.quit_button, "quit")
	assert_not_null(screen.diorama, "the map model")
	assert_string_contains(_all_text(screen.practice_button), "OFFLINE")
	assert_eq(screen.quit_button.text, "QUIT")


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
	assert_eq(TitleScreen.BACKGROUND.get_size(), Vector2(1414.0, 2000.0))


func test_every_tap_target_is_big_enough_for_a_thumb() -> void:
	var screen: TitleScreen = _screen()
	# 720 px design width is about 390 dp on a phone: 88 px is about 48 dp
	for button: Button in [screen.practice_button, screen.create_button, screen.join_button, screen.settings_button, screen.profile_button]:
		assert_gte(button.custom_minimum_size.y, 88.0, "%s is tall enough" % button.name)
	assert_gte(screen.quit_button.custom_minimum_size.y, 64.0)
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


func test_the_map_model_has_the_map_three_kids_and_fits_its_frame() -> void:
	var screen: TitleScreen = _screen()
	var model: MenuDiorama = screen.diorama
	model.size = Vector2(690.0, 480.0)
	await wait_frames(2)
	assert_true(model.map.diorama, "the compact map model")
	assert_eq(model.kids.size(), 3)
	assert_eq(model.map.layout.lane_length, MenuDiorama.LANE_LENGTH)
	assert_ne(model.map.layout.lane_length, (load("res://data/rules/map_layout.tres") as MapLayout).lane_length, "the real layout is not changed")
	# every corner of the model stays in the camera's view, also at both ends of its swing
	var half_x: float = model.map.layout.lane_width / 2.0 + model.map.layout.boundary_thickness + StreetMap.SIDEWALK_WIDTH
	var half_z: float = model.map.layout.lane_length / 2.0 + StreetMap.DIORAMA_REACH
	for yaw: float in [-MenuDiorama.TURN_DEGREES, 0.0, MenuDiorama.TURN_DEGREES]:
		for cx: float in [-half_x, half_x]:
			for cz: float in [-half_z, half_z]:
				var corner: Vector3 = Vector3(cx, StreetMap.CURB_HEIGHT, cz).rotated(Vector3.UP, deg_to_rad(yaw))
				assert_true(model.camera.is_position_in_frustum(corner), "corner %s at %d degrees is in view" % [corner, yaw])


func test_the_map_model_turns_by_itself() -> void:
	var screen: TitleScreen = _screen()
	var model: MenuDiorama = screen.diorama
	model.size = Vector2(690.0, 480.0)
	var start: float = model.pivot.rotation_degrees.y
	await wait_frames(30)
	assert_ne(model.pivot.rotation_degrees.y, start, "it is never a still picture")
	assert_lte(absf(model.pivot.rotation_degrees.y), MenuDiorama.TURN_DEGREES + 0.01)
