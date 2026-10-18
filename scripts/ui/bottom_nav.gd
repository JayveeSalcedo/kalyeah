class_name BottomNav
extends PanelContainer
## The main screen's bottom bar: a flat wall of light stone slabs, like a Clash of Clans castle, across
## the whole bottom edge (no margin, not a card) with five icon tabs: Characters, Weapons, Battle, History, Menu. Only the
## open tab is lit and shows its name.

signal tab_selected(tab: StringName)

const TABS: Array[Dictionary] = [
	{"id": &"characters", "label": "Characters"},
	{"id": &"weapons", "label": "Weapons"},
	{"id": &"battle", "label": "Battle"},
	{"id": &"history", "label": "History"},
	{"id": &"menu", "label": "Menu"},
]
## The strip's height without the phone's home-bar inset.
const HEIGHT: float = 104.0
## The stone cap along the top edge (the shader's lip).
const LIP: float = 7.0
const STONE_SHADER: Shader = preload("res://shaders/nav_stone.gdshader")
const BAR_COLOR: Color = Color(0.84, 0.81, 0.74)
## Icons on the light stone: dark gray when idle, burnt orange when open.
const IDLE: Color = Color("5a564f")
const LIT: Color = Color("c85f00")

var current: StringName = &"battle"
var buttons: Dictionary[StringName, Button] = {}

var _icons: Dictionary[StringName, NavIcon] = {}
var _labels: Dictionary[StringName, Label] = {}


func _init() -> void:
	name = "BottomNav"
	custom_minimum_size = Vector2(0.0, HEIGHT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_top = 2
	style.border_color = Color(0.0, 0.0, 0.0, 0.18)
	add_theme_stylebox_override("panel", style)
	var cement: ColorRect = ColorRect.new()
	cement.name = "Stone"
	cement.color = BAR_COLOR
	cement.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STONE_SHADER
	cement.material = material
	cement.resized.connect(func() -> void:
		material.set_shader_parameter("rect_size", cement.size)
		# one slab per tab: the bar's height under the lip, a fifth of its width
		material.set_shader_parameter("slab", Vector2(cement.size.x / float(TABS.size()), cement.size.y - LIP)))
	add_child(cement)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Tabs"
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	for tab: Dictionary in TABS:
		var id: StringName = tab["id"]
		var button: Button = Button.new()
		button.name = String(id).capitalize()
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, HEIGHT - 2.0)
		button.pressed.connect(select.bind(id))
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		var stack: VBoxContainer = VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 2)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(stack)
		var icon: NavIcon = NavIcon.new(id)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(icon)
		var label: Label = Label.new()
		label.text = String(tab["label"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", LIT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(label)
		row.add_child(button)
		buttons[id] = button
		_icons[id] = icon
		_labels[id] = label
	_restyle()


## Opens `tab` (emits `tab_selected` when it is a different one).
func select(tab: StringName) -> void:
	if tab == current:
		return
	current = tab
	_restyle()
	tab_selected.emit(tab)


## Makes the strip reach the phone's bottom edge: the tabs stay above the home bar.
func set_bottom_inset(inset: float) -> void:
	add_theme_constant_override("margin_bottom", int(inset))
	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_bottom = inset


func _restyle() -> void:
	for id: StringName in buttons:
		var lit: bool = id == current
		_icons[id].color = LIT if lit else IDLE
		# only the open tab shows its name; the others keep the space so nothing jumps
		_labels[id].modulate.a = 1.0 if lit else 0.0
