extends Node
## Network connection for the whole app: owns the GameClient and polls it every
## frame so it survives scene changes (lobby -> loading -> match).

signal connected
signal disconnected

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const NET_RULES: NetRules = preload("res://data/rules/net_rules.tres")

var client: GameClient = GameClient.new(RULES, LAYOUT, NET_RULES)
var is_online: bool = false
## The server this phone runs for a hotspot room it hosts (Android only), or null.
var host: GameServer
var host_code: String = ""


func _ready() -> void:
	client.connection_changed.connect(_on_connection_changed)


func _process(delta: float) -> void:
	client.poll(delta)
	if host != null:
		host.poll(delta)


## A browser can't listen for connections, so only the apps can host a hotspot room.
func can_host() -> bool:
	return not OS.has_feature("web")


## Starts a room server on this phone. The room's code is made from `ip`, the phone's address on
## its hotspot or Wi-Fi, so friends join with the code alone.
func start_host(ip: String) -> Error:
	stop_host()
	host_code = HotspotCode.encode(ip, NET_RULES)
	if host_code.is_empty():
		return ERR_INVALID_PARAMETER
	host = GameServer.new(RULES, LAYOUT, NET_RULES, Time.get_ticks_usec())
	host.rooms.next_code = host_code
	var error: Error = host.listen(NET_RULES.default_port)
	if error != OK:
		host = null
		host_code = ""
	return error


func stop_host() -> void:
	if host != null:
		host.stop()
		host = null
	host_code = ""


## Where this phone's own client connects to reach the server it hosts.
func host_url() -> String:
	return "ws://127.0.0.1:%d" % NET_RULES.default_port


func _on_connection_changed(online: bool) -> void:
	is_online = online
	if online:
		connected.emit()
	else:
		disconnected.emit()
