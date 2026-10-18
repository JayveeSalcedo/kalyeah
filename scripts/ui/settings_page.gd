class_name SettingsPage
extends VBoxContainer
## The Settings tab: your profile, sound, vibration (phones), the online server and quitting. The
## same controls fill the settings card that the gear at the top right opens.

signal profile_pressed
signal quit_pressed

var profile_button: Button
var quit_button: Button
var server_field: LineEdit


func _ready() -> void:
	name = "SettingsPage"
	add_theme_constant_override("separation", 14)
	var title: Label = Label.new()
	title.theme_type_variation = &"DisplayLabel"
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 38)
	add_child(title)
	profile_button = MenuDialog.make_button("PROFILE", "blue", 30, Vector2(0.0, 88.0))
	profile_button.name = "ProfileButton"
	profile_button.pressed.connect(profile_pressed.emit)
	add_child(profile_button)
	server_field = fill(self)
	server_field.focus_exited.connect(save_server)
	server_field.text_submitted.connect(func(_text: String) -> void: save_server())
	quit_button = MenuDialog.make_button("QUIT GAME", "red", 30, Vector2(0.0, 88.0))
	quit_button.name = "QuitButton"
	quit_button.pressed.connect(quit_pressed.emit)
	add_child(quit_button)


## Remembers what is typed in the server field.
func save_server() -> void:
	var typed: String = server_field.text.strip_edges()
	if typed != Settings.server_url:
		Settings.save_server_url(typed)


## Sound, vibration (phones only) and the server address, added to `parent`. Returns the server field.
static func fill(parent: Control) -> LineEdit:
	var sound: HBoxContainer = _row(parent, "Sound")
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
		var buzz: HBoxContainer = _row(parent, "Vibration")
		var toggle: Button = MenuDialog.make_button("ON" if Settings.vibration else "OFF", "green" if Settings.vibration else "grey", 28, Vector2(150.0, 72.0))
		toggle.name = "VibrationToggle"
		toggle.pressed.connect(func() -> void:
			Settings.set_vibration(not Settings.vibration)
			toggle.text = "ON" if Settings.vibration else "OFF"
			KalyeahTheme.style_button(toggle, "green" if Settings.vibration else "grey"))
		buzz.add_child(toggle)
	var label: Label = Label.new()
	label.text = "Server"
	label.add_theme_font_size_override("font_size", 26)
	parent.add_child(label)
	var server: LineEdit = LineEdit.new()
	server.name = "ServerField"
	server.text = Settings.server_url
	server.placeholder_text = "wss://your-server"
	server.custom_minimum_size = Vector2(0.0, 76.0)
	server.add_theme_font_size_override("font_size", 28)
	parent.add_child(server)
	return server


static func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170.0, 0.0)
	label.add_theme_font_size_override("font_size", 28)
	row.add_child(label)
	parent.add_child(row)
	return row
