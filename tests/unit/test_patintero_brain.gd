extends GutTest
## Patintero practice bots: runners line up and cross when the guard is away, guards follow the
## runners, and a whole match of bots plays out the same every time from the same seed.

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const PAT: PatinteroRules = preload("res://data/rules/patintero_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _bots(seed_value: int) -> PatinteroSim:
	var sim: PatinteroSim = PatinteroSim.new(RULES, PAT, LAYOUT, seed_value)
	for id: int in range(1, 7):
		sim.add_bot(id, 0 if id <= 3 else 1, PatinteroBrain.new())
	sim.start(0)
	return sim


## Plain players (moved by hand), team 0 running; play has started.
func _plain() -> PatinteroSim:
	var sim: PatinteroSim = PatinteroSim.new(RULES, PAT, LAYOUT, 2)
	for id: int in range(1, 7):
		sim.add_player(id, 0 if id <= 3 else 1)
	sim.start(0)
	sim.phase = PatinteroSim.Phase.PLAYING
	return sim


func _wait(sim: PatinteroSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


func test_zones_count_up_the_grid() -> void:
	var sim: PatinteroSim = _plain()
	assert_eq(PatinteroBrain.zone_of(sim, PAT.start_line_z + 1.0), 0, "home")
	assert_eq(PatinteroBrain.zone_of(sim, (PAT.start_line_z + PAT.guard_lines[0]) / 2.0), 1)
	assert_eq(PatinteroBrain.zone_of(sim, PAT.back_line_z - 1.0), PAT.guard_lines.size() + 2, "past the back line")


func test_a_runner_waits_out_of_reach_while_the_guard_is_on_its_side() -> void:
	var sim: PatinteroSim = _plain()
	var runner: PatinteroPlayer = sim.players[1]
	var middle: float = (PAT.start_line_z + PAT.guard_lines[0]) / 2.0
	runner.position = Vector2(PAT.field_half_width - PAT.bot_side_margin, middle)
	sim.players[4].position.x = runner.position.x
	sim.players[6].position.y = PAT.back_line_z
	var input: PlayerInput = PatinteroBrain.new().think(runner, sim)
	assert_gte(runner.position.y + input.move.y * 0.1, PAT.guard_lines[0] + PAT.tag_distance, "does not walk into the guard")


func test_a_runner_crosses_when_the_guard_is_far_away() -> void:
	var sim: PatinteroSim = _plain()
	var runner: PatinteroPlayer = sim.players[1]
	var x: float = PAT.field_half_width - PAT.bot_side_margin
	runner.position = Vector2(x, PAT.guard_lines[0] + PAT.tag_distance + PAT.bot_line_margin)
	sim.players[4].position.x = -PAT.field_half_width
	sim.players[6].position.y = PAT.back_line_z
	var input: PlayerInput = PatinteroBrain.new().think(runner, sim)
	assert_lt(input.move.y, -0.5, "dashes up the grid")


func test_a_line_guard_follows_the_runner_nearest_its_line() -> void:
	var sim: PatinteroSim = _plain()
	var guard: PatinteroPlayer = sim.players[4]
	sim.players[1].position = Vector2(2.5, PAT.guard_lines[0] + 1.6)
	sim.players[2].position = Vector2(-2.5, PAT.start_line_z + 1.5)
	var input: PlayerInput = PatinteroBrain.new().think(guard, sim)
	assert_gt(input.move.x, 0.5, "slides toward the near runner")


func test_runner_bots_score_in_a_bot_match() -> void:
	var sim: PatinteroSim = _bots(3)
	watch_signals(sim)
	_wait(sim, PAT.intro_time + PAT.turn_time * 2.0)
	assert_signal_emitted(sim, "point_scored")


func test_a_match_of_bots_ends() -> void:
	var sim: PatinteroSim = _bots(5)
	_wait(sim, PAT.intro_time + (PAT.turn_time + PAT.switch_freeze_time) * PAT.max_turns + 1.0)
	assert_eq(sim.phase, PatinteroSim.Phase.MATCH_OVER)


func test_the_same_seed_plays_the_same_match() -> void:
	var first: PatinteroSim = _bots(8)
	var second: PatinteroSim = _bots(8)
	_wait(first, 40.0)
	_wait(second, 40.0)
	for id: int in first.players:
		assert_eq(first.players[id].position, second.players[id].position)
	assert_eq(first.points, second.points)
	assert_eq(first.attacking_team, second.attacking_team)
