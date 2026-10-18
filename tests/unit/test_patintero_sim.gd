extends GutTest
## Patintero (docs/GDD.md "Patintero"): taggers stay on their lines, a touch inside the grid
## catches a runner and switches the teams, every round trip scores, first to 3 wins.

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const PAT: PatinteroRules = preload("res://data/rules/patintero_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


## Team 0 (ids 1-3) runs, team 1 (ids 4-6) tags; play has started.
func _sim() -> PatinteroSim:
	var sim: PatinteroSim = PatinteroSim.new(RULES, PAT, LAYOUT, 4)
	for id: int in range(1, 7):
		sim.add_player(id, 0 if id <= 3 else 1)
	sim.start(0)
	sim.phase = PatinteroSim.Phase.PLAYING
	return sim


func _wait(sim: PatinteroSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


func _push(sim: PatinteroSim, id: int, move: Vector2, seconds: float) -> void:
	sim.set_input(id, PlayerInput.create(move, Vector2.ZERO, 0, 0))
	_wait(sim, seconds)
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, 0))


func test_a_turn_starts_with_runners_home_and_taggers_on_their_lines() -> void:
	var sim: PatinteroSim = _sim()
	for id: int in [1, 2, 3]:
		assert_true(sim.is_runner(id))
		assert_true(sim.in_home(sim.players[id].position))
	var line_guards: Array[float] = []
	for id: int in [4, 5]:
		assert_eq(sim.players[id].role, PatinteroPlayer.Role.LINE_GUARD)
		line_guards.append(sim.players[id].position.y)
	assert_eq(line_guards, PAT.guard_lines, "one guard on each line across")
	assert_eq(sim.players[6].role, PatinteroPlayer.Role.CENTRE_GUARD)
	assert_eq(sim.players[6].position.x, 0.0)
	assert_eq(sim.turn_left, PAT.turn_time)


func test_the_opening_show_freezes_everyone_then_play_starts() -> void:
	var sim: PatinteroSim = PatinteroSim.new(RULES, PAT, LAYOUT, 4)
	var me: PatinteroPlayer = sim.add_player(1, 0)
	sim.add_player(2, 1)
	sim.start(0)
	watch_signals(sim)
	var spot: Vector2 = me.position
	sim.set_input(1, PlayerInput.create(Vector2(0, -1), Vector2.ZERO, 0, 0))
	_wait(sim, PAT.intro_time - 0.2)
	assert_eq(me.position, spot)
	_wait(sim, 0.4)
	assert_eq(sim.phase, PatinteroSim.Phase.PLAYING)
	assert_signal_emitted(sim, "intro_finished")


func test_a_line_guard_only_slides_along_its_line() -> void:
	var sim: PatinteroSim = _sim()
	var guard: PatinteroPlayer = sim.players[4]
	_push(sim, 4, Vector2(0.7, 0.7).normalized(), 3.0)
	assert_eq(guard.position.y, PAT.guard_lines[0], "never leaves the line")
	assert_almost_eq(guard.position.x, PAT.field_half_width, 0.01, "stops at the side line")


func test_the_centre_guard_only_moves_up_and_down_the_middle_line() -> void:
	var sim: PatinteroSim = _sim()
	var centre: PatinteroPlayer = sim.players[6]
	_push(sim, 6, Vector2(1, -1).normalized(), 5.0)
	assert_eq(centre.position.x, 0.0)
	assert_almost_eq(centre.position.y, PAT.back_line_z, 0.01, "stops at the back line")
	_push(sim, 6, Vector2(0, 1), 6.0)
	assert_almost_eq(centre.position.y, PAT.start_line_z, 0.01, "and at the start line")


func test_a_tagger_touching_a_runner_in_the_grid_catches_and_switches_the_teams() -> void:
	var sim: PatinteroSim = _sim()
	var runner: PatinteroPlayer = sim.players[1]
	runner.position = Vector2(-1.0, PAT.guard_lines[0] + 0.6)
	sim.players[4].position.x = -1.0
	watch_signals(sim)
	sim.step(DT)
	assert_signal_emitted_with_parameters(sim, "runner_caught", [1, 4])
	assert_eq(sim.phase, PatinteroSim.Phase.SWITCH_FREEZE)
	_wait(sim, PAT.switch_freeze_time + 0.1)
	assert_eq(sim.phase, PatinteroSim.Phase.PLAYING)
	assert_eq(sim.attacking_team, 1)
	assert_signal_emitted_with_parameters(sim, "sides_switched", [1])
	assert_false(sim.is_runner(1), "the catchers run now")
	assert_true(sim.is_runner(4))
	assert_true(sim.in_home(sim.players[4].position))


func test_out_of_reach_is_safe() -> void:
	var sim: PatinteroSim = _sim()
	sim.players[1].position = Vector2(-1.0, PAT.guard_lines[0] + PAT.tag_distance + 0.1)
	sim.players[4].position.x = -1.0
	sim.step(DT)
	assert_eq(sim.phase, PatinteroSim.Phase.PLAYING)


func test_nobody_is_caught_at_home_or_past_the_back_line() -> void:
	var sim: PatinteroSim = _sim()
	var centre: PatinteroPlayer = sim.players[6]
	centre.position = Vector2(0.0, PAT.start_line_z)
	sim.players[1].position = Vector2(0.3, PAT.start_line_z + 0.3)
	sim.step(DT)
	assert_eq(sim.phase, PatinteroSim.Phase.PLAYING, "home is safe")
	centre.position = Vector2(0.0, PAT.back_line_z)
	sim.players[1].position = Vector2(0.3, PAT.back_line_z - 0.3)
	sim.step(DT)
	assert_eq(sim.phase, PatinteroSim.Phase.PLAYING, "past the back line is safe")


func test_stepping_past_a_side_line_in_the_grid_is_caught() -> void:
	var sim: PatinteroSim = _sim()
	var runner: PatinteroPlayer = sim.players[1]
	runner.position = Vector2(PAT.field_half_width - 0.2, (PAT.guard_lines[0] + PAT.guard_lines[1]) / 2.0)
	watch_signals(sim)
	_push(sim, 1, Vector2(1, 0), 0.3)
	assert_signal_emitted_with_parameters(sim, "runner_caught", [1, PatinteroSim.OUT_OF_BOUNDS])


func test_outside_the_grid_the_side_lines_are_walls() -> void:
	var sim: PatinteroSim = _sim()
	var runner: PatinteroPlayer = sim.players[1]
	_push(sim, 1, Vector2(1, 0), 2.0)
	assert_true(sim.in_home(runner.position))
	assert_lte(runner.position.x, PAT.field_half_width)
	assert_eq(sim.phase, PatinteroSim.Phase.PLAYING)


func test_a_round_trip_scores_a_point_for_the_team() -> void:
	var sim: PatinteroSim = _sim()
	var runner: PatinteroPlayer = sim.players[1]
	watch_signals(sim)
	runner.position = Vector2(-3.0, PAT.back_line_z - 0.5)
	sim.step(DT)
	assert_true(runner.reached_back)
	runner.position = Vector2(-3.0, PAT.start_line_z + 0.5)
	sim.step(DT)
	assert_signal_emitted_with_parameters(sim, "point_scored", [1, 0])
	assert_eq(sim.points[0], 1)
	assert_eq(sim.points[1], 0)
	assert_eq(runner.points, 1)
	assert_false(runner.reached_back, "the next trip starts over")
	assert_eq(sim.phase, PatinteroSim.Phase.PLAYING, "a point does not end the turn")


func test_going_home_without_reaching_the_back_scores_nothing() -> void:
	var sim: PatinteroSim = _sim()
	var runner: PatinteroPlayer = sim.players[1]
	runner.position = Vector2(-3.0, 0.0)
	sim.step(DT)
	runner.position = Vector2(-3.0, PAT.start_line_z + 0.5)
	sim.step(DT)
	assert_eq(sim.points[0], 0)
	assert_eq(sim.points[1], 0)


func test_every_runner_who_makes_the_trip_scores() -> void:
	var sim: PatinteroSim = _sim()
	for id: int in [1, 2]:
		sim.players[id].position = Vector2(-3.0 + id, PAT.back_line_z - 0.5)
	sim.step(DT)
	for id: int in [1, 2]:
		sim.players[id].position = Vector2(-3.0 + id, PAT.start_line_z + 0.5)
	sim.step(DT)
	assert_eq(sim.points[0], 2)


func test_the_first_team_to_three_points_wins() -> void:
	var sim: PatinteroSim = _sim()
	sim.points[0] = PAT.points_to_win - 1
	var runner: PatinteroPlayer = sim.players[1]
	watch_signals(sim)
	runner.reached_back = true
	runner.position = Vector2(-3.0, PAT.start_line_z + 0.5)
	sim.step(DT)
	assert_eq(sim.phase, PatinteroSim.Phase.MATCH_OVER)
	assert_eq(sim.winner, 0)
	assert_signal_emitted_with_parameters(sim, "match_over", [0])


func test_the_turn_clock_running_out_switches_the_teams() -> void:
	var sim: PatinteroSim = _sim()
	watch_signals(sim)
	sim.turn_left = 0.05
	_wait(sim, 0.1)
	assert_signal_emitted(sim, "turn_timed_out")
	_wait(sim, PAT.switch_freeze_time + 0.1)
	assert_eq(sim.attacking_team, 1)
	assert_almost_eq(sim.turn_left, PAT.turn_time, 0.2, "a fresh clock")


func test_after_the_turn_limit_the_most_points_win_or_it_is_a_draw() -> void:
	var sim: PatinteroSim = _sim()
	sim.points = [1, 2]
	sim.turns_played = PAT.max_turns - 1
	sim.turn_left = 0.01
	_wait(sim, PAT.switch_freeze_time + 0.2)
	assert_eq(sim.phase, PatinteroSim.Phase.MATCH_OVER)
	assert_eq(sim.winner, 1)
	var level: PatinteroSim = _sim()
	level.points = [2, 2]
	level.turns_played = PAT.max_turns - 1
	level.turn_left = 0.01
	_wait(level, PAT.switch_freeze_time + 0.2)
	assert_eq(level.winner, -1, "a draw")


func test_no_input_moves_nobody() -> void:
	var sim: PatinteroSim = _sim()
	var before: Array[Vector2] = []
	for id: int in sim.players:
		before.append(sim.players[id].position)
	_wait(sim, 1.0)
	var index: int = 0
	for id: int in sim.players:
		assert_eq(sim.players[id].position, before[index])
		index += 1


func test_a_team_never_has_the_same_kid_twice_and_you_keep_yours() -> void:
	var sim: PatinteroSim = _sim()
	sim.assign_characters(1, &"inday")
	assert_eq(sim.players[1].character_id, &"inday")
	for team: int in [0, 1]:
		var seen: Dictionary[StringName, bool] = {}
		for id: int in sim.players:
			if sim.players[id].team == team:
				seen[sim.players[id].character_id] = true
		assert_eq(seen.size(), 3, "team %d has three different kids" % team)
