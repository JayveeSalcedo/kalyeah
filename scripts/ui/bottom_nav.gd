class_name BottomNav
extends PanelContainer
## The main screen's bottom bar: Characters, Weapons, Battle, History, Menu. The open tab is lit.

signal tab_selected(tab: StringName)

const TABS: Array[Dictionary] = [
	{"id": &"characters", "label": "Characters"},
	{"id": &"weapons", "label": "Weapons"},
	{"id": &"battle", "label": "Battle"},
	{"id": &"history", "label": "History"},
	{"id": &"menu", "label": "Menu"},
]
const HEIGHT: float = 104.0

var current: StringName = &"battle"
var buttons: Dictionary[StringName, Button] = {}


func _init() -> void:
	name = "BottomNav"
	custom_minimum_size = Vector2(0.0, HEIGHT)
	var style: StyleBoxFlat = KalyeahTheme.painted_panel(6.0)
	add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for tab: Dictionary in TABS:
		var button: Button = Button.new()
		button.name = String(tab["id"]).capitalize()
		button.text = String(tab["label"])
		button.toggle_mode = false
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", KalyeahTheme.BODY_FONT)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(select.bind(tab["id"] as StringName))
		MenuDialog.feel_press(button)
		row.add_child(button)
		buttons[tab["id"] as StringName] = button
	_restyle()


## Opens `tab` (emits `tab_selected` when it is a different one).
func select(tab: StringName) -> void:
	if tab == current:
		return
	current = tab
	_restyle()
	tab_selected.emit(tab)


func _restyle() -> void:
	for id: StringName in buttons:
		var button: Button = buttons[id]
		var lit: bool = id == current
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		var lit_style: StyleBoxFlat = StyleBoxFlat.new()
		lit_style.bg_color = Color(KalyeahTheme.AMBER, 0.22)
		lit_style.set_corner_radius_all(18)
		lit_style.set_border_width_all(2)
		lit_style.border_color = KalyeahTheme.AMBER
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			button.add_theme_stylebox_override(state, lit_style if lit else empty)
		var colour: Color = KalyeahTheme.AMBER if lit else KalyeahTheme.TEXT_MUTED
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, colour)
