class_name StreetGameHud
extends Control
## What every street-game practice HUD shares (Tumbang Preso, Patintero), built in code like
## MatchHud: the clock at the top centre, the settings button at the top right (Resume / Exit),
## the movement stick at the bottom left (where the main match has it), a prompt over the controls saying what to do now,
## banners, the opening title along the bottom and the result card (title, final lines, Play
## again / Exit). A game's HUD extends it and adds its own pieces in `_build_game()`.

signal again_pressed
signal exit_pressed

const BANNER_TIME: float = 2.0
const TOP_Y: float = 40.0
const MARGIN: float = 14.0
const GEAR_SIZE: float = 64.0
const CLOCK_SIZE: Vector2 = Vector2(150.0, 64.0)
## The controls sit where the main match has them: the stick at the bottom left, a game's button
## at the bottom right in weapon 2's place, the cancel zone over it.
const ROW_HEIGHT: float = MatchHud.ROW_HEIGHT
const STICK_ZONE: float = MatchHud.STICK_ZONE
const STICK_FROM_LEFT: float = MatchHud.STICK_FROM_LEFT
const BUTTON_SIZE: float = MatchHud.WEAPON_SIZE
const BUTTON_FROM_RIGHT: float = MatchHud.WEAPON_MARGIN + MatchHud.WEAPON_SIZE / 2.0
const CANCEL_AT: Vector2 = MatchHud.CANCEL_AT
const CANCEL_SIZE: Vector2 = MatchHud.CANCEL_SIZE
const PROMPT_Y: float = 300.0
const OWN_COLOR: Color = Color(0.45, 0.75, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.45, 0.4)
const GOLD: Color = Color(1.0, 0.86, 0.3)
const INK: Color = Color(0.1, 0.05, 0.1)

var joystick: VirtualJoystick
var cancel_zone: Control
var clock_label: Label
var prompt_label: Label
var banner: Label
var intro_bar: ColorRect
var intro_title: Label
var intro_sub: Label
var settings_button: TextureButton
var menu: MatchMenu
var result_card: PanelContainer
var result_title: Label
var result_heading: Label
var result_lines: Label
var again_button: Button

var _banner_left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## The game's own controls and top pieces (called once while building, before the overlays).
func _build_game() -> void:
	pass


## The aimed buttons the game added (switched with the stick by set_controls_active()).
func aim_buttons() -> Array[AimButton]:
	return []


## The top pieces pushed down by set_top_inset() besides the clock and settings button.
func top_controls() -> Array[Control]:
	return []


## The clock as m:ss (`seconds` rounded up).
func set_clock(seconds: float) -> void:
	var whole: int = ceili(seconds)
	clock_label.text = "%d:%02d" % [whole / 60, whole % 60]


func set_prompt(text: String, color: Color = Color.WHITE) -> void:
	prompt_label.text = text
	prompt_label.visible = not text.is_empty()
	prompt_label.add_theme_color_override("font_color", color)


## Shows (or hides) the stick; a hidden stick lets go of any thumb on it.
func show_stick(on: bool) -> void:
	joystick.visible = on
	if not on:
		joystick.release()


## The result card with `title` and the final `lines`, or hidden when `title` is empty.
## Banners stop while it shows.
func show_result(title: String, lines: PackedStringArray = []) -> void:
	result_card.visible = not title.is_empty()
	if result_card.visible:
		result_title.text = title
		result_lines.text = "\n".join(lines)
		joystick.release()


func show_intro(on: bool) -> void:
	intro_bar.visible = on


## Banners fade after BANNER_TIME (not while the result card shows).
func tick(delta: float) -> void:
	if result_card.visible or _banner_left <= 0.0:
		return
	_banner_left -= delta
	if _banner_left <= 0.0:
		banner.visible = false


func show_banner(text: String) -> void:
	banner.text = text
	banner.visible = true
	_banner_left = BANNER_TIME
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2.ONE * 1.5
	banner.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.12)


func banner_text() -> String:
	return banner.text if banner.visible else ""


func set_controls_active(active: bool) -> void:
	if not active:
		cancel_controls()
	joystick.set_process_input(active)
	for button: AimButton in aim_buttons():
		button.set_process_input(active)


func cancel_controls() -> void:
	joystick.release()
	for button: AimButton in aim_buttons():
		button.cancel_aim()


func controls_active() -> bool:
	return joystick.is_processing_input()


## Pixels the top row is pushed down to clear a notch or status bar.
func set_top_inset(pixels: float) -> void:
	var controls: Array[Control] = [clock_label, settings_button]
	controls.append_array(top_controls())
	for control: Control in controls:
		control.position.y += pixels


func toggle_menu() -> void:
	if menu.visible:
		menu.close()
		return
	set_controls_active(false)
	menu.open()


func _build() -> void:
	clock_label = _label("0:00", 34, Vector4(0.5, 0, 0.5, 0), Vector4(-CLOCK_SIZE.x / 2.0, TOP_Y, CLOCK_SIZE.x / 2.0, TOP_Y + CLOCK_SIZE.y))
	clock_label.theme_type_variation = &"HudPill"
	settings_button = TextureButton.new()
	settings_button.texture_normal = Icons.art(&"gear")
	settings_button.ignore_texture_size = true
	settings_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_place(settings_button, Vector4(1, 0, 1, 0), Vector4(-MARGIN - GEAR_SIZE, TOP_Y, -MARGIN, TOP_Y + GEAR_SIZE))
	settings_button.pressed.connect(toggle_menu)
	add_child(settings_button)
	cancel_zone = _build_cancel_zone()
	joystick = VirtualJoystick.new()
	joystick.rest_fraction = Vector2(0.5, 0.5)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick)
	_put(joystick, false, Vector2(STICK_FROM_LEFT, ROW_HEIGHT), Vector2(STICK_ZONE, STICK_ZONE))
	_put(cancel_zone, true, CANCEL_AT, CANCEL_SIZE)
	_build_game()
	prompt_label = _label("", 26, Vector4(0, 1, 1, 1), Vector4(40, -PROMPT_Y - 28, -40, -PROMPT_Y + 28))
	prompt_label.visible = false
	banner = _label("", 44, Vector4(0, 0.3, 1, 0.3), Vector4(0, -60, 0, 60))
	banner.add_theme_color_override("font_color", GOLD)
	banner.add_theme_constant_override("outline_size", 12)
	banner.visible = false
	_build_intro_bar()
	_build_result_card()
	# last, so it draws over everything
	menu = MatchMenu.new()
	add_child(menu)
	menu.set_practice(false)
	menu.exit_pressed.connect(exit_pressed.emit)
	menu.closed.connect(set_controls_active.bind(true))


## Puts a game's button at the bottom right, where the main match has weapon 2.
func _put_button(control: Control) -> void:
	_put(control, true, Vector2(BUTTON_FROM_RIGHT, ROW_HEIGHT), Vector2(BUTTON_SIZE, BUTTON_SIZE))


## The opening title along the bottom: the game's name and how it goes (set by the game).
func _build_intro_bar() -> void:
	intro_bar = ColorRect.new()
	intro_bar.color = Color(0.05, 0.04, 0.08, 0.72)
	_place(intro_bar, Vector4(0, 1, 1, 1), Vector4(0, -300, 0, -120))
	intro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_bar.visible = false
	add_child(intro_bar)
	intro_title = _label("", 46, Vector4(0, 0, 1, 0), Vector4(0, 14, 0, 74), intro_bar)
	intro_title.add_theme_color_override("font_color", GOLD)
	intro_sub = _label("", 24, Vector4(0, 0, 1, 0), Vector4(16, 80, -16, 170), intro_bar)
	intro_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_result_card() -> void:
	result_card = PanelContainer.new()
	result_card.add_theme_stylebox_override("panel", KalyeahTheme.painted_panel(34.0))
	_place(result_card, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-260, -240, 260, 240))
	result_card.visible = false
	add_child(result_card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	result_card.add_child(column)
	result_title = _label("", 48, Vector4.ZERO, Vector4.ZERO, column)
	result_title.add_theme_color_override("font_color", GOLD)
	result_heading = _label("", 22, Vector4.ZERO, Vector4.ZERO, column)
	result_heading.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.75))
	result_lines = _label("", 28, Vector4.ZERO, Vector4.ZERO, column)
	result_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	again_button = MenuDialog.make_button("PLAY AGAIN", "green", 28)
	again_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again_button.pressed.connect(again_pressed.emit)
	buttons.add_child(again_button)
	var leave: Button = MenuDialog.make_button("EXIT", "red", 28)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(exit_pressed.emit)
	buttons.add_child(leave)


func _build_cancel_zone() -> Control:
	var zone: Control = Control.new()
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.visible = false
	add_child(zone)
	var back: ColorRect = ColorRect.new()
	_place(back, Vector4(0, 0, 1, 1), Vector4.ZERO)
	back.color = Color(0.85, 0.15, 0.15, 0.55)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(back)
	_label("Cancel", 24, Vector4(0, 0, 1, 1), Vector4.ZERO, zone)
	return zone


## A centred, outlined label (white unless coloured later) added to `parent` (default: the HUD).
func _label(text: String, font_size: int, anchors: Vector4, offsets: Vector4, parent: Control = null) -> Label:
	var label: Label = Label.new()
	_place(label, anchors, offsets)
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label


## Places `control` with its centre `at` = (from the right or left edge, from the bottom).
func _put(control: Control, from_right: bool, at: Vector2, extent: Vector2) -> void:
	var edge: float = 1.0 if from_right else 0.0
	var near: float = (-1.0 if from_right else 1.0) * at.x
	_place(control, Vector4(edge, 1, edge, 1), Vector4(
		near - extent.x / 2.0, -at.y - extent.y / 2.0, near + extent.x / 2.0, -at.y + extent.y / 2.0))


## Anchors first, then offsets (setting an anchor can move offsets).
func _place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w
