class_name HotspotFinder
extends RefCounted
## Tries every candidate address at once with plain WebSockets and reports the first one that
## answers. Drive it with poll(delta) until `url` is set or `failed` is true.

const TIMEOUT: float = 3.0

var url: String = ""
var failed: bool = false

var _probes: Dictionary[String, WebSocketPeer] = {}
var _left: float = TIMEOUT


func start(candidates: PackedStringArray) -> void:
	stop()
	url = ""
	failed = false
	_left = TIMEOUT
	for candidate: String in candidates:
		var probe: WebSocketPeer = WebSocketPeer.new()
		if probe.connect_to_url(candidate) == OK:
			_probes[candidate] = probe
	if _probes.is_empty():
		failed = true


func is_searching() -> bool:
	return not _probes.is_empty()


func poll(delta: float) -> void:
	if _probes.is_empty():
		return
	_left -= delta
	for candidate: String in _probes.keys():
		var probe: WebSocketPeer = _probes[candidate]
		probe.poll()
		var state: WebSocketPeer.State = probe.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			url = candidate
			stop()
			return
		if state == WebSocketPeer.STATE_CLOSED:
			_probes.erase(candidate)
	if _probes.is_empty() or _left <= 0.0:
		stop()
		failed = url.is_empty()


func stop() -> void:
	for candidate: String in _probes:
		_probes[candidate].close()
	_probes.clear()
