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


# ---- no default skills: only the two picked weapons (owner) ----

func test_there_is_no_dash_or_pin_any_more() -> void:
	assert_false("dash_distance" in RULES, "Takbo is gone")
	assert_false("bookmark_blink" in RULES, "the pin is gone")
	var sim: MatchSim = _sim()
	var p: PlayerState = sim.add_player(1, 0)
	var start: Vector2 = p.position
	# every unused button bit does nothing: no skill moves the player
	_tick(sim, 1, Vector2.ZERO, (1 << 2) | (1 << 3) | (1 << 4))
	_run(sim, 1, Vector2.ZERO, 10)
	assert_eq(p.position, start)


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
