extends GutTest
## Tumbang Preso (docs/GDD.md "Tumbang Preso"): throw a slipper at the can from behind the
## line, fetch it, the taya tags by touch while the can stands, a tagged kid becomes the
## taya, and the kid tagged the fewest times wins.

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const PRESO: PresoRules = preload("res://data/rules/preso_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0
const TAYA: int = 9


## Player 1 throws, TAYA guards; play has started.
func _sim(thrower_count: int = 1) -> PresoSim:
	var sim: PresoSim = PresoSim.new(RULES, PRESO, LAYOUT, 5)
	for i: int in thrower_count:
		sim.add_player(i + 1)
	sim.add_player(TAYA)
	sim.start(TAYA)
	sim.phase = PresoSim.Phase.PLAYING
	return sim


func _wait(sim: PresoSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


## Throws with an exact aim (a stick past the deadzone) and lets the slipper land.
func _throw_at(sim: PresoSim, id: int, target: Vector2) -> void:
	var state: PresoPlayer = sim.players[id]
	assert_true(sim.throw(state, state.position.direction_to(target)), "threw")
	_wait(sim, PRESO.slipper_range / PRESO.slipper_speed + 0.1)


func test_round_starts_with_the_throwers_behind_the_line_and_the_taya_by_the_can() -> void:
	var sim: PresoSim = _sim(3)
	for id: int in [1, 2, 3]:
		var state: PresoPlayer = sim.players[id]
		assert_true(sim.in_home(state.position), "thrower %d behind the line" % id)
		assert_true(state.has_slipper)
	assert_eq(sim.players[TAYA].position, sim.guard_spot())
	assert_eq(sim.can_state, PresoSim.CanState.STANDING)
	assert_eq(sim.players[TAYA].times_tagged, 0, "starting as the taya is not a tag")


func test_opening_show_freezes_everyone_then_play_starts() -> void:
	var sim: PresoSim = PresoSim.new(RULES, PRESO, LAYOUT, 5)
	var me: PresoPlayer = sim.add_player(1)
	sim.add_player(TAYA)
	sim.start(TAYA)
	assert_eq(sim.phase, PresoSim.Phase.INTRO)
	watch_signals(sim)
	var spot: Vector2 = me.position
	sim.set_input(1, PlayerInput.create(Vector2(1, 0), Vector2.ZERO, 0, 0))
	_wait(sim, PRESO.intro_time - 0.2)
	assert_eq(me.position, spot, "nobody moves in the intro")
	_wait(sim, 0.4)
	assert_eq(sim.phase, PresoSim.Phase.PLAYING)
	assert_signal_emitted(sim, "intro_finished")


func test_a_slipper_that_hits_the_can_knocks_it_over() -> void:
	var sim: PresoSim = _sim()
	watch_signals(sim)
	_throw_at(sim, 1, PRESO.can_spot)
	assert_eq(sim.can_state, PresoSim.CanState.DOWN)
	assert_gt(sim.can_position.distance_to(PRESO.can_spot), 1.0, "the can rolls away")
	assert_lt(sim.can_position.y, PRESO.throw_line_z, "a knocked can stays in front of the line")
	assert_eq(sim.players[1].knockdowns, 1)
	assert_signal_emitted_with_parameters(sim, "can_knocked", [1])
	assert_false(sim.slippers[1].flying, "the slipper drops by the can")


func test_a_miss_lands_at_full_range_and_must_be_fetched() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	var start: Vector2 = me.position
	_throw_at(sim, 1, start + Vector2(-0.6, -1.0) * 10.0)
	assert_eq(sim.can_state, PresoSim.CanState.STANDING)
	var slipper: PresoSim.Slipper = sim.slippers[1]
	assert_false(slipper.flying)
	assert_almost_eq(slipper.position.distance_to(start), PRESO.slipper_range, 0.3)
	assert_false(me.has_slipper)
	assert_false(sim.can_throw(me), "nothing to throw")


func test_walking_over_your_slipper_picks_it_up() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	_throw_at(sim, 1, me.position + Vector2(-0.6, -1.0))
	watch_signals(sim)
	me.position = sim.slippers[1].position + Vector2(0.3, 0.0)
	sim.step(DT)
	assert_true(me.has_slipper)
	assert_false(sim.slippers.has(1))
	assert_signal_emitted_with_parameters(sim, "slipper_picked_up", [1])


func test_you_only_throw_from_behind_the_line() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	me.position = Vector2(0.0, PRESO.throw_line_z - 1.0)
	assert_false(sim.throw(me, Vector2(0, -1)))
	assert_true(me.has_slipper)


func test_the_taya_never_throws() -> void:
	var sim: PresoSim = _sim()
	var taya: PresoPlayer = sim.players[TAYA]
	taya.position = Vector2(0.0, PRESO.throw_line_z + 1.0)
	assert_false(sim.can_throw(taya))


func test_releasing_the_throw_button_throws_and_cancel_does_not() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, 0))
	sim.step(DT)
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2(0, -1), PlayerInput.BTN_AIM_CANCEL, 1))
	sim.step(DT)
	assert_true(me.has_slipper, "cancelled")
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, 2))
	sim.step(DT)
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2(0, -1), 0, 3))
	sim.step(DT)
	assert_false(me.has_slipper, "thrown on release")


func test_a_throw_always_goes_up_the_street() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	var direction: Vector2 = sim.throw_direction(me, Vector2(0.0, 1.0))
	assert_lt(direction.y, 0.0, "backwards is turned forward")
	assert_almost_eq(absf(rad_to_deg(PresoSim.FORWARD.angle_to(direction))), PRESO.max_throw_angle, 0.5)
	assert_true(sim.throw(me, Vector2(1.0, 0.2)))
	_wait(sim, 1.0)
	assert_false(sim.in_home(sim.slippers[1].position), "a slipper never lands back behind the line")


func test_a_tap_aims_at_the_can_with_a_little_spread() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	var at_can: Vector2 = me.position.direction_to(PRESO.can_spot)
	assert_almost_eq(sim.throw_direction(me, Vector2.ZERO).angle_to(at_can), 0.0, 0.001)
	sim.throw(me, Vector2.ZERO)
	var off: float = absf(rad_to_deg(sim.slippers[1].direction.angle_to(at_can)))
	assert_lte(off, PRESO.auto_aim_spread + 0.01)


func test_the_taya_cannot_cross_the_home_line() -> void:
	var sim: PresoSim = _sim()
	var taya: PresoPlayer = sim.players[TAYA]
	sim.set_input(TAYA, PlayerInput.create(Vector2(0, 1), Vector2.ZERO, 0, 0))
	_wait(sim, 4.0)
	assert_false(sim.in_home(taya.position))
	assert_almost_eq(taya.position.y, PRESO.throw_line_z - taya.radius, 0.01)


func test_the_taya_tags_a_thrower_outside_the_line_who_becomes_the_taya() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	me.position = Vector2(2.0, 0.0)
	sim.players[TAYA].position = me.position + Vector2(0.5, 0.0)
	watch_signals(sim)
	sim.step(DT)
	assert_signal_emitted_with_parameters(sim, "player_tagged", [1, TAYA])
	assert_eq(me.times_tagged, 1)
	assert_eq(sim.phase, PresoSim.Phase.TAG_FREEZE)
	_wait(sim, PRESO.tag_freeze_time + 0.1)
	assert_eq(sim.phase, PresoSim.Phase.PLAYING)
	assert_eq(sim.taya_id, 1)
	assert_signal_emitted_with_parameters(sim, "taya_changed", [1])
	assert_eq(me.position, sim.guard_spot(), "the new taya takes the can")
	assert_true(sim.in_home(sim.players[TAYA].position), "the old taya throws now")


func test_behind_the_line_you_are_safe() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	me.position = Vector2(0.0, PRESO.throw_line_z + 0.3)
	sim.players[TAYA].position = Vector2(0.0, PRESO.throw_line_z - 0.4)
	sim.step(DT)
	assert_eq(me.times_tagged, 0)
	assert_eq(sim.phase, PresoSim.Phase.PLAYING)


func test_no_tags_while_the_can_is_down_until_the_taya_stands_it_back_up() -> void:
	var sim: PresoSim = _sim(2)
	_throw_at(sim, 1, PRESO.can_spot)
	assert_eq(sim.can_state, PresoSim.CanState.DOWN)
	var other: PresoPlayer = sim.players[2]
	var taya: PresoPlayer = sim.players[TAYA]
	other.position = Vector2(-6.0, 0.0)
	taya.position = other.position + Vector2(0.3, 0.0)
	sim.step(DT)
	assert_eq(other.times_tagged, 0, "can down: no tagging")
	watch_signals(sim)
	taya.position = sim.can_position
	sim.step(DT)
	assert_eq(sim.can_state, PresoSim.CanState.CARRIED)
	assert_signal_emitted(sim, "can_picked_up")
	taya.position = PRESO.can_spot
	sim.step(DT)
	assert_eq(sim.can_state, PresoSim.CanState.STANDING)
	assert_signal_emitted_with_parameters(sim, "can_set", [TAYA])
	taya.position = other.position + Vector2(0.3, 0.0)
	sim.step(DT)
	assert_eq(other.times_tagged, 1, "can up again: tagged")


func test_holding_your_slipper_too_long_throws_it_for_you() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	_wait(sim, PRESO.shot_clock - 0.5)
	assert_true(me.has_slipper)
	assert_gt(sim.shot_clock_left(1), 0.0)
	_wait(sim, 0.6)
	assert_false(me.has_slipper, "thrown at the can for you")


func test_waiting_at_home_without_your_slipper_too_long_counts_as_a_tag() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	_throw_at(sim, 1, me.position + Vector2(-0.6, -1.0))
	watch_signals(sim)
	_wait(sim, PRESO.home_grace)
	assert_signal_emitted_with_parameters(sim, "player_tagged", [1, PresoSim.TOO_SLOW])
	assert_eq(me.times_tagged, 1)


func test_home_wait_only_counts_behind_the_line_and_resets_on_pick_up() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	_throw_at(sim, 1, me.position + Vector2(-0.6, -1.0))
	var waited: float = me.home_wait
	me.position = Vector2(8.0, 0.0)
	sim.players[TAYA].position = Vector2(-8.0, -8.0)
	_wait(sim, 1.0)
	assert_almost_eq(me.home_wait, waited, 0.001, "out on the street the home clock waits")
	me.position = sim.slippers[1].position
	sim.step(DT)
	assert_eq(me.home_wait, 0.0)


func test_the_match_ends_on_the_clock() -> void:
	var sim: PresoSim = _sim()
	watch_signals(sim)
	sim.match_time = PRESO.match_length - 0.05
	sim.players[1].shot_time = -100.0
	_wait(sim, 0.1)
	assert_eq(sim.phase, PresoSim.Phase.MATCH_OVER)
	assert_signal_emitted(sim, "match_over")
	assert_eq(sim.time_left(), 0.0)


func test_the_clock_stops_in_the_freeze() -> void:
	var sim: PresoSim = _sim()
	sim._tag(sim.players[1], TAYA)
	var before: float = sim.match_time
	_wait(sim, PRESO.tag_freeze_time - 0.2)
	assert_eq(sim.match_time, before)


func test_ranking_is_fewest_tags_then_most_knockdowns_then_least_taya_time() -> void:
	var sim: PresoSim = _sim(3)
	sim.players[1].times_tagged = 2
	sim.players[2].times_tagged = 1
	sim.players[3].times_tagged = 1
	sim.players[3].knockdowns = 2
	sim.players[TAYA].times_tagged = 1
	sim.players[TAYA].knockdowns = 2
	sim.players[TAYA].taya_time = 30.0
	sim.players[3].taya_time = 10.0
	var expected: Array[int] = [3, TAYA, 2, 1]
	assert_eq(sim.ranking(), expected)


func test_every_kid_gets_a_different_character_and_you_keep_yours() -> void:
	var sim: PresoSim = _sim(3)
	sim.assign_characters(1, &"popoy")
	assert_eq(sim.players[1].character_id, &"popoy")
	var seen: Dictionary[StringName, bool] = {}
	for id: int in sim.players:
		seen[sim.players[id].character_id] = true
	assert_eq(seen.size(), 4)


func test_a_cardboard_wall_blocks_kids_and_stops_slippers() -> void:
	var sim: PresoSim = _sim()
	var me: PresoPlayer = sim.players[1]
	var wall: Rect2 = LAYOUT.obstacle_rects()[0]
	me.position = Vector2(wall.get_center().x, wall.end.y + 1.5)
	sim.set_input(1, PlayerInput.create(Vector2(0, -1), Vector2.ZERO, 0, 0))
	_wait(sim, 1.0)
	assert_gt(me.position.y, wall.end.y, "stopped at the wall")
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, 0))
	me.position = Vector2(wall.get_center().x, wall.end.y + 1.5)
	me.shot_time = 0.0
	assert_true(sim.throw(me, Vector2(0, -1)))
	_wait(sim, 1.0)
	var slipper: PresoSim.Slipper = sim.slippers[1]
	assert_false(slipper.flying)
	assert_gt(slipper.position.y, wall.position.y, "dropped in front of the wall")
	assert_lt(slipper.position.distance_to(me.position), 2.0)
