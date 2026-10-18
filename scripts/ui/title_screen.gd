class_name TitleScreen
extends Control
## The main screen. Top row: the K! logo on the left, Settings on the right. Middle: a vertical
## carousel of 2:1 mode cards at the left edge (a fifth of each card is past the screen's edge) and
## the chosen mode's details with its action buttons on the right. Settings holds the player's name
## and the infrequent quit action, while Android Back also opens its confirmation.

const SERVER_SCENE: String = "res://server/main.tscn"
const LOBBY_SCENE: String = "res://scenes/ui/lobby.tscn"
const PRACTICE_SCENE: String = "res://scenes/match/practice.tscn"
const BACKGROUND: Texture2D = preload("res://assets/ui/main_bg.webp")
const GEAR: Texture2D = preload("res://assets/icons/gear.png")
const CROP_SHADER: Shader = preload("res://shaders/minimap_crop.gdshader")

## The game modes, first is the default (owner: hotspot first, not online).
const MODES: Array[Dictionary] = [
	{"id": "hotspot", "title": "HOTSPOT", "color": "blue",
		"text": "Play with friends on the same phone hotspot or Wi-Fi. One phone hosts: no server, address or code."},
	{"id": "online", "title": "ONLINE", "color": "orange",
		"text": "Play with anyone through the game server. Create a room and share its code, or join with a code."},
	{"id": "practice", "title": "PRACTICE", "color": "green",
		"text": "Train alone against dummies. No connection needed."},
]
## The maps (street games), first is the default. Only Agawan Base can be played yet.
const MAPS: Array[Dictionary] = [
	{"id": "agawan_base", "title": "AGAWAN BASE", "playable": true},
	{"id": "tumbang_preso", "title": "TUMBANG PRESO", "playable": false},
	{"id": "patintero", "title": "PATINTERO", "playable": false},
]
const LOGO: String = "res://assets/ui/k_logo.png"

const SIDE_MARGIN: float = 34.0
const TOP_MARGIN: float = 26.0
const BOTTOM_MARGIN: float = 22.0
const TAP_TARGET: float = 88.0
const AVATAR: float = 76.0
const GOLD: Color = KalyeahTheme.AMBER
const CREAM: Color = KalyeahTheme.CREAM

## The screen asks for the game to close (replaced in tests).
var quit_action: Callable = _quit_game
## The screen leaves for the lobby (replaced in tests).
var open_lobby_action: Callable = _change_to_lobby

var profile_button: Button
var settings_button: Button
var logo: Control
var carousel: MenuCarousel
var mode_name_label: Label
var mode_text_label: Label
var map_button: Button
var primary_button: Button
var secondary_button: Button
var quit_button: Button
var dialog: MenuDialog

var _name_label: Label
var _avatar_texture: TextureRect
var _loading: bool = false
var _loading_dots: Label


## True for the dedicated server export or `godot --headless -- --server`.
static func is_server_run() -> bool:
	return OS.has_feature("dedicated_server") or OS.get_cmdline_user_args().has("--server")


func _ready() -> void:
	if is_server_run():
		get_tree().change_scene_to_file.call_deferred(SERVER_SCENE)
		return
	Session.ensure_profile()
	Net.stop_host()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_layout()
	_apply_safe_area()
	_refresh_mode()
	settings_button.pressed.connect(open_settings)
	carousel.selected.connect(_on_mode_selected)
	primary_button.pressed.connect(_on_primary_pressed)
	secondary_button.pressed.connect(_on_secondary_pressed)
	map_button.pressed.connect(_on_map_pressed)
	get_viewport().size_changed.connect(_apply_safe_area)
	set_process(false)
	_pop_in.call_deferred()


# ---- layout ---------------------------------------------------------------------------

## The blue diamond picture covers the whole screen (cropped, never stretched), softly vignetted.
func _build_background() -> void:
	var picture: TextureRect = TextureRect.new()
	picture.name = "Background"
	picture.texture = BACKGROUND
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	var vignette: GradientTexture2D = GradientTexture2D.new()
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.46)
	vignette.fill_to = Vector2(1.0, 1.0)
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.0, 0.02, 0.1, 0.0), Color(0.0, 0.02, 0.1, 0.55)])
	vignette.gradient = gradient
	var shade: TextureRect = TextureRect.new()
	shade.name = "Vignette"
	shade.texture = vignette
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


var _margin: MarginContainer


func _build_layout() -> void:
	_margin = MarginContainer.new()
	_margin.name = "Safe"
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_apply_safe_area()
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(column)
	column.add_child(_build_top_bar())
	column.add_child(_build_middle())


## The mode carousel on the left, the details and the action buttons on the right, centred in the
## space under the top row.
func _build_middle() -> Control:
	var middle: HBoxContainer = HBoxContainer.new()
	middle.name = "Middle"
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 24)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carousel = MenuCarousel.new()
	carousel.name = "ModeCarousel"
	# the visible part of a card: 80% of it, counted from the screen's edge (the margin is part of it)
	carousel.custom_minimum_size = Vector2(ChoiceCard.CARD_SIZE.x * (1.0 - MenuCarousel.HIDDEN_LEFT) - SIDE_MARGIN, 560.0)
	carousel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(carousel)
	carousel.setup("Mode", MODES, Session.menu_mode)
	middle.add_child(_build_details())
	return middle


func _build_details() -> Control:
	var details: VBoxContainer = VBoxContainer.new()
	details.name = "Details"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_theme_constant_override("separation", 12)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind: Label = Label.new()
	kind.text = "Game mode"
	kind.theme_type_variation = &"MutedLabel"
	kind.add_theme_font_size_override("font_size", 20)
	details.add_child(kind)
	mode_name_label = Label.new()
	mode_name_label.name = "ModeName"
	mode_name_label.theme_type_variation = &"DisplayLabel"
	mode_name_label.add_theme_font_size_override("font_size", 38)
	mode_name_label.add_theme_color_override("font_color", CREAM)
	mode_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(mode_name_label)
	mode_text_label = Label.new()
	mode_text_label.name = "ModeText"
	mode_text_label.add_theme_font_size_override("font_size", 21)
	mode_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_text_label.custom_minimum_size = Vector2(0.0, 130.0)
	details.add_child(mode_text_label)
	map_button = MenuDialog.make_button("", "grey", 24, Vector2(0.0, 88.0))
	map_button.name = "MapButton"
	map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(map_button)
	primary_button = _action_button(details, "PrimaryButton", "", "orange")
	secondary_button = _action_button(details, "SecondaryButton", "", "green")
	return details


func _action_button(parent: Control, button_name: String, text: String, color: String) -> Button:
	var button: Button = MenuDialog.make_button(text, color, 32, Vector2(0.0, 88.0))
	button.name = button_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


## The chosen mode's name, text and buttons: Hotspot and Online create or join a room, Practice
## starts. A map that can't be played yet turns every action off.
func _refresh_mode() -> void:
	var mode: Dictionary = MODES[Session.menu_mode]
	var map: Dictionary = MAPS[Session.menu_map]
	var rooms: bool = String(mode["id"]) != "practice"
	mode_name_label.text = String(mode["title"])
	mode_text_label.text = String(mode["text"])
	map_button.text = "Map: %s" % String(map["title"])
	primary_button.text = "CREATE ROOM" if rooms else "START"
	secondary_button.text = "JOIN ROOM"
	secondary_button.visible = rooms
	KalyeahTheme.style_button(primary_button, "blue" if rooms else "orange")
	var playable: bool = bool(map["playable"])
	primary_button.disabled = not playable
	secondary_button.disabled = not playable


func _on_mode_selected(index: int) -> void:
	Session.menu_mode = index
	_refresh_mode()


## The map button steps through the street games (only Agawan Base is playable so far).
func _on_map_pressed() -> void:
	Session.menu_map = (Session.menu_map + 1) % MAPS.size()
	_refresh_mode()


func _on_primary_pressed() -> void:
	match String(MODES[Session.menu_mode]["id"]):
		"practice":
			_on_practice_pressed()
		"online":
			_open_lobby(LobbyScreen.Intent.CREATE, false)
		_:
			_open_lobby(LobbyScreen.Intent.CREATE, true)


func _on_secondary_pressed() -> void:
	_open_lobby(LobbyScreen.Intent.JOIN, String(MODES[Session.menu_mode]["id"]) == "hotspot")


## Keeps everything clear of notches, rounded corners and the home bar.
func _apply_safe_area() -> void:
	if _margin == null:
		return
	var inset: Vector4 = safe_insets()
	_margin.add_theme_constant_override("margin_left", int(SIDE_MARGIN + inset.x))
	_margin.add_theme_constant_override("margin_top", int(TOP_MARGIN + inset.y))
	_margin.add_theme_constant_override("margin_right", int(SIDE_MARGIN + inset.z))
	_margin.add_theme_constant_override("margin_bottom", int(BOTTOM_MARGIN + inset.w))
	if carousel != null:
		# the cards start past the screen's left edge: a fifth of each is out of sight
		carousel.left_offset = -(SIDE_MARGIN + inset.x) - ChoiceCard.CARD_SIZE.x * MenuCarousel.HIDDEN_LEFT
		carousel.setup_layout()


## The unsafe screen edges (left, top, right, bottom) in UI pixels: the notch, the status bar,
## rounded corners and the home bar. Zero where the window has none.
func safe_insets() -> Vector4:
	var window: Vector2i = DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0:
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var origin: Vector2i = DisplayServer.window_get_position()
	var to_ui: Vector2 = get_viewport().get_visible_rect().size / Vector2(window)
	var left: float = maxf(0.0, float(safe.position.x - origin.x))
	var top: float = maxf(0.0, float(safe.position.y - origin.y))
	var right: float = maxf(0.0, float(origin.x + window.x - (safe.position.x + safe.size.x)))
	var bottom: float = maxf(0.0, float(origin.y + window.y - (safe.position.y + safe.size.y)))
	return Vector4(minf(left * to_ui.x, 120.0), minf(top * to_ui.y, 120.0), minf(right * to_ui.x, 120.0), minf(bottom * to_ui.y, 120.0))


func _build_top_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo = _build_logo()
	bar.add_child(logo)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	settings_button = DialogButtons.icon_button(GEAR, "blue", TAP_TARGET)
	settings_button.name = "SettingsButton"
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(settings_button)
	return bar


## The owner's K! picture (assets/ui/k_logo.png) when it exists, else a code-drawn K! stand-in.
func _build_logo() -> Control:
	if ResourceLoader.exists(LOGO):
		var picture: TextureRect = TextureRect.new()
		picture.name = "Logo"
		picture.texture = load(LOGO) as Texture2D
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		picture.custom_minimum_size = Vector2(TAP_TARGET + 40.0, TAP_TARGET + 40.0)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return picture
	var stand_in: Label = Label.new()
	stand_in.name = "Logo"
	stand_in.text = "K!"
	stand_in.theme_type_variation = &"DisplayLabel"
	stand_in.add_theme_font_size_override("font_size", 84)
	stand_in.add_theme_color_override("font_color", GOLD)
	stand_in.add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.18))
	stand_in.add_theme_constant_override("outline_size", 10)
	stand_in.custom_minimum_size = Vector2(0.0, TAP_TARGET + 8.0)
	stand_in.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stand_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return stand_in


## The player's character face in a round gold ring.
func _build_avatar() -> Control:
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(AVATAR, AVATAR)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring: Panel = Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.22)
	style.set_corner_radius_all(int(AVATAR))
	style.set_border_width_all(4)
	style.border_color = GOLD
	style.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ring)
	_avatar_texture = TextureRect.new()
	_avatar_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_avatar_texture.offset_left = 5.0
	_avatar_texture.offset_top = 5.0
	_avatar_texture.offset_right = -5.0
	_avatar_texture.offset_bottom = -5.0
	_avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_avatar_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_avatar_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crop: ShaderMaterial = ShaderMaterial.new()
	crop.shader = CROP_SHADER
	crop.set_shader_parameter("rect_size", Vector2(AVATAR - 10.0, AVATAR - 10.0))
	crop.set_shader_parameter("radius", (AVATAR - 10.0) / 2.0)
	_avatar_texture.material = crop
	holder.add_child(_avatar_texture)
	return holder


# ---- what the screen shows ---------------------------------------------------------------

func _refresh_profile() -> void:
	if is_instance_valid(_name_label):
		_name_label.text = Session.player_name
	if is_instance_valid(_avatar_texture):
		var face: Texture2D = KidModel.minimap_face(StringName(Session.avatar_id))
		_avatar_texture.texture = face if face != null else KidModel.portrait(StringName(Session.avatar_id))


## The buttons pop up in turn when the screen opens.
func _pop_in() -> void:
	var buttons: Array[Control] = [primary_button, secondary_button]
	for i: int in buttons.size():
		var button: Control = buttons[i]
		button.pivot_offset = button.size / 2.0
		button.scale = Vector2.ONE * 0.85
		button.modulate.a = 0.0
		var pop: Tween = create_tween().set_parallel(true)
		pop.tween_property(button, "modulate:a", 1.0, 0.25).set_delay(0.1 * i)
		pop.tween_property(button, "scale", Vector2.ONE, 0.35).set_delay(0.1 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---- actions ----------------------------------------------------------------------------

func _on_practice_pressed() -> void:
	if _loading:
		return
	_loading = true
	_show_loading("GETTING THE STREET READY")
	ResourceLoader.load_threaded_request(PRACTICE_SCENE)
	set_process(true)


## The practice match is a big 3D scene: it loads in the background while the screen shows progress.
func _process(_delta: float) -> void:
	if not _loading:
		set_process(false)
		return
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(PRACTICE_SCENE, progress)
	if _loading_dots != null:
		_loading_dots.text = ".".repeat(1 + int(Time.get_ticks_msec() / 300) % 3)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_loading = false
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(PRACTICE_SCENE) as PackedScene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		_loading = false
		get_tree().change_scene_to_file(PRACTICE_SCENE)


func _show_loading(message: String) -> void:
	var cover: ColorRect = ColorRect.new()
	cover.name = "Loading"
	cover.color = Color(0.02, 0.05, 0.16, 0.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(center)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	center.add_child(stack)
	var text: Label = Label.new()
	text.text = message
	text.theme_type_variation = &"DisplayLabel"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 40)
	text.add_theme_color_override("font_color", CREAM)
	text.add_theme_constant_override("outline_size", 4)
	stack.add_child(text)
	_loading_dots = Label.new()
	_loading_dots.text = "."
	_loading_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_dots.add_theme_font_size_override("font_size", 56)
	_loading_dots.add_theme_color_override("font_color", Color.WHITE)
	stack.add_child(_loading_dots)
	var fade: Tween = create_tween()
	fade.tween_property(cover, "color:a", 0.88, 0.25)


func _open_lobby(intent: LobbyScreen.Intent, hotspot: bool) -> void:
	Session.lobby_intent = intent
	Session.lobby_hotspot = hotspot
	open_lobby_action.call(intent)


func _change_to_lobby(_intent: LobbyScreen.Intent) -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _show_dialog(new_dialog: MenuDialog) -> void:
	if dialog != null and is_instance_valid(dialog) and dialog.is_open:
		dialog.close(false)
	dialog = new_dialog
	dialog.open(self)


## Rename: a text box (12 letters at most) with Cancel / Save.
func open_name_editor() -> MenuDialog:
	var card: MenuDialog = MenuDialog.create("YOUR NAME")
	var field: LineEdit = LineEdit.new()
	field.name = "NameField"
	field.text = Session.player_name
	field.placeholder_text = "Your name"
	field.max_length = Session.MAX_NAME_LENGTH
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.custom_minimum_size = Vector2(0.0, 84.0)
	field.add_theme_font_size_override("font_size", 36)
	card.body.add_child(field)
	var hint: Label = card.add_hint("%d characters max." % Session.MAX_NAME_LENGTH)
	var cancel: Button = MenuDialog.make_button("CANCEL", "grey", 30)
	var save: Button = MenuDialog.make_button("SAVE", "green", 30)
	card.add_buttons([cancel, save])
	var apply: Callable = func() -> void:
		var clean: String = Session.clean_name(field.text)
		if clean.is_empty():
			hint.text = "Your name can't be empty."
			hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
			return
		Session.player_name = clean
		Session.save()
		_refresh_profile()
		card.close()
	save.pressed.connect(apply)
	field.text_submitted.connect(func(_text: String) -> void: apply.call())
	cancel.pressed.connect(card.close)
	_show_dialog(card)
	field.grab_focus.call_deferred()
	return card


## Your face and name: tap to rename (the profile lives in Settings now).
func _build_profile_row(settings: MenuDialog) -> Control:
	profile_button = Button.new()
	profile_button.name = "ProfileButton"
	profile_button.custom_minimum_size = Vector2(0.0, TAP_TARGET + 8.0)
	profile_button.clip_text = true
	var pill: StyleBoxFlat = KalyeahTheme.painted_pill()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		profile_button.add_theme_stylebox_override(state, pill)
	MenuDialog.feel_press(profile_button)
	var inner: HBoxContainer = HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 14.0
	inner.offset_right = -14.0
	inner.add_theme_constant_override("separation", 14)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_button.add_child(inner)
	inner.add_child(_build_avatar())
	var texts: VBoxContainer = VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(texts)
	_name_label = Label.new()
	_name_label.theme_type_variation = &"DisplayLabel"
	_name_label.add_theme_font_size_override("font_size", 34)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_name_label)
	var role: Label = Label.new()
	role.text = "Tap to change your name"
	role.theme_type_variation = &"MutedLabel"
	role.add_theme_font_size_override("font_size", 17)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(role)
	_refresh_profile()
	profile_button.pressed.connect(func() -> void:
		settings.close(false)
		open_name_editor())
	return profile_button


## Settings: sound volume, vibration (phones) and the online server address.
func open_settings() -> MenuDialog:
	var card: MenuDialog = MenuDialog.create("SETTINGS")
	card.body.add_child(_build_profile_row(card))
	var sound: HBoxContainer = _settings_row(card, "Sound")
	var slider: HSlider = DialogButtons.slider(Settings.volume)
	slider.name = "VolumeSlider"
	sound.add_child(slider)
	var percent: Label = Label.new()
	percent.custom_minimum_size = Vector2(84.0, 0.0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.add_theme_font_size_override("font_size", 28)
	percent.text = "%d%%" % roundi(Settings.volume * 100.0)
	sound.add_child(percent)
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set_volume(value)
		percent.text = "%d%%" % roundi(value * 100.0))
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.play_ui())
	if Settings.can_vibrate():
		var buzz: HBoxContainer = _settings_row(card, "Vibration")
		var toggle: Button = MenuDialog.make_button("ON" if Settings.vibration else "OFF", "green" if Settings.vibration else "grey", 28, Vector2(150.0, 72.0))
		toggle.name = "VibrationToggle"
		toggle.pressed.connect(func() -> void:
			Settings.set_vibration(not Settings.vibration)
			toggle.text = "ON" if Settings.vibration else "OFF"
			KalyeahTheme.style_button(toggle, "green" if Settings.vibration else "grey"))
		buzz.add_child(toggle)
	card.add_label("Server", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	var server: LineEdit = LineEdit.new()
	server.name = "ServerField"
	server.text = Settings.server_url
	server.placeholder_text = "wss://your-server"
	server.custom_minimum_size = Vector2(0.0, 76.0)
	server.add_theme_font_size_override("font_size", 28)
	card.body.add_child(server)
	quit_button = MenuDialog.make_button("QUIT GAME", "red", 28)
	quit_button.name = "QuitButton"
	card.add_buttons([quit_button])
	quit_button.pressed.connect(open_quit_confirm)
	var done: Button = MenuDialog.make_button("DONE", "green", 34)
	card.add_buttons([done])
	done.pressed.connect(card.close)
	card.closed.connect(func() -> void:
		var typed: String = server.text.strip_edges()
		if typed != Settings.server_url:
			Settings.save_server_url(typed))
	_show_dialog(card)
	return card


func _settings_row(card: MenuDialog, label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170.0, 0.0)
	label.add_theme_font_size_override("font_size", 28)
	row.add_child(label)
	card.body.add_child(row)
	return row


## Quit: asks first (a stray tap must not close the game).
func open_quit_confirm() -> MenuDialog:
	var card: MenuDialog = MenuDialog.create("QUIT GAME?", 560.0)
	var stay: Button = MenuDialog.make_button("CANCEL", "grey", 32)
	var leave: Button = MenuDialog.make_button("QUIT", "red", 32)
	card.add_buttons([stay, leave])
	stay.pressed.connect(card.close)
	leave.pressed.connect(func() -> void:
		card.close(false)
		quit_action.call())
	_show_dialog(card)
	return card


## Close the game: the app quits; a browser tab has no "quit", so it leaves the page instead.
func _quit_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.close(); setTimeout(function () { window.location.replace('about:blank'); }, 120);")
	else:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (dialog == null or not is_instance_valid(dialog) or not dialog.is_open):
		get_viewport().set_input_as_handled()
		open_quit_confirm()


## The phone's back button: close what is open, or ask to quit.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if dialog != null and is_instance_valid(dialog) and dialog.is_open:
			dialog.close()
		else:
			open_quit_confirm()
