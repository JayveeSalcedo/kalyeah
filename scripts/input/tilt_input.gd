class_name TiltInput
extends RefCounted
## One-handed movement: tilting the phone moves the kid (no on-screen stick).
## Reads the phone's orientation (the browser's deviceorientation on the web,
## the gravity sensor on Android), measures it from the way the phone was held
## when the match started, and turns it into a stick vector in screen terms
## (x = right, y = down the screen): tilt the top away to run up the screen, tilt
## right to run right. A dead zone keeps a still hand still, full speed comes at a
## gentle angle, and the result is smoothed so hand shake does not jitter.

enum Status { OK, WAITING, DENIED, NONE }

var rules: TiltRules
## Multiplier from the player's sensitivity setting.
var sensitivity: float = 1.0
## The smoothed stick vector (length 0..1).
var value: Vector2 = Vector2.ZERO
## The orientation (roll, pitch in degrees) that counts as "level".
var neutral: Vector2 = Vector2.ZERO
var has_neutral: bool = false


func _init(p_rules: TiltRules) -> void:
	rules = p_rules


## Next reading counts as level again (match start, after a rescue, menu button).
func recenter() -> void:
	has_neutral = false


## Feeds one reading (roll, pitch in degrees; null when there is none) and returns
## the smoothed stick vector.
func update(reading: Variant, delta: float) -> Vector2:
	var target: Vector2 = Vector2.ZERO
	if reading != null:
		var angles: Vector2 = reading as Vector2
		if not has_neutral:
			neutral = angles
			has_neutral = true
		target = shape(angles - neutral)
	var blend: float = 1.0 - exp(-rules.smoothing_rate * delta)
	value = value.lerp(target, blend)
	if value.length() < 0.01:
		value = Vector2.ZERO
	return value


## Tilt away from level (roll right +, pitch: top tipped away -) -> stick vector.
## Inside the dead zone it is zero; it grows to full at `full_tilt_degrees`.
func shape(offset: Vector2) -> Vector2:
	var angle: float = offset.length() * sensitivity
	if angle <= rules.deadzone_degrees or offset.length() < 0.0001:
		return Vector2.ZERO
	var amount: float = clampf(
		(angle - rules.deadzone_degrees) / (rules.full_tilt_degrees - rules.deadzone_degrees), 0.0, 1.0
	)
	return offset.normalized() * amount


## The phone's orientation as (roll, pitch) in degrees, or null without a sensor.
## Pitch grows as the phone stands up (0 = flat, 90 = upright), like the browser's beta.
static func read_device() -> Variant:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"(window.kalyeahTilt && window.kalyeahTilt.ok) ? (window.kalyeahTilt.gamma + ',' + window.kalyeahTilt.beta) : ''", true
		)
		var text: String = raw as String if raw is String else ""
		var parts: PackedStringArray = text.split(",")
		if parts.size() != 2:
			return null
		return Vector2(parts[0].to_float(), parts[1].to_float())
	if OS.has_feature("android"):
		var gravity: Vector3 = Input.get_gravity()
		if gravity.length() < 0.1:
			return null
		var roll: float = rad_to_deg(atan2(-gravity.x, -gravity.z))
		var pitch: float = rad_to_deg(atan2(-gravity.y, -gravity.z))
		return Vector2(roll, pitch)
	return null


## What the HUD should say about tilt: working, waiting for the first tap /
## permission, blocked by the player, or no sensor (desktop: use the keyboard).
static func device_status() -> Status:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"window.kalyeahTilt ? (window.kalyeahTilt.ok ? 'ok' : (window.kalyeahTilt.denied ? 'denied' : 'waiting')) : 'none'", true
		)
		match raw as String if raw is String else "none":
			"ok":
				return Status.OK
			"denied":
				return Status.DENIED
			"waiting":
				return Status.WAITING
		return Status.NONE
	if OS.has_feature("android"):
		return Status.OK if Input.get_gravity().length() > 0.1 else Status.WAITING
	return Status.NONE


## Web: starts listening to the phone's orientation. iPhones only allow that after
## the player taps, so the first tap anywhere asks for permission.
static func install_web_listener() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
(function () {
  if (window.kalyeahTilt) return;
  var tilt = window.kalyeahTilt = {gamma: 0, beta: 0, ok: false, asked: false, denied: false};
  function onTilt(e) {
    if (e.beta === null || e.gamma === null) return;
    tilt.gamma = e.gamma; tilt.beta = e.beta; tilt.ok = true;
  }
  function listen() { window.addEventListener('deviceorientation', onTilt); }
  var api = window.DeviceOrientationEvent;
  if (api && typeof api.requestPermission === 'function') {
    var ask = function () {
      if (tilt.asked) return;
      tilt.asked = true;
      api.requestPermission().then(function (answer) {
        if (answer === 'granted') { listen(); } else { tilt.denied = true; }
      }).catch(function () { tilt.asked = false; });
    };
    document.addEventListener('touchend', ask);
    document.addEventListener('click', ask);
  } else if (api) {
    listen();
  }
})();
""", true)
