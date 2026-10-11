extends GutTest
## One-handed movement: phone tilt -> stick (TiltInput, data/rules/tilt_rules.tres).

const RULES: TiltRules = preload("res://data/rules/tilt_rules.tres")
const DT: float = 1.0 / 60.0


func _settled(tilt: TiltInput, reading: Vector2) -> Vector2:
	var value: Vector2 = Vector2.ZERO
	for i: int in 120:
		value = tilt.update(reading, DT)
	return value


func test_gentle_numbers_from_data() -> void:
	assert_between(RULES.deadzone_degrees, 2.0, 6.0, "a still hand stays still")
	assert_between(RULES.full_tilt_degrees, 10.0, 20.0, "full speed without tipping the phone far")
	assert_gt(RULES.smoothing_rate, 0.0)
	assert_eq(RULES.sensitivity_steps.size(), 3, "low, medium, high")


func test_the_first_reading_is_level() -> void:
	var tilt: TiltInput = TiltInput.new(RULES)
	assert_eq(_settled(tilt, Vector2(10.0, 55.0)), Vector2.ZERO)


func test_dead_zone_then_a_gentle_ramp_to_full_speed() -> void:
	var tilt: TiltInput = TiltInput.new(RULES)
	assert_eq(tilt.shape(Vector2(RULES.deadzone_degrees - 0.5, 0.0)), Vector2.ZERO)
	var half: float = (RULES.deadzone_degrees + RULES.full_tilt_degrees) / 2.0
	assert_almost_eq(tilt.shape(Vector2(half, 0.0)).x, 0.5, 0.01, "half way: half speed")
	assert_almost_eq(tilt.shape(Vector2(RULES.full_tilt_degrees, 0.0)).length(), 1.0, 0.001)
	assert_almost_eq(tilt.shape(Vector2(45.0, 0.0)).length(), 1.0, 0.001, "never faster than full")


func test_directions_match_the_screen() -> void:
	var tilt: TiltInput = TiltInput.new(RULES)
	tilt.update(Vector2(0.0, 50.0), DT)
	var forward: Vector2 = _settled(tilt, Vector2(0.0, 50.0 - 20.0))
	assert_almost_eq(forward.y, -1.0, 0.02, "top tipped away: up the screen")
	var right: Vector2 = _settled(tilt, Vector2(20.0, 50.0))
	assert_almost_eq(right.x, 1.0, 0.02, "right side down: right")


func test_smoothing_eases_in_instead_of_jumping() -> void:
	var tilt: TiltInput = TiltInput.new(RULES)
	tilt.update(Vector2.ZERO, DT)
	var first: Vector2 = tilt.update(Vector2(30.0, 0.0), DT)
	assert_between(first.x, 0.01, 0.5, "one frame in: still easing")
	assert_almost_eq(_settled(tilt, Vector2(30.0, 0.0)).x, 1.0, 0.02)


func test_no_sensor_means_no_movement() -> void:
	var tilt: TiltInput = TiltInput.new(RULES)
	tilt.update(Vector2.ZERO, DT)
	_settled(tilt, Vector2(30.0, 0.0))
	for i: int in 120:
		tilt.update(null, DT)
	assert_eq(tilt.value, Vector2.ZERO)


func test_sensitivity_scales_the_tilt_and_recenter_resets_level() -> void:
	var tilt: TiltInput = TiltInput.new(RULES)
	var offset: Vector2 = Vector2(8.0, 0.0)
	var medium: float = tilt.shape(offset).x
	tilt.sensitivity = RULES.sensitivity_steps[2]
	assert_gt(tilt.shape(offset).x, medium, "high: less tilt for the same speed")
	tilt.update(Vector2.ZERO, DT)
	tilt.recenter()
	assert_eq(_settled(tilt, Vector2(25.0, 30.0)), Vector2.ZERO, "the new hold is level")
