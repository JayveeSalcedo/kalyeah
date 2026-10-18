extends GutTest
## Tumbang Preso practice bots: they throw, fetch, guard and fix the can, and a whole match
## of bots plays out the same every time from the same seed.

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const PRESO: PresoRules = preload("res://data/rules/preso_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _bots(seed_value: int, count: int = 4) -> PresoSim:
	var sim: PresoSim = PresoSim.new(RULES, PRESO, LAYOUT, seed_value)
	for id: int in range(1, count + 1):
		sim.add_bot(id, PresoBrain.new())
	sim.start(1)
	return sim


## A taya bot (id 1) and a thrower (id 2) the test moves by hand; play has started.
func _duel() -> PresoSim:
	var sim: PresoSim = PresoSim.new(RULES, PRESO, LAYOUT, 3)
	sim.add_bot(1, PresoBrain.new())
	sim.add_player(2)
	sim.start(1)
	sim.phase = PresoSim.Phase.PLAYING
	return sim


func _wait(sim: PresoSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


func test_a_thrower_bot_throws_after_a_moment() -> void:
	var sim: PresoSim = _bots(3)
	watch_signals(sim)
	_wait(sim, PRESO.intro_time + PRESO.bot_reaction_max + 0.3)
	assert_signal_emitted(sim, "slipper_thrown")


func test_a_taya_bot_puts_a_knocked_can_back() -> void:
	var sim: PresoSim = _duel()
	var thrower: PresoPlayer = sim.players[2]
	sim.throw(thrower, thrower.position.direction_to(PRESO.can_spot))
	_wait(sim, 1.0)
	assert_eq(sim.can_state, PresoSim.CanState.DOWN)
	watch_signals(sim)
	_wait(sim, 6.0)
	assert_signal_emitted(sim, "can_set")


func test_a_taya_bot_chases_a_thrower_near_the_can() -> void:
	var sim: PresoSim = _duel()
	var thrower: PresoPlayer = sim.players[2]
	thrower.position = PRESO.can_spot + Vector2(3.0, 0.0)
	var taya: PresoPlayer = sim.players[1]
	var input: PlayerInput = PresoBrain.new().think(taya, sim)
	assert_gt(input.move.dot(taya.position.direction_to(thrower.position)), 0.9, "runs at the thrower")


func test_a_thrower_bot_waits_at_home_while_the_taya_stands_on_its_slipper() -> void:
	var sim: PresoSim = _duel()
	var thrower: PresoPlayer = sim.players[2]
	sim.throw(thrower, Vector2(-0.5, -1.0))
	_wait(sim, 1.0)
	sim.players[1].position = sim.slippers[2].position
	var input: PlayerInput = PresoBrain.new().think(thrower, sim)
	assert_eq(input.move, Vector2.ZERO, "stays home")
	thrower.home_wait = PRESO.home_grace - PRESO.bot_desperate_time
	input = PresoBrain.new().think(thrower, sim)
	assert_ne(input.move, Vector2.ZERO, "goes anyway before it is too slow")


func test_a_match_of_bots_is_played_out_with_knockdowns_and_tags() -> void:
	var sim: PresoSim = _bots(21)
	_wait(sim, PRESO.intro_time + PRESO.match_length + PRESO.tag_freeze_time * 30.0)
	assert_eq(sim.phase, PresoSim.Phase.MATCH_OVER)
	var knockdowns: int = 0
	var tags: int = 0
	for id: int in sim.players:
		knockdowns += sim.players[id].knockdowns
		tags += sim.players[id].times_tagged
	assert_gt(knockdowns, 0, "bots knock the can over")
	assert_gt(tags, 0, "bots get tagged")


func test_the_same_seed_plays_the_same_match() -> void:
	var first: PresoSim = _bots(8)
	var second: PresoSim = _bots(8)
	_wait(first, 40.0)
	_wait(second, 40.0)
	for id: int in first.players:
		assert_eq(first.players[id].position, second.players[id].position)
		assert_eq(first.players[id].times_tagged, second.players[id].times_tagged)
	assert_eq(first.taya_id, second.taya_id)
