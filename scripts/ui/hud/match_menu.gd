class_name MatchMenu
extends Control
## The in-match settings modal: a see-through navy card with a gold frame and a
## title plate, a close button, the
## practice test buttons and Resume / Exit. Built in code.

signal closed
signal exit_pressed
signal hurt_pressed
## A practice animation test: the status (StatusEffects.Type) to play on the local kid.
signal status_pressed(type: int)

const BACKDROP: Color = Color(0.02, 0.02, 0.06, 0.32)
const GOLD: Color = Color(1.0, 0.8, 0.32)
const GOLD_DARK: Color = Color(0.62, 0.4, 0.1)
const INK: Color = Color(0.1, 0.06, 0.06)
const CARD_SIZE: Vector2 = Vector2(440.0, 600.0)
## The practice buttons that play the animations a skill hit causes (label, StatusEffects.Type).
const STATUS_TESTS: Array[Array] = [["STUNNED", StatusEffects.Type.STUN], ["AIRBORNE", StatusEffects.Type.AIRBORNE], ["KNOCKED DOWN", StatusEffects.Type.KNOCKOUT]]
## The card is a little see-through, so the street shows behind it.
const CARD_ALPHA: float = 0.9
const BUTTON_HEIGHT: float = 62.0

var hurt_button: Button
## Practice only: one button per animation a skill hit plays (status type -> button).
var status_buttons: Dictionary[int, Button] = {}

var _test_title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	var card: PanelContainer = PanelContainer.new()
	_centered(card, Rect2(-CARD_SIZE / 2.0, CARD_SIZE))
	var card_style: StyleBoxFlat = KalyeahTheme.painted_panel()
	card_style.content_margin_top = 48.0
	card_style.bg_color = Color(card_style.bg_color, CARD_ALPHA)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	_test_title = _section(column, "PRACTICE")
	hurt_button = _button("TAKE 30 DAMAGE", "blue", column)
	hurt_button.pressed.connect(hurt_pressed.emit)
	_section(column, "PLAY A HIT ANIMATION")
	for test: Array in STATUS_TESTS:
		var play: Button = _button(test[0] as String, "orange", column)
		play.pressed.connect(status_pressed.emit.bind(test[1] as int))
		status_buttons[test[1] as int] = play
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var resume: Button = _button("RESUME", "green", column)
	resume.pressed.connect(close)
	var leave: Button = _button("EXIT MATCH", "red", column)
	leave.pressed.connect(exit_pressed.emit)
	# siblings of the card (a container would lay them out inside it)
	_title_plate()


## Practice shows the test buttons (damage and the hit animations); an online match does not.
func set_practice(on: bool) -> void:
	hurt_button.visible = on
	for button: Button in status_buttons.values():
		button.visible = on
	_test_title.visible = on


func open() -> void:
	_test_title.visible = hurt_button.visible
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	var tap: InputEventMouseButton = event as InputEventMouseButton
	if tap != null and tap.pressed:
		close()


## The gold "MENU" plate riding on the card's top edge.
func _title_plate() -> void:
	var plate: Label = Label.new()
	plate.text = "MENU"
	plate.theme_type_variation = &"DisplayLabel"
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_theme_font_size_override("font_size", 34)
	plate.add_theme_color_override("font_color", Color.WHITE)
	plate.add_theme_color_override("font_outline_color", INK)
	plate.add_theme_constant_override("outline_size", 10)
	plate.add_theme_stylebox_override("normal", KalyeahTheme.painted_button("gold"))
	_centered(plate, Rect2(-110.0, -CARD_SIZE.y / 2.0 - 30.0, 220.0, 60.0))
	add_child(plate)


## Places `control` at `rect`, measured from the screen centre.
func _centered(control: Control, rect: Rect2) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


func _section(parent: Control, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", GOLD)
	parent.add_child(label)
	return label


func _button(text: String, paint: String, parent: Control) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", 24)
	KalyeahTheme.style_button(button, paint)
	parent.add_child(button)
	return button
