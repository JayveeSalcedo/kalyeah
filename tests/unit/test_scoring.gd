extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 3)


func _wait(sim: MatchSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


## The enemy post of `player`'s team (inside their base).
func _enemy_post(sim: MatchSim, player: PlayerState) -> Vector2:
	return LAYOUT.base_center(-sim.side_for_team(player.team))


## Puts `player` on the enemy post and waits for the point.
func _score(sim: MatchSim, player: PlayerState) -> void:
	player.position = _enemy_post(sim, player)
	_wait(sim, RULES.capture_time + 0.1)


func _finish_freeze(sim: MatchSim) -> void:
	_wait(sim, RULES.point_freeze_time + 0.1)


## Volleyball-style sets, to check the generic MatchScore logic.
func _set_rules() -> GameRules:
	var rules: GameRules = RULES.duplicate() as GameRules
	rules.set_points_to_win = 5
	rules.set_win_by = 2
	rules.set_point_cap = 7
	rules.match_sets_to_win = 2
	return rules


# ---- MatchScore --------------------------------------------------------------

func test_scoring_numbers_come_from_data() -> void:
	assert_eq(RULES.capture_time, 5.0)
	assert_eq(RULES.point_freeze_time, 3.0)
	assert_eq(RULES.set_points_to_win, 3, "first to 3 points, like the street game")
	assert_eq(RULES.set_win_by, 1)
	assert_eq(RULES.set_point_cap, 3)
	assert_eq(RULES.match_sets_to_win, 1, "one set decides the match")


func test_first_to_three_points_wins_the_match() -> void:
	var score: MatchScore = MatchScore.new(RULES)
	assert_eq(score.award_point(0), MatchScore.Result.POINT)
	assert_eq(score.award_point(1), MatchScore.Result.POINT)
	assert_eq(score.award_point(1), MatchScore.Result.POINT)
	assert_eq(score.award_point(0), MatchScore.Result.POINT, "2-2")
	assert_eq(score.award_point(0), MatchScore.Result.MATCH)
	assert_eq(score.winner, 0)


func test_first_to_five_wins_a_set_when_sets_are_on() -> void:
	var score: MatchScore = MatchScore.new(_set_rules())
	for i: int in 4:
		assert_eq(score.award_point(0), MatchScore.Result.POINT)
	assert_eq(score.award_point(0), MatchScore.Result.SET)
	assert_eq(score.sets, [1, 0] as Array[int])
	assert_eq(score.points, [0, 0] as Array[int])
	assert_eq(score.set_number, 2)


func test_win_by_two_until_the_cap_of_seven() -> void:
	var score: MatchScore = MatchScore.new(_set_rules())
	for i: int in 4:
		score.award_point(0)
		score.award_point(1)
	assert_eq(score.award_point(0), MatchScore.Result.POINT, "5-4 is not enough")
	assert_eq(score.award_point(1), MatchScore.Result.POINT, "5-5")
	assert_eq(score.award_point(1), MatchScore.Result.POINT, "5-6")
	assert_eq(score.award_point(0), MatchScore.Result.POINT, "6-6")
	assert_eq(score.award_point(1), MatchScore.Result.SET, "7 wins at the cap even 6-7")
	assert_eq(score.sets, [0, 1] as Array[int])


# ---- capture: the whole team in the enemy base ------------------------------------

func test_standing_in_the_enemy_base_for_five_seconds_scores() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	watch_signals(sim)
	me.position = _enemy_post(sim, me) + Vector2(0.0, 1.5)
	_wait(sim, RULES.capture_time - 0.2)
	assert_eq(sim.score.points[0], 0, "not yet")
	assert_eq(sim.capture_team, 0)
	assert_eq(sim.capture_kind, MatchSim.CaptureKind.BASE)
	assert_almost_eq(sim.capture_time_left(), 0.2, 0.05)
	_wait(sim, 0.4)
	assert_eq(sim.score.points[0], 1)
	assert_signal_emitted_with_parameters(sim, "point_scored", [0, MatchSim.CaptureKind.BASE])
	assert_eq(sim.phase, MatchSim.Phase.POINT_FREEZE)


func test_the_countdown_starts_only_when_the_whole_team_is_in() -> void:
	var sim: MatchSim = _sim()
	var a: PlayerState = sim.add_player(1, 0)
	var b: PlayerState = sim.add_player(2, 0)
	a.position = _enemy_post(sim, a)
	_wait(sim, RULES.capture_time + 1.0)
	assert_eq(sim.capture_team, -1, "one teammate is still outside")
	assert_eq(sim.score.points[0], 0)
	b.position = _enemy_post(sim, b) + Vector2(0.0, 1.0)
	_wait(sim, RULES.capture_time + 0.1)
	assert_eq(sim.score.points[0], 1)


func test_a_tagged_teammate_stops_the_capture() -> void:
	var sim: MatchSim = _sim()
	var a: PlayerState = sim.add_player(1, 0)
	var b: PlayerState = sim.add_player(2, 0)
	a.position = _enemy_post(sim, a)
	b.position = _enemy_post(sim, b)
	sim.kill(2)
	_wait(sim, RULES.capture_time + 0.5)
	assert_eq(sim.score.points[0], 0, "everyone has to be in the base, so rescue them first")


func test_stepping_out_restarts_the_countdown() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var post: Vector2 = _enemy_post(sim, me)
	me.position = post
	_wait(sim, RULES.capture_time - 0.5)
	me.position = Vector2.ZERO
	sim.step(DT)
	assert_eq(sim.capture_team, -1)
	me.position = post
	_wait(sim, RULES.capture_time - 0.5)
	assert_eq(sim.score.points[0], 0)


func test_own_base_does_not_score() -> void:
	var sim: MatchSim = _sim()
	sim.add_player(1, 0)
	_wait(sim, RULES.capture_time + 1.0)
	assert_eq(sim.score.points, [0, 0] as Array[int])


func test_training_dummies_do_not_count_for_a_capture() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	sim.add_dummy(2, 0, Vector2(0.0, 10.0), DummyBrain.standing())
	me.position = _enemy_post(sim, me)
	_wait(sim, RULES.capture_time + 0.1)
	assert_eq(sim.score.points[0], 1, "the ally dummy stays home, you still score")


# ---- capture: every enemy tagged ---------------------------------------------------

func test_tagging_the_whole_other_team_scores_after_the_countdown() -> void:
	var sim: MatchSim = _sim()
	sim.add_player(1, 0)
	sim.add_player(2, 1)
	sim.add_player(3, 1)
	watch_signals(sim)
	sim.kill(2)
	_wait(sim, 1.0)
	assert_eq(sim.capture_team, -1, "one of them is still free")
	sim.kill(3)
	sim.step(DT)
	assert_eq(sim.capture_team, 0)
	assert_eq(sim.capture_kind, MatchSim.CaptureKind.ALL_TAGGED)
	_wait(sim, RULES.capture_time)
	assert_eq(sim.score.points[0], 1)
	assert_signal_emitted_with_parameters(sim, "point_scored", [0, MatchSim.CaptureKind.ALL_TAGGED])


# ---- freeze and reset ----------------------------------------------------------

func test_freeze_then_everyone_is_reset_at_full_hp_out_of_the_boxes() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var them: PlayerState = sim.add_player(2, 1)
	sim.set_loadout(1, &"bato_light", &"lata")
	me.weapon_cooldowns = [3.0, 9.0] as Array[float]
	me.dash_cooldown_left = 5.0
	sim.apply_effect(2, StatusEffects.Type.SLOW, 10.0, 0.4)
	sim.kill(2)
	_score(sim, me)
	var frozen_at: Vector2 = me.position
	_wait(sim, 2.0)
	assert_eq(me.position, frozen_at, "nobody moves in the freeze")
	assert_eq(sim.phase, MatchSim.Phase.POINT_FREEZE)
	watch_signals(sim)
	_wait(sim, 1.2)
	assert_eq(sim.phase, MatchSim.Phase.PLAYING)
	assert_signal_emitted(sim, "point_reset")
	assert_eq(me.position, me.spawn_position)
	assert_eq(them.position, them.spawn_position)
	assert_false(them.tagged, "the tagged come out of the box too")
	assert_eq(them.hp, 100)
	assert_false(them.effects.has(StatusEffects.Type.SLOW))
	assert_eq(me.weapon_cooldowns, [0.0, 0.0] as Array[float])
	assert_eq(me.dash_cooldown_left, 0.0)
	assert_eq(sim.capture_team, -1)


func test_new_sets_switch_ends_when_sets_are_on() -> void:
	var sim: MatchSim = MatchSim.new(_set_rules(), LAYOUT, 3)
	var me: PlayerState = sim.add_player(1, 0)
	var them: PlayerState = sim.add_player(2, 1)
	watch_signals(sim)
	for i: int in 5:
		_score(sim, me)
		_finish_freeze(sim)
	assert_eq(sim.score.sets, [1, 0] as Array[int])
	assert_signal_emitted(sim, "set_won")
	assert_signal_emitted(sim, "sides_switched")
	assert_eq(sim.side_for_team(0), MapLayout.SIDE_ENEMY)
	assert_lt(me.position.y, 0.0, "team 0 now starts at the -Z end")
	assert_gt(me.position.x, 0.0, "in that end's corner")
	assert_gt(them.position.y, 0.0)
	_score(sim, me)
	assert_eq(sim.score.points[0], 1, "scoring now means reaching the +Z post")


func test_three_points_end_the_match() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	watch_signals(sim)
	for i: int in 3:
		_score(sim, me)
		_finish_freeze(sim)
	assert_eq(sim.phase, MatchSim.Phase.MATCH_OVER)
	assert_signal_emitted_with_parameters(sim, "match_won", [0])
	var at: Vector2 = me.position
	_wait(sim, 5.0)
	assert_eq(me.position, at, "nothing runs after the match")


func test_a_team_of_training_dummies_never_scores() -> void:
	var sim: MatchSim = _sim()
	sim.add_player(1, 0)
	sim.add_dummy(2, 1, Vector2(0.0, -10.0), DummyBrain.standing())
	sim.kill(1)
	_wait(sim, RULES.capture_time + 0.5)
	assert_eq(sim.score.points, [0, 0] as Array[int], "practice: being tagged gives the dummies no point")
