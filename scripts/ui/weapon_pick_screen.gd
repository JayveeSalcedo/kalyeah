class_name WeaponPickScreen
extends Control
## Full-screen character and weapon pick (portrait, like a fighting game's select screen).
## A gold title plate with a countdown ring, your two loadout sockets, row 1: the six
## characters as 3:4 profile cards, row 2: a tab per street game (Bato-bato-pik, Tumbang
## preso, ...) over that game's weapon cards (painted art | name, with its description below),
## and a big Ready button. Pick a kid, tap two weapons, then Ready, or wait for the timer to
## auto-fill the weapons. Reads and drives a WeaponPick. In swap mode (waiting to respawn)
## the characters are hidden (a kid is fixed for the match), every full pair of weapons is
## applied at once and the ring shows the respawn countdown.

signal confirmed(picks: Array[StringName])
## A character card was tapped.
signal character_changed(id: StringName)
## Swap mode: a new pair of weapons was picked (applied at once).
signal swapped(picks: Array[StringName])
signal closed

## The character cards are exactly 3:4 (width:height).
const PROFILE_SIZE: Vector2 = Vector2(108.0, 144.0)
const CARD_HEIGHT: float = 100.0
const CARD_ICON: float = 76.0
const TITLE_FONT: int = 30
const TAB_FONT: int = 17
const NAME_FONT: int = 24
const DESCRIPTION_FONT: int = 18
const STAT_FONT: int = 15
const SOCKET_SIZE: float = 76.0
const BACKDROP: Color = Color(0.05, 0.06, 0.14, 0.92)
const PICKED_COLOR: Color = Color(1.0, 0.82, 0.25)
const CARD_COLOR: Color = Color(0.13, 0.16, 0.32, 0.95)
const INK: Color = Color(0.1, 0.06, 0.06)
const GOLD: Color = Color(1.0, 0.8, 0.32)
const KIND_COLORS: Dictionary[WeaponDef.Kind, Color] = {
	WeaponDef.Kind.ATTACK: Color(1.0, 0.42, 0.34),
	WeaponDef.Kind.CROWD_CONTROL: Color(0.74, 0.52, 1.0),
	WeaponDef.Kind.BLOCK: Color(0.42, 0.72, 1.0),
	WeaponDef.Kind.HEAL: Color(0.45, 0.85, 0.4),
}

var pick: WeaponPick
## The character picked on this screen (the kid you play as).
var character_id: StringName = &""
## Respawn swap mode: no pick timer, every full pair is applied, Done closes.
var swap_mode: bool = false

var _characters: Array[CharacterDef] = []
var _profiles: Dictionary[StringName, Button] = {}
var _character_row: Control
var _tabs: Dictionary[String, Button] = {}
var _pages: Dictionary[String, Control] = {}
var _buttons: Dictionary[StringName, Button] = {}
var _badges: Dictionary[StringName, Label] = {}
var _defs: Dictionary[StringName, WeaponDef] = {}
var _title: Label
var _timer: Label
var _ring: CountdownRing
var _sockets: Array[LoadoutSocket] = []
var _ready_button: Button
var _rng: RandomNumberGenerator
var _swap_total: float = 0.0


static func kind_color(kind: WeaponDef.Kind) -> Color:
	return KIND_COLORS[kind]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Shows the screen for `p_pick`. `rng` fills empty slots on timeout. With `characters` the
## kid is picked too (`current` is the one shown selected first).
func open(p_pick: WeaponPick, defs: Array[WeaponDef], heading: String, rng: RandomNumberGenerator,
		characters: Array[CharacterDef] = [], current: StringName = &"") -> void:
	pick = p_pick
	_rng = rng
	swap_mode = false
	_characters = characters
	character_id = current if not characters.is_empty() else &""
	if not characters.is_empty() and not characters.any(func(c: CharacterDef) -> bool: return c.id == character_id):
		character_id = characters[0].id
	_show(defs, heading)


## Opens the respawn swap: change weapons as often as you like until `close()`.
func open_swap(p_pick: WeaponPick, defs: Array[WeaponDef], heading: String) -> void:
	pick = p_pick
	swap_mode = true
	_swap_total = 0.0
	_show(defs, heading)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Swap mode shows the respawn countdown instead of a pick timer.
func show_time(seconds: float) -> void:
	if visible:
		_swap_total = maxf(_swap_total, seconds)
		_timer.text = "Back in %d" % ceili(seconds)
		_ring.show_time(seconds, _swap_total)


func _show(defs: Array[WeaponDef], heading: String) -> void:
	if _buttons.is_empty():
		_build(defs)
	_title.text = heading
	_character_row.visible = not swap_mode and not _characters.is_empty()
	_open_tab(_first_tab())
	visible = true
	_refresh()


## The tab shown first: the street game of your first weapon, else the first one.
func _first_tab() -> String:
	if pick != null and not pick.picks.is_empty() and _defs.has(pick.picks[0]):
		return _defs[pick.picks[0]].street_game
	return _tabs.keys()[0] as String


## Shows one street game's weapon cards.
func open_tab(group: String) -> void:
	_open_tab(group)


func _open_tab(group: String) -> void:
	for name: String in _pages:
		_pages[name].visible = name == group
		_tabs[name].set_pressed_no_signal(name == group)


func current_tab() -> String:
	for name: String in _pages:
		if _pages[name].visible:
			return name
	return ""


## Picks the kid you play as.
func pick_character(id: StringName) -> void:
	if not is_open() or swap_mode or not _profiles.has(id):
		return
	character_id = id
	_refresh()
	character_changed.emit(id)


func is_open() -> bool:
	return visible and pick != null and not pick.done


func tap(id: StringName) -> void:
	if not is_open():
		return
	pick.toggle(id)
	_refresh()
	if swap_mode and pick.picks.size() == WeaponPick.SLOTS:
		swapped.emit(pick.picks.duplicate())


func press_ready() -> void:
	if swap_mode:
		close()
	elif is_open() and pick.confirm():
		_finish()


## Counts the pick timer down (call every frame while open).
func tick(delta: float) -> void:
	if not is_open() or swap_mode:
		return
	if pick.step(delta, _rng):
		_finish()
	else:
		_refresh()


func _finish() -> void:
	visible = false
	confirmed.emit(pick.picks.duplicate())


func _refresh() -> void:
	if not swap_mode:
		_timer.text = "%d" % ceili(pick.time_left)
		_ring.show_time(pick.time_left, pick.time_total)
	for id: StringName in _profiles:
		_profiles[id].set_pressed_no_signal(id == character_id)
	for id: StringName in _buttons:
		var slot: int = pick.picks.find(id)
		_buttons[id].set_pressed_no_signal(slot >= 0)
		_badges[id].visible = slot >= 0
		_badges[id].text = "%d" % (slot + 1)
	for slot: int in _sockets.size():
		var id: StringName = pick.picks[slot] if slot < pick.picks.size() else &""
		_sockets[slot].show_weapon(_defs.get(id) as WeaponDef)
	var can_go: bool = swap_mode or pick.can_confirm()
	_ready_button.disabled = not can_go
	_style_ready(can_go)
	if swap_mode:
		_ready_button.text = "DONE"
	else:
		_ready_button.text = "READY!" if pick.can_confirm() else "Pick %d more" % (WeaponPick.SLOTS - pick.picks.size())


# ---- building -----------------------------------------------------------------------

## Builds the screen once; later opens reuse it.
func _build(defs: Array[WeaponDef]) -> void:
	for def: WeaponDef in defs:
		_defs[def.id] = def
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(_header())
	_character_row = _profile_row()
	column.add_child(_character_row)
	column.add_child(_loadout())
	column.add_child(_tab_row(defs))
	column.add_child(_weapon_pages(defs))
	_ready_button = Button.new()
	_ready_button.custom_minimum_size = Vector2(360.0, 84.0)
	_ready_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ready_button.add_theme_font_size_override("font_size", 32)
	_ready_button.pressed.connect(press_ready)
	column.add_child(_ready_button)


## Row 1: the six characters as 3:4 profile cards.
func _profile_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Characters"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for character: CharacterDef in _characters:
		var card: Button = _profile_card(character)
		row.add_child(card)
		_profiles[character.id] = card
	return row


## One character: their portrait (top-aligned, so the face shows) and name on a 3:4 card.
func _profile_card(character: CharacterDef) -> Button:
	var button: Button = Button.new()
	button.name = "Profile_" + String(character.id)
	button.toggle_mode = true
	button.custom_minimum_size = PROFILE_SIZE
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _card(CARD_COLOR, Color(0.35, 0.4, 0.7), 3))
	button.add_theme_stylebox_override("hover", _card(CARD_COLOR.lightened(0.06), Color(0.5, 0.55, 0.85), 3))
	var chosen: StyleBoxFlat = _card(CARD_COLOR.lightened(0.12), PICKED_COLOR, 6)
	chosen.shadow_color = Color(1.0, 0.8, 0.3, 0.6)
	chosen.shadow_size = 10
	button.add_theme_stylebox_override("pressed", chosen)
	button.add_theme_stylebox_override("hover_pressed", chosen)
	var portrait: Texture2D = KidModel.portrait(character.id)
	var art: TextureRect = TextureRect.new()
	art.texture = portrait
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var inner: float = PROFILE_SIZE.x - 8.0
	art.position = Vector2(4.0, 6.0)
	art.size = Vector2(inner, inner * portrait.get_height() / float(portrait.get_width()))
	button.add_child(art)
	var plate: ColorRect = ColorRect.new()
	plate.color = Color(0.03, 0.04, 0.1, 0.82)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(0.0, PROFILE_SIZE.y - 30.0)
	plate.size = Vector2(PROFILE_SIZE.x, 30.0)
	button.add_child(plate)
	var name_label: Label = _text(character.display_name, 18, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = plate.position
	name_label.size = plate.size
	button.add_child(name_label)
	button.pressed.connect(pick_character.bind(character.id))
	return button


## Row 2: one tab per street game.
func _tab_row(defs: Array[WeaponDef]) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Tabs"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for def: WeaponDef in defs:
		if _tabs.has(def.street_game):
			continue
		var tab: Button = Button.new()
		tab.name = "Tab_" + def.street_game
		tab.text = def.street_game
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0.0, 56.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", TAB_FONT)
		tab.add_theme_color_override("font_color", Color.WHITE)
		tab.add_theme_color_override("font_pressed_color", INK)
		tab.add_theme_color_override("font_hover_pressed_color", INK)
		tab.add_theme_stylebox_override("normal", _card(CARD_COLOR, Color(0.35, 0.4, 0.7), 2))
		tab.add_theme_stylebox_override("hover", _card(CARD_COLOR.lightened(0.08), Color(0.5, 0.55, 0.85), 2))
		var on: StyleBoxFlat = _card(PICKED_COLOR, INK, 3)
		tab.add_theme_stylebox_override("pressed", on)
		tab.add_theme_stylebox_override("hover_pressed", on)
		tab.pressed.connect(_open_tab.bind(def.street_game))
		row.add_child(tab)
		_tabs[def.street_game] = tab
	return row


## The weapon cards of every street game, one page per tab (only one shows), scrollable.
func _weapon_pages(defs: Array[WeaponDef]) -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Weapons"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var holder: VBoxContainer = VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	for group: String in _tabs:
		var page: VBoxContainer = VBoxContainer.new()
		page.name = "Page_" + group
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 8)
		holder.add_child(page)
		_pages[group] = page
		for def: WeaponDef in defs:
			if def.street_game == group:
				page.add_child(_weapon_card(def))
	return scroll


## Gold title plate with the countdown ring beside it.
func _header() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(440.0, 70.0)
	_title.add_theme_font_size_override("font_size", TITLE_FONT)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_outline_color", INK)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_stylebox_override("normal", KalyeahTheme.painted_button("gold"))
	row.add_child(_title)
	_ring = CountdownRing.new()
	_ring.custom_minimum_size = Vector2(84.0, 84.0)
	row.add_child(_ring)
	_timer = Label.new()
	_timer.visible = false
	row.add_child(_timer)
	return row


## Your two loadout sockets.
func _loadout() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	for slot: int in WeaponPick.SLOTS:
		var socket: LoadoutSocket = LoadoutSocket.new()
		socket.number = slot + 1
		socket.custom_minimum_size = Vector2(220.0, SOCKET_SIZE + 36.0)
		row.add_child(socket)
		_sockets.append(socket)
	return row


## One weapon: its painted art on the left; its name, then its description below, then what
## it does in numbers.
func _weapon_card(def: WeaponDef) -> Button:
	var button: Button = Button.new()
	button.name = "Weapon_" + String(def.id)
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = false
	button.add_theme_stylebox_override("normal", _card(CARD_COLOR, kind_color(def.kind).darkened(0.3), 3))
	button.add_theme_stylebox_override("hover", _card(CARD_COLOR.lightened(0.06), kind_color(def.kind).darkened(0.2), 3))
	var picked: StyleBoxFlat = _card(CARD_COLOR.lightened(0.12), PICKED_COLOR, 5)
	picked.shadow_color = Color(1.0, 0.8, 0.3, 0.55)
	picked.shadow_size = 8
	button.add_theme_stylebox_override("pressed", picked)
	button.add_theme_stylebox_override("hover_pressed", picked)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var art: TextureRect = TextureRect.new()
	art.texture = Icons.art(StringName("btn_" + String(def.id)))
	art.custom_minimum_size = Vector2(CARD_ICON, CARD_ICON)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title: HBoxContainer = HBoxContainer.new()
	title.add_theme_constant_override("separation", 10)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title)
	var name_label: Label = _text(def.display_name, NAME_FONT, Color.WHITE)
	name_label.clip_text = false
	title.add_child(name_label)
	var tag: Label = _text(def.kind_label(), 14, Color.WHITE)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(46.0, 22.0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = kind_color(def.kind).darkened(0.15)
	pill.border_color = INK
	pill.set_border_width_all(2)
	pill.set_corner_radius_all(9)
	tag.add_theme_stylebox_override("normal", pill)
	title.add_child(tag)
	var description: Label = _text(def.description, DESCRIPTION_FONT, Color(0.86, 0.9, 1.0))
	description.name = "Description"
	description.clip_text = false
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("outline_size", 0)
	texts.add_child(description)
	var stats: Label = _text(_stat_line(def), STAT_FONT, Color(1.0, 0.86, 0.5))
	stats.add_theme_constant_override("outline_size", 0)
	texts.add_child(stats)
	var badge: Label = _text("1", 18, INK)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var round_badge: StyleBoxFlat = StyleBoxFlat.new()
	round_badge.bg_color = PICKED_COLOR
	round_badge.border_color = INK
	round_badge.set_border_width_all(3)
	round_badge.set_corner_radius_all(16)
	badge.add_theme_stylebox_override("normal", round_badge)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -26.0
	badge.offset_right = 6.0
	badge.offset_top = -8.0
	badge.offset_bottom = 24.0
	badge.visible = false
	button.add_child(badge)
	button.pressed.connect(tap.bind(def.id))
	_buttons[def.id] = button
	_badges[def.id] = badge
	return button


## "14 dmg · 4s · 7m": what the weapon does at a glance.
static func _stat_line(def: WeaponDef) -> String:
	var parts: PackedStringArray = []
	if def.damage > 0:
		parts.append("%d dmg" % (def.damage * maxi(def.count, 1)))
	parts.append("%ss" % String.num(def.cooldown, 0 if is_equal_approx(def.cooldown, roundf(def.cooldown)) else 1))
	if def.max_range > 0.0:
		parts.append("%dm" % roundi(def.max_range))
	return " · ".join(parts)


func _text(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 4)
	label.clip_text = true
	return label


func _card(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(16)
	return style


func _style_ready(on: bool) -> void:
	KalyeahTheme.style_button(_ready_button, "green" if on else "grey")


## Closes the pick now, filling any empty slot at random.
func force_finish() -> void:
	if swap_mode:
		close()
		return
	if not is_open():
		return
	pick.fill(_rng)
	pick.done = true
	_finish()


## Hides the screen without confirming anything (online: the server decided).
func dismiss() -> void:
	if pick != null:
		pick.done = true
	visible = false
