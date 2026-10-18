class_name BottomNav
extends PanelContainer
## The main screen's bottom bar: a flat wall of light stone slabs, like a Clash of Clans castle, across
## the whole bottom edge (no margin, not a card) with five icon tabs: Characters, Weapons, Battle, History, Settings. Only the
## open tab is lit and shows its name.

signal tab_selected(tab: StringName)

const TABS: Array[Dictionary] = [
	{"id": &"characters", "label": "Characters"},
	{"id": &"weapons", "label": "Weapons"},
	{"id": &"battle", "label": "Battle"},
	{"id": &"history", "label": "History"},
	{"id": &"settings", "label": "Settings"},
]
## The strip's height without the phone's home-bar inset.
const HEIGHT: float = 104.0
const STONE_SHADER: Shader = preload("res://shaders/nav_stone.gdshader")
const BAR_COLOR: Color = Color(0.10, 0.17, 0.32)
## Icons on the dark blue cement: soft blue-gray when idle, amber when open.
const IDLE: Color = Color("8fa3c4")
const LIT: Color = Color("ffbf3c")
const NAME_COLOR: Color = Color("fff3d6")
## The open tab's icon grows and rises past the bar's top edge to make room for its name.
const LIT_SCALE: float = 1.5
const LIT_RISE: float = 30.0
const MOVE_TIME: float = 0.16

var current: StringName = &"battle"
var buttons: Dictionary[StringName, Button] = {}

var _inner: MarginContainer
var _left: float = 0.0
var _right: float = 0.0
var _icons: Dictionary[StringName, NavIcon] = {}
var _labels: Dictionary[StringName, Label] = {}


func _init() -> void:
	name = "BottomNav"
	custom_minimum_size = Vector2(0.0, HEIGHT)
	clip_contents = false
	# a plain panel: no border, no rounding, no shadow (the look is the shader behind the tabs)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var stone: ColorRect = ColorRect.new()
	stone.name = "Stone"
	stone.color = BAR_COLOR
	stone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STONE_SHADER
	stone.material = material
	stone.resized.connect(func() -> void:
		material.set_shader_parameter("rect_size", stone.size)
		_update_inner())
	add_child(stone)
	# the tabs sit between the screen's side margins; a partition line closes each end of the strip
	_inner = MarginContainer.new()
	_inner.name = "Inner"
	_inner.add_theme_constant_override("margin_left", 0)
	_inner.add_theme_constant_override("margin_right", 0)
	add_child(_inner)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Tabs"
	row.add_theme_constant_override("separation", 0)
	_inner.add_child(row)
	for tab: Dictionary in TABS:
		var id: StringName = tab["id"]
		var button: Button = Button.new()
		button.name = String(id).capitalize()
		button.focus_mode = Control.FOCUS_NONE
		button.clip_contents = false
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, HEIGHT)
		button.pressed.connect(select.bind(id))
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		var icon: NavIcon = NavIcon.new(id)
		icon.pivot_offset = Vector2(NavIcon.SIZE, NavIcon.SIZE) / 2.0
		button.add_child(icon)
		var label: Label = Label.new()
		label.text = String(tab["label"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", NAME_COLOR)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.12))
		label.add_theme_constant_override("outline_size", 4)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_top = -32.0
		label.offset_bottom = -6.0
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		button.resized.connect(_place.bind(id, false))
		row.add_child(button)
		buttons[id] = button
		_icons[id] = icon
		_labels[id] = label
	_restyle(false)


## Opens `tab` (emits `tab_selected` when it is a different one).
func select(tab: StringName) -> void:
	if tab == current:
		return
	current = tab
	_restyle(true)
	tab_selected.emit(tab)


## Keeps the tabs inside the screen's side margins (`left` and `right` in pixels). The bar itself
## still runs edge to edge; partition lines mark where the tab strip begins and ends.
func set_side_margins(left: float, right: float) -> void:
	_left = left
	_right = right
	_inner.add_theme_constant_override("margin_left", int(left))
	_inner.add_theme_constant_override("margin_right", int(right))
	_update_inner()


func _update_inner() -> void:
	var stone: ColorRect = find_child("Stone", true, false) as ColorRect
	var material: ShaderMaterial = stone.material as ShaderMaterial
	material.set_shader_parameter("inner", Vector2(_left, stone.size.x - _right))


## Makes the bar reach the phone's bottom edge: the tabs stay above the home bar.
func set_bottom_inset(inset: float) -> void:
	add_theme_constant_override("margin_bottom", int(inset))


func _restyle(animate: bool) -> void:
	for id: StringName in buttons:
		_place(id, animate)
	var material: ShaderMaterial = (find_child("Stone", true, false) as ColorRect).material as ShaderMaterial
	material.set_shader_parameter("active_tab", float(_index_of(current)))


func _index_of(tab: StringName) -> int:
	for i: int in TABS.size():
		if TABS[i]["id"] == tab:
			return i
	return 0


## Puts a tab's icon where it belongs: the open one big and rising past the bar's top edge with its
## name under it, the others small and centred in the bar.
func _place(id: StringName, animate: bool) -> void:
	var lit: bool = id == current
	var button: Button = buttons[id]
	var icon: NavIcon = _icons[id]
	var x: float = (button.size.x - NavIcon.SIZE) / 2.0
	var y: float = (HEIGHT - NavIcon.SIZE) / 2.0 - LIT_RISE if lit else (HEIGHT - NavIcon.SIZE) / 2.0
	var grown: Vector2 = Vector2.ONE * (LIT_SCALE if lit else 1.0)
	icon.color = LIT if lit else IDLE
	_labels[id].visible = lit
	var tween_key: String = "move_%s" % id
	if animate and is_inside_tree():
		if has_meta(tween_key):
			(get_meta(tween_key) as Tween).kill()
		var move: Tween = create_tween().set_parallel(true)
		move.tween_property(icon, "position", Vector2(x, y), MOVE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		move.tween_property(icon, "scale", grown, MOVE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		set_meta(tween_key, move)
	else:
		icon.position = Vector2(x, y)
		icon.scale = grown
