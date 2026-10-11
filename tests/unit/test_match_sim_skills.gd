extends GutTest

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 7)


## One tick with the given stick and buttons.
func _tick(sim: MatchSim, id: int, move: Vector2, buttons: int) -> void:
	sim.set_input(id, PlayerInput.create(move, Vector2.ZERO, buttons, sim.tick))
	sim.step(DT)


func _run(sim: MatchSim, id: int, move: Vector2, ticks: int) -> void:
	for i: int in ticks:
		_tick(sim, id, move, 0)



## The pin button: pressed, then released a tick later (a tap dashes the way you face;
## the move vector is only held for the press tick).
func _pin(sim: MatchSim, id: int, move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.ZERO) -> void:
	sim.set_input(id, PlayerInput.create(move, Vector2.ZERO, PlayerInput.BTN_BOOKMARK, sim.tick))
	sim.step(DT)
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, 0, sim.tick))
	sim.step(DT)

func test_skill_numbers_come_from_data() -> void:
	assert_eq(RULES.dash_distance, 5.0)
	assert_eq(RULES.dash_duration, 0.2)
	assert_eq(RULES.dash_stumble, 0.4)
	assert_eq(RULES.dash_cooldown, 8.0)
	assert_eq(RULES.bookmark_blink, 4.6)
	assert_eq(RULES.bookmark_speed_bonus, 0.0)
	assert_eq(RULES.bookmark_tumble, 0.45)
	assert_eq(RULES.bookmark_boost_duration, 4.0)
	assert_eq(RULES.bookmark_cooldown, 14.0)


# ---- HP and tagging ----

func test_damage_reduces_hp() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	sim.damage(1, 30)
	assert_eq(p.hp, 70)
	assert_false(p.tagged)


func test_damage_to_a_tagged_or_unknown_player_is_ignored() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	sim.kill(1)
	watch_signals(sim)
	sim.damage(1, 10)
	sim.damage(99, 10)
	sim.damage(1, 0)
	assert_signal_not_emitted(sim, "player_tagged")
	assert_signal_not_emitted(sim, "player_damaged")
	assert_eq(p.hp, 0)


func test_a_tag_cancels_dash_and_bookmark_effects() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_pin(sim, 1, Vector2(0.0, -1.0))
	assert_true(p.mark_active)
	sim.damage(1, 100)
	assert_false(p.mark_active)
	assert_eq(p.boost_time_left, 0.0)
	assert_eq(p.dash_time_left, 0.0)


# ---- Takbo (dash) ----

func test_dash_travels_five_meters_in_the_stick_direction() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2(0.0, -1.0), 5)
	assert_almost_eq(p.position.y, start.y - 5.0, 0.05)
	assert_almost_eq(p.position.x, start.x, 0.001)


func test_dash_without_stick_goes_where_the_player_faces() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2.ZERO, 5)
	assert_almost_eq(p.position.y, start.y - 5.0, 0.05)


func test_stumble_after_dash_blocks_movement_then_it_recovers() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2(0.0, -1.0), 6)
	var after_dash: Vector2 = p.position
	_run(sim, 1, Vector2(1.0, 0.0), 10)
	assert_eq(p.position, after_dash, "can't move while stumbling")
	_run(sim, 1, Vector2(1.0, 0.0), 10)
	assert_gt(p.position.x, after_dash.x, "moving again after the stumble")


func test_cannot_use_skills_while_stumbling() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2(0.0, -1.0), 7)
	_pin(sim, 1, Vector2(0.0, -1.0))
	assert_false(p.mark_active)


func test_dash_cooldown_is_eight_seconds() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2(1.0, 0.0), PlayerInput.BTN_DASH)
	assert_almost_eq(p.dash_cooldown_left, 8.0, 0.001)
	_run(sim, 1, Vector2.ZERO, 60)
	_tick(sim, 1, Vector2(-1.0, 0.0), PlayerInput.BTN_DASH)
	assert_eq(p.dash_time_left, 0.0, "still on cooldown at 2 s")
	_run(sim, 1, Vector2.ZERO, 200)
	_tick(sim, 1, Vector2(-1.0, 0.0), PlayerInput.BTN_DASH)
	assert_gt(p.dash_time_left, 0.0, "ready again after 8 s")


func test_dash_stops_at_an_obstacle() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var cover: Rect2 = LAYOUT.obstacle_rects()[0]
	p.position = Vector2(cover.get_center().x, cover.end.y + 1.5)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	_run(sim, 1, Vector2(0.0, -1.0), 8)
	assert_almost_eq(p.position.y, cover.end.y + p.radius, 0.05)


# ---- Bookmark ----

func test_the_pin_blinks_a_short_way_tumbles_and_leaves_a_pin() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_pin(sim, 1, Vector2.ZERO)
	assert_almost_eq(p.position.y, start.y - RULES.bookmark_blink, 0.01)
	assert_gt(p.stumble_time_left, 0.0, "tumbles after the blink")
	var tumbling_at: Vector2 = p.position
	_run(sim, 1, Vector2(1.0, 0.0), 5)
	assert_eq(p.position, tumbling_at, "can't move while tumbling")
	assert_true(p.mark_active)
	assert_eq(p.mark_position, start)
	assert_eq(p.bookmark_cooldown_left, 0.0, "the cooldown waits until you are back at the mark")
	assert_false(p.bookmark_ready(), "but it can't be used again while out on the mark")


func test_bookmark_returns_to_the_mark_after_four_seconds() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_pin(sim, 1, Vector2.ZERO)
	_run(sim, 1, Vector2.ZERO, 110)
	assert_true(p.mark_active, "boost still running at ~3.7 s")
	_run(sim, 1, Vector2.ZERO, 15)
	assert_false(p.mark_active)
	assert_eq(p.position, start)


func test_bookmark_return_is_a_data_toggle() -> void:
	var rules: GameRules = RULES.duplicate() as GameRules
	rules.bookmark_returns = false
	var sim: MatchSim = MatchSim.new(rules, LAYOUT, 7)
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_pin(sim, 1, Vector2.ZERO)
	_run(sim, 1, Vector2.ZERO, 130)
	assert_almost_eq(p.position.y, start.y - RULES.bookmark_blink, 0.01, "stays where it blinked")


func test_bookmark_cooldown_starts_only_after_returning_to_the_mark() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_pin(sim, 1, Vector2.ZERO)
	_run(sim, 1, Vector2.ZERO, 100)
	assert_eq(p.bookmark_cooldown_left, 0.0, "not counting while out on the mark")
	_run(sim, 1, Vector2.ZERO, 25)
	assert_false(p.mark_active, "back at the pin after 4 s")
	assert_almost_eq(p.bookmark_cooldown_left, 14.0, 0.25, "the 14 s cooldown starts now")
	_run(sim, 1, Vector2.ZERO, 400)
	_pin(sim, 1, Vector2.ZERO)
	assert_false(p.mark_active, "still on cooldown ~13.4 s after the return")
	_run(sim, 1, Vector2.ZERO, 30)
	_pin(sim, 1, Vector2.ZERO)
	assert_true(p.mark_active, "ready 14 s after the return")


func test_pressing_the_pin_again_returns_early() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	_pin(sim, 1, Vector2.ZERO)
	_run(sim, 1, Vector2(1.0, 0.0), 40)
	assert_true(p.mark_active)
	_pin(sim, 1, Vector2.ZERO)
	assert_false(p.mark_active, "back at once")
	assert_eq(p.position, start)
	assert_almost_eq(p.bookmark_cooldown_left, RULES.bookmark_cooldown, 0.1, "cooldown starts on the early return")


func test_dying_out_on_a_mark_starts_the_bookmark_cooldown() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_pin(sim, 1, Vector2.ZERO)
	sim.kill(1)
	assert_false(p.mark_active)
	assert_almost_eq(p.bookmark_cooldown_left, 14.0, 0.001)


func test_holding_dash_through_its_cooldown_does_not_precast() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	for i: int in 300:
		_tick(sim, 1, Vector2.ZERO, PlayerInput.BTN_DASH)
	assert_eq(p.dash_cooldown_left, 0.0)
	assert_eq(p.dash_time_left, 0.0, "the held button never fires on its own")
	_tick(sim, 1, Vector2.ZERO, 0)
	_tick(sim, 1, Vector2(0.0, -1.0), PlayerInput.BTN_DASH)
	assert_gt(p.dash_time_left, 0.0, "a fresh press works")


func test_holding_bookmark_through_its_cooldown_does_not_precast() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	_pin(sim, 1, Vector2.ZERO)
	_run(sim, 1, Vector2.ZERO, 200)
	assert_false(p.mark_active, "back at the pin, on cooldown")
	assert_false(p.bookmark_ready())
	# pressed during the cooldown and held through its end: nothing is queued
	for i: int in 600:
		sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_BOOKMARK, sim.tick))
		sim.step(DT)
	assert_true(p.bookmark_ready())
	assert_false(p.mark_active)
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick))
	sim.step(DT)
	assert_false(p.mark_active, "letting go afterwards does not cast")


func test_bookmark_blink_stops_at_an_obstacle() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var cover: Rect2 = LAYOUT.obstacle_rects()[0]
	p.position = Vector2(cover.get_center().x, cover.end.y + 2.5)
	_pin(sim, 1, Vector2.ZERO)
	assert_almost_eq(p.position.y, cover.end.y + p.radius, 0.05)


# ---- the pin dash: tap = facing, drag = chosen direction ---------------------------------

func test_a_tap_on_the_pin_dashes_the_way_the_player_faces() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.facing = Vector2(1.0, 0.0)
	var start: Vector2 = p.position
	_pin(sim, 1, Vector2.ZERO)
	assert_almost_eq(p.position.x - start.x, RULES.bookmark_blink, 0.05, "dashed to the right, where it faced")
	assert_almost_eq(p.position.y, start.y, 0.05)


func test_dragging_the_pin_chooses_the_dash_direction() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	p.position = Vector2(0.0, -4.0)
	p.facing = Vector2(0.0, -1.0)
	var start: Vector2 = p.position
	_pin(sim, 1, Vector2.ZERO, Vector2(-1.0, 0.0))
	assert_almost_eq(start.x - p.position.x, RULES.bookmark_blink, 0.05, "dashed left, where it was aimed")
	assert_almost_eq(p.facing.x, -1.0, 0.01)


func test_cancelling_the_pin_aim_does_not_dash() -> void:
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_BOOKMARK, sim.tick))
	sim.step(DT)
	sim.set_input(1, PlayerInput.create(Vector2.ZERO, Vector2(-1.0, 0.0), PlayerInput.BTN_AIM_CANCEL, sim.tick))
	sim.step(DT)
	assert_eq(p.position, start)
	assert_false(p.mark_active)
