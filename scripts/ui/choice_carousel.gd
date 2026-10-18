class_name ChoiceCarousel
extends Control
## A tinted full-screen layer with a row of choice cards you swipe through. Tapping a card
## picks it and closes the layer; tapping the tint closes it without a change.

signal picked(index: int)

const CARD_SIZE: Vector2 = Vector2(300.0, 150.0)
const TINT: Color = Color(0.01, 0.025, 0.06, 0.72)

var cards: Array[Button] = []


## `options` are {title, note, color}; the card at `current` is the highlighted one.
static func create(heading: String, options: Array[Dictionary], current: int) -> ChoiceCarousel:
	var carousel: ChoiceCarousel = ChoiceCarousel.new()
	carousel.name = "ChoiceCarousel"
	carousel._build(heading, options, current)
	return carousel


func _build(heading: String, options: Array[Dictionary], current: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tint: ColorRect = ColorRect.new()
	tint.name = "Tint"
	tint.color = TINT
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.gui_input.connect(_on_tint_input)
	add_child(tint)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)
	var title: Label = Label.new()
	title.text = heading
	title.theme_type_variation = &"DisplayLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", KalyeahTheme.CREAM)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size = Vector2(620.0, CARD_SIZE.y + 24.0)
	stack.add_child(scroll)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	for i: int in options.size():
		var option: Dictionary = options[i]
		var card: Button = MenuDialog.make_button("%s\n%s" % [option["title"], option["note"]], String(option["color"]) if i == current else "grey", 22, CARD_SIZE)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.clip_text = true
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.name = "Choice%d" % i
		card.pressed.connect(_pick.bind(i))
		row.add_child(card)
		cards.append(card)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func _pick(index: int) -> void:
	picked.emit(index)
	queue_free()


func _on_tint_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		queue_free()
