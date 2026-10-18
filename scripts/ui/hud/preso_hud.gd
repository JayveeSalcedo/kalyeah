class_name PresoHud
extends Control
## The Tumbang Preso HUD, built in code like MatchHud: the clock (counting down) at the top
## centre, the tally board on the left (every kid's times tagged, best first, the taya
## marked), the settings button on the right, a prompt over the controls saying what to do
## now, banners, the opening title and the result card. Controls: the movement stick at the
## bottom left and the slipper button at the bottom right (drag to aim, release to throw, tap =
## at the can); the taya has no button. The match screen feeds it sim state through `sync()`.

signal again_pressed
signal exit_pressed

const BANNER_TIME: float = 2.0
const TOP_Y: float = 40.0
const MARGIN: float = 14.0
const GEAR_SIZE: float = 64.0
const CLOCK_SIZE: Vector2 = Vector2(150.0, 64.0)
const BOARD_WIDTH: float = 230.0
const BOARD_ROW: float = 40.0
## The controls sit where the main match has them: the stick at the bottom left, the slipper
## button at the bottom right in weapon 2's place, the cancel zone over it.
const ROW_HEIGHT: float = MatchHud.ROW_HEIGHT
const STICK_ZONE: float = MatchHud.STICK_ZONE
const STICK_FROM_LEFT: float = MatchHud.STICK_FROM_LEFT
const BUTTON_SIZE: float = MatchHud.WEAPON_SIZE
const BUTTON_FROM_RIGHT: float = MatchHud.WEAPON_MARGIN + MatchHud.WEAPON_SIZE / 2.0
const CANCEL_AT: Vector2 = MatchHud.CANCEL_AT
const CANCEL_SIZE: Vector2 = MatchHud.CANCEL_SIZE
const PROMPT_Y: float = 300.0
const OWN_COLOR: Color = Color(0.45, 0.75, 1.0)
const TAYA_COLOR: Color = Color(1.0, 0.45, 0.4)
const GOLD: Color = Color(1.0, 0.86, 0.3)
const INK: Color = Color(0.1, 0.05, 0.1)

var joystick: VirtualJoystick
var throw_button: AimButton
var cancel_zone: Control
var clock_label: Label
var board: VBoxContainer
var prompt_label: Label
var banner: Label
var intro_bar: ColorRect
var intro_title: Label
var intro_sub: Label
var settings_button: TextureButton
var menu: MatchMenu
var result_card: PanelContainer
var result_title: Label
var result_lines: Label
var again_button: Button

var _banner_left: float = 0.0
var _board_text: PackedStringArray = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## What the kid `id` should do right now, in a few words ("" when nothing to say).
static func prompt_for(sim: PresoSim, id: int) -> String:
	if sim.phase != PresoSim.Phase.PLAYING:
		return ""
	var state: PresoPlayer = sim.players[id]
	if sim.is_taya(id):
		match sim.can_state:
			PresoSim.CanState.DOWN:
				return "PICK UP THE CAN!"
			PresoSim.CanState.CARRIED:
				return "PUT IT BACK IN THE CIRCLE!"
		return "TAG A KID OUTSIDE THE LINE!"
	if state.has_slipper:
		if sim.in_home(state.position):
			return "THROW AT THE CAN!  %d" % ceili(sim.shot_clock_left(id))
		return "BACK BEHIND THE LINE!"
	var slipper: PresoSim.Slipper = sim.slippers.get(id) as PresoSim.Slipper
	if slipper == null or slipper.flying:
		return ""
	if sim.can_state != PresoSim.CanState.STANDING:
		return "THE CAN IS DOWN - GET YOUR SLIPPER!"
	if sim.in_home(state.position):
		return "GET YOUR SLIPPER!  %d" % ceili(sim.home_grace_left(id))
	return "GET YOUR SLIPPER - WATCH THE TAYA!"


## The tally board, best first: "1  YOU  0" with "TAYA" after whoever guards the can now.
static func board_lines(sim: PresoSim, names: Dictionary[int, String]) -> PackedStringArray:
	var lines: PackedStringArray = []
	var place: int = 1
	for id: int in sim.ranking():
		var line: String = "%d  %s  %d" % [place, names.get(id, "?"), sim.players[id].times_tagged]
		if sim.is_taya(id):
			line += "  TAYA"
		lines.append(line)
		place += 1
	return lines


## The result card's title for the local kid: a win for the best place, else the place.
static func result_text(sim: PresoSim, local_id: int) -> String:
	var place: int = sim.ranking().find(local_id) + 1
	return "YOU WIN!" if place == 1 else "#%d OF %d" % [place, sim.players.size()]


func sync(sim: PresoSim, local_id: int, names: Dictionary[int, String], delta: float) -> void:
	var seconds: int = ceili(sim.time_left())
	clock_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_sync_board(sim, local_id, names)
	var playing: bool = sim.phase == PresoSim.Phase.PLAYING
	var taya: bool = sim.is_taya(local_id)
	joystick.visible = playing
	if not playing:
		joystick.release()
	throw_button.visible = playing and not taya
	throw_button.set_locked(not sim.can_throw(sim.players[local_id]))
	var prompt: String = prompt_for(sim, local_id)
	prompt_label.text = prompt
	prompt_label.visible = not prompt.is_empty()
	prompt_label.add_theme_color_override("font_color", TAYA_COLOR if taya else Color.WHITE)
	_show_intro(sim.phase == PresoSim.Phase.INTRO)
	result_card.visible = sim.phase == PresoSim.Phase.MATCH_OVER
	if result_card.visible:
		result_title.text = result_text(sim, local_id)
		result_lines.text = "\n".join(board_lines(sim, names))
		joystick.release()
	elif _banner_left > 0.0:
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
	throw_button.set_process_input(active)


func cancel_controls() -> void:
	joystick.release()
	throw_button.cancel_aim()


func controls_active() -> bool:
	return throw_button.is_processing_input()


## Pixels the top row is pushed down to clear a notch or status bar.
func set_top_inset(pixels: float) -> void:
	for control: Control in [clock_label, board, settings_button]:
		control.position.y += pixels


func toggle_menu() -> void:
	if menu.visible:
		menu.close()
		return
	set_controls_active(false)
	menu.open()


func _sync_board(sim: PresoSim, local_id: int, names: Dictionary[int, String]) -> void:
	var lines: PackedStringArray = board_lines(sim, names)
	if lines == _board_text:
		return
	_board_text = lines
	var ids: Array[int] = sim.ranking()
	for child: Node in board.get_children():
		child.queue_free()
	for index: int in lines.size():
		var row: Label = Label.new()
		row.text = lines[index]
		row.theme_type_variation = &"HudPill"
		row.custom_minimum_size = Vector2(0.0, BOARD_ROW)
		row.add_theme_font_size_override("font_size", 22)
		var color: Color = Color.WHITE
		if sim.is_taya(ids[index]):
			color = TAYA_COLOR
		elif ids[index] == local_id:
			color = OWN_COLOR
		row.add_theme_color_override("font_color", color)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(row)


func _show_intro(on: bool) -> void:
	intro_bar.visible = on


func _build() -> void:
	clock_label = _label("3:00", 34, Vector4(0.5, 0, 0.5, 0), Vector4(-CLOCK_SIZE.x / 2.0, TOP_Y, CLOCK_SIZE.x / 2.0, TOP_Y + CLOCK_SIZE.y))
	clock_label.theme_type_variation = &"HudPill"
	board = VBoxContainer.new()
	_place(board, Vector4(0, 0, 0, 0), Vector4(MARGIN, TOP_Y, MARGIN + BOARD_WIDTH, TOP_Y + BOARD_ROW * 6.0))
	board.add_theme_constant_override("separation", 4)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	settings_button = TextureButton.new()
	settings_button.texture_normal = Icons.art(&"gear")
	settings_button.ignore_texture_size = true
	settings_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_place(settings_button, Vector4(1, 0, 1, 0), Vector4(-MARGIN - GEAR_SIZE, TOP_Y, -MARGIN, TOP_Y + GEAR_SIZE))
	settings_button.pressed.connect(toggle_menu)
	add_child(settings_button)
	cancel_zone = _build_cancel_zone()
	throw_button = AimButton.new()
	throw_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_button.icon_id = &"tsinelas_light"
	throw_button.sub_text = "THROW"
	throw_button.cancel_zone = cancel_zone
	add_child(throw_button)
	joystick = VirtualJoystick.new()
	joystick.rest_fraction = Vector2(0.5, 0.5)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick)
	_put(joystick, false, Vector2(STICK_FROM_LEFT, ROW_HEIGHT), Vector2(STICK_ZONE, STICK_ZONE))
	_put(throw_button, true, Vector2(BUTTON_FROM_RIGHT, ROW_HEIGHT), Vector2(BUTTON_SIZE, BUTTON_SIZE))
	_put(cancel_zone, true, CANCEL_AT, CANCEL_SIZE)
	prompt_label = _label("", 26, Vector4(0, 1, 1, 1), Vector4(40, -PROMPT_Y - 28, -40, -PROMPT_Y + 28))
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


## The opening title along the bottom: the game's name and how it goes.
func _build_intro_bar() -> void:
	intro_bar = ColorRect.new()
	intro_bar.color = Color(0.05, 0.04, 0.08, 0.72)
	_place(intro_bar, Vector4(0, 1, 1, 1), Vector4(0, -300, 0, -120))
	intro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_bar.visible = false
	add_child(intro_bar)
	intro_title = _label("TUMBANG PRESO!", 46, Vector4(0, 0, 1, 0), Vector4(0, 14, 0, 74), intro_bar)
	intro_title.add_theme_color_override("font_color", GOLD)
	intro_sub = _label("KNOCK THE CAN  •  FETCH YOUR SLIPPER\nFEWEST TAGS WINS", 24, Vector4(0, 0, 1, 0), Vector4(16, 80, -16, 170), intro_bar)
	intro_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## The end of the match: who won, the final tally, Play again / Exit.
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
	var heading: Label = _label("TIMES TAGGED", 22, Vector4.ZERO, Vector4.ZERO, column)
	heading.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.75))
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
