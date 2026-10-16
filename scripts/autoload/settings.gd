extends Node
## User and build settings. The game server address comes from, in order:
## the web page's `?server=wss://...` query, the address saved in the lobby, or
## the project setting `kalyeah/network/server_url` (empty until a server is
## deployed, see server/README.md).

const SAVE_PATH: String = "user://settings.cfg"
const PROJECT_KEY: String = "kalyeah/network/server_url"

var server_url: String = ""
## The address of a game server on the same phone hotspot / Wi-Fi (plain ws://, no https).
var hotspot_url: String = ""
## Master volume 0..1 and whether button presses buzz the phone (owner-facing settings screen).
var volume: float = 1.0
var vibration: bool = true

var _ui_voice: AudioStreamPlayer


func _ready() -> void:
	KalyeahTheme.apply()
	# every Button in the game clicks (menus, lobby, pick screen)
	_ui_voice = AudioStreamPlayer.new()
	_ui_voice.volume_db = -8.0
	add_child(_ui_voice)
	get_tree().node_added.connect(_on_node_added)
	server_url = ProjectSettings.get_setting(PROJECT_KEY, "") as String
	var file: ConfigFile = ConfigFile.new()
	if file.load(SAVE_PATH) == OK:
		var saved: String = file.get_value("network", "server_url", "") as String
		if not saved.is_empty():
			server_url = saved
		hotspot_url = file.get_value("network", "hotspot_url", "") as String
		volume = clampf(float(file.get_value("audio", "volume", 1.0)), 0.0, 1.0)
		vibration = bool(file.get_value("input", "vibration", true))
	apply_volume()
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		var from_query: String = url_from_query(search as String if search is String else "")
		if not from_query.is_empty():
			server_url = from_query


## `?server=wss%3A%2F%2Fexample.com&x=1` -> "wss://example.com".
static func url_from_query(search: String) -> String:
	var query: String = search.trim_prefix("?")
	for part: String in query.split("&", false):
		var pair: PackedStringArray = part.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "server":
			return pair[1].uri_decode().strip_edges()
	return ""


## A bare host becomes wss://host (ws:// for localhost).
static func normalize_url(raw: String) -> String:
	var url: String = raw.strip_edges()
	if url.is_empty() or url.begins_with("ws://") or url.begins_with("wss://"):
		return url
	url = url.trim_prefix("https://").trim_prefix("http://")
	if url.begins_with("localhost") or is_local_address(url):
		return "ws://" + url
	return "wss://" + url


## True for a private network address (a phone hotspot or home Wi-Fi), which has no https.
static func is_local_address(address: String) -> bool:
	if address.begins_with("127.") or address.begins_with("10.") or address.begins_with("192.168."):
		return true
	if address.begins_with("172."):
		var second: String = address.split(".")[1] if address.split(".").size() > 1 else ""
		return second.is_valid_int() and second.to_int() >= 16 and second.to_int() <= 31
	return false


func save_server_url(url: String) -> void:
	server_url = normalize_url(url)
	var file: ConfigFile = ConfigFile.new()
	file.load(SAVE_PATH)
	file.set_value("network", "server_url", server_url)
	file.save(SAVE_PATH)


func save_hotspot_url(url: String) -> void:
	hotspot_url = normalize_url(url)
	var file: ConfigFile = ConfigFile.new()
	file.load(SAVE_PATH)
	file.set_value("network", "hotspot_url", hotspot_url)
	file.save(SAVE_PATH)


## The address the lobby starts with: the hotspot's or the online server's.
func lobby_url(hotspot: bool) -> String:
	return hotspot_url if hotspot else server_url


## Sets the master bus from `volume` (0 = silent).
func apply_volume() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_volume()
	_save_value("audio", "volume", volume)


func set_vibration(on: bool) -> void:
	vibration = on
	_save_value("input", "vibration", on)


## True where the phone can buzz (a native Android or iOS build; not in a browser).
static func can_vibrate() -> bool:
	return (OS.has_feature("android") or OS.has_feature("ios")) and not OS.has_feature("web")


func vibrate(milliseconds: int = 12) -> void:
	if vibration and can_vibrate():
		Input.vibrate_handheld(milliseconds)


func _save_value(section: String, key: String, value: Variant) -> void:
	var file: ConfigFile = ConfigFile.new()
	file.load(SAVE_PATH)
	file.set_value(section, key, value)
	file.save(SAVE_PATH)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(play_ui, CONNECT_DEFERRED)


func play_ui(id: StringName = &"ui_click") -> void:
	vibrate()
	_ui_voice.stream = SoundBank.get_sound(id)
	_ui_voice.play()
