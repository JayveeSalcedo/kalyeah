extends GutTest


func test_combine_caps_length_at_one() -> void:
	assert_eq(LocalInput.combine(Vector2(1.0, 0.0), Vector2(1.0, 0.0)), Vector2(1.0, 0.0))
	assert_almost_eq(LocalInput.combine(Vector2(1.0, 0.0), Vector2(0.0, -1.0)).length(), 1.0, 0.0001)
	assert_eq(LocalInput.combine(Vector2(0.2, 0.0), Vector2.ZERO), Vector2(0.2, 0.0))


func test_other_team_stick_is_rotated_back() -> void:
	assert_eq(LocalInput.to_world(Vector2(0.5, -1.0), false), Vector2(0.5, -1.0))
	assert_eq(LocalInput.to_world(Vector2(0.5, -1.0), true), Vector2(-0.5, 1.0))


func test_keyboard_vector_is_zero_without_keys() -> void:
	assert_eq(LocalInput.keyboard_vector(), Vector2.ZERO)


func test_keyboard_buttons_is_zero_without_keys() -> void:
	assert_eq(LocalInput.keyboard_buttons(), 0)


func test_touch_button_hit_area_is_round() -> void:
	var size: Vector2 = Vector2(128.0, 128.0)
	assert_true(TouchButton.hit_test(Vector2(64.0, 64.0), size))
	assert_true(TouchButton.hit_test(Vector2(64.0, 5.0), size), "near the top edge")
	assert_false(TouchButton.hit_test(Vector2(2.0, 2.0), size), "corner is outside the circle")
	assert_false(TouchButton.hit_test(Vector2(300.0, 64.0), size))


func test_touch_button_cooldown_fraction() -> void:
	var button: TouchButton = autofree(TouchButton.new()) as TouchButton
	button.set_cooldown(4.0, 8.0)
	assert_eq(button.cooldown_fraction, 0.5)
	button.set_cooldown(0.0, 8.0)
	assert_eq(button.cooldown_fraction, 0.0)
	button.set_cooldown(9.0, 8.0)
	assert_eq(button.cooldown_fraction, 1.0)


func test_holding_one_skill_button_locks_every_other_one() -> void:
	var held: AimButton = autofree(AimButton.new()) as AimButton
	var other: AimButton = autofree(AimButton.new()) as AimButton
	var plain: TouchButton = autofree(TouchButton.new()) as TouchButton
	add_child(held)
	add_child(other)
	add_child(plain)
	assert_true(other.can_press())
	held._begin(Vector2.ZERO)
	assert_true(held.can_press(), "the held button itself stays usable")
	assert_false(other.can_press(), "no second weapon")
	assert_false(plain.can_press(), "no other button either")
	held._finish(false)
	assert_true(other.can_press(), "free again after the release")
	assert_true(plain.can_press())


func test_the_tilt_moves_and_adds_to_the_keyboard_and_debug_stick() -> void:
	var input: MatchInput = MatchInput.new()
	input.tilt = Vector2(0.0, -1.0)
	var built: PlayerInput = input.build(false, func(_slot: int) -> Vector2: return Vector2.ZERO, 1)
	assert_almost_eq(built.move.y, -1.0, 0.001, "tilt the top away: run up the screen")
	input.build(true, func(_slot: int) -> Vector2: return Vector2.ZERO, 2)
	built = input.build(true, func(_slot: int) -> Vector2: return Vector2.ZERO, 3)
	assert_almost_eq(built.move.y, 1.0, 0.001, "the other team's view is turned around")


func test_the_settings_menu_pauses_the_controls() -> void:
	var hud: MatchHud = autofree(MatchHud.new()) as MatchHud
	add_child(hud)
	assert_false(hud.menu.visible)
	assert_not_null(hud.settings_button.texture_normal, "painted gear")
	hud.toggle_menu()
	assert_true(hud.menu.visible)
	assert_false(hud.controls_active(), "no casting through the menu")
	hud.toggle_menu()
	assert_true(hud.controls_active())


func test_one_handed_no_stick_and_the_two_skills_in_a_row_at_the_bottom() -> void:
	var screen_root: Control = autofree(Control.new()) as Control
	screen_root.size = Vector2(720.0, 1280.0)
	add_child(screen_root)
	var hud: MatchHud = MatchHud.new()
	screen_root.add_child(hud)
	hud.layout_controls()
	assert_false("joystick" in hud, "no movement button: tilt moves you")
	assert_eq(hud.aim_buttons.size(), 2, "weapon 1 and weapon 2 only")
	var screen: Vector2 = hud.get_rect().size
	var left: Vector2 = hud.weapon_buttons[0].get_rect().get_center()
	var right: Vector2 = hud.weapon_buttons[1].get_rect().get_center()
	assert_almost_eq(left.y, right.y, 0.5, "in one row")
	assert_gt(left.y, screen.y * 0.8, "at the bottom")
	assert_lt(left.x, right.x)
	assert_almost_eq(left.x + right.x, screen.x, 1.0, "centred")
	for button: AimButton in hud.weapon_buttons:
		assert_lt(button.get_rect().end.y, screen.y, "on screen")


func test_the_score_sits_at_the_top_right() -> void:
	var screen_root: Control = autofree(Control.new()) as Control
	screen_root.size = Vector2(720.0, 1280.0)
	add_child(screen_root)
	var hud: MatchHud = MatchHud.new()
	screen_root.add_child(hud)
	var score: Rect2 = hud.scoreboard.get_global_rect()
	assert_gt(score.position.x, 720.0 / 2.0, "right half")
	assert_almost_eq(score.end.x, 720.0 - MatchHud.MARGIN, 1.0, "against the right edge")
	assert_lt(score.position.y, 200.0, "at the top")


func test_the_menu_has_no_handedness_switch() -> void:
	var hud: MatchHud = autofree(MatchHud.new()) as MatchHud
	add_child(hud)
	assert_false("left_button" in hud.menu, "controls are fixed")
	assert_false("left_handed" in Settings)


func test_the_stick_follows_the_turned_camera() -> void:
	# camera behind-right (45 degrees): screen up heads forward-left in the world
	var up: Vector2 = LocalInput.to_world(Vector2(0.0, -1.0), false, 45.0)
	assert_almost_eq(up.x, -0.7071, 0.001)
	assert_almost_eq(up.y, -0.7071, 0.001)
	for stick: Vector2 in [Vector2(0.3, -0.8), Vector2(-1.0, 0.0), Vector2(0.6, 0.6)]:
		for flip: bool in [false, true]:
			var back: Vector2 = LocalInput.to_screen(LocalInput.to_world(stick, flip, 45.0), flip, 45.0)
			assert_almost_eq(back.x, stick.x, 0.0001)
			assert_almost_eq(back.y, stick.y, 0.0001)
