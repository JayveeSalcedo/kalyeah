class_name MenuPage
extends VBoxContainer
## The Menu tab: your profile, settings and quitting.

signal profile_pressed
signal settings_pressed
signal quit_pressed

var profile_button: Button
var settings_button: Button
var quit_button: Button


func _ready() -> void:
	name = "MenuPage"
	add_theme_constant_override("separation", 14)
	var title: Label = Label.new()
	title.theme_type_variation = &"DisplayLabel"
	title.text = "MENU"
	title.add_theme_font_size_override("font_size", 38)
	add_child(title)
	profile_button = _button("PROFILE", "blue", profile_pressed)
	settings_button = _button("SETTINGS", "grey", settings_pressed)
	quit_button = _button("QUIT GAME", "red", quit_pressed)


func _button(text: String, color: String, pressed: Signal) -> Button:
	var button: Button = MenuDialog.make_button(text, color, 32, Vector2(0.0, 92.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(pressed.emit)
	add_child(button)
	return button
