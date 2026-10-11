extends GutTest
## Tag (docs/GDD.md "Tag"): at 0 HP a player is tagged and sent to their team's box;
## a free teammate stepping into the box rescues them back to their post.

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 11)


func _wait(sim: MatchSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


func _box(sim: MatchSim, team: int) -> Rect2:
	return LAYOUT.jail_rect(sim.side_for_team(team))


func test_zero_hp_tags_and_sends_you_to_your_teams_box() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	me.position = Vector2(3.0, -10.0)
	watch_signals(sim)
	sim.damage(1, 500)
	assert_true(me.tagged)
	assert_eq(me.hp, 0)
	assert_true(_box(sim, 0).has_point(me.position), "in the box")
	assert_lt(me.position.x, 0.0, "your team's box is top left")
	assert_lt(me.position.y, 0.0)
	assert_signal_emitted_with_parameters(sim, "player_tagged", [1])


func test_tagged_opponents_go_to_the_bottom_right_box() -> void:
	var sim: MatchSim = _sim()
	var them: PlayerState = sim.add_player(2, 1)
	sim.damage(2, 500)
	assert_gt(them.position.x, 0.0)
	assert_gt(them.position.y, 0.0)
	assert_true(_box(sim, 1).has_point(them.position))


func test_tagged_kids_stand_side_by_side_in_the_box() -> void:
	var sim: MatchSim = _sim()
	var a: PlayerState = sim.add_player(1, 0)
	var b: PlayerState = sim.add_player(2, 0)
	sim.kill(1)
	sim.kill(2)
	assert_ne(a.position, b.position)


func test_tagged_players_cannot_move_act_or_be_hit() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	sim.set_loadout(1, &"bato_light", &"lata")
	sim.kill(1)
	var at: Vector2 = me.position
	for i: int in 10:
		sim.set_input(1, PlayerInput.create(Vector2(1.0, 0.0), Vector2.ZERO, PlayerInput.BTN_WEAPON_1, sim.tick))
		sim.step(DT)
	assert_eq(me.position, at, "waiting in the box")
	assert_false(me.can_act())
	assert_false(sim.weapon_ready(me, 0))
	assert_false(sim.is_targetable(me))
	assert_eq(sim.heal(1, 50), 0, "no healing in the box")


func test_you_get_tagged_every_time_not_just_once() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var friend: PlayerState = sim.add_player(2, 0)
	for round: int in 3:
		sim.damage(1, 500)
		assert_true(me.tagged, "tag %d" % round)
		friend.position = _box(sim, 0).get_center()
		sim.step(DT)
		assert_false(me.tagged, "rescue %d" % round)
		friend.position = Vector2.ZERO


func test_a_teammate_stepping_into_the_box_rescues_you_back_to_your_post() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var friend: PlayerState = sim.add_player(2, 0)
	sim.set_loadout(1, &"bato_light", &"lata")
	me.weapon_cooldowns = [2.0, 0.0] as Array[float]
	sim.kill(1)
	watch_signals(sim)
	friend.position = _box(sim, 0).get_center() + Vector2(0.0, _box(sim, 0).size.y / 2.0 + 2.0)
	for i: int in 30:
		sim.set_input(2, PlayerInput.create(Vector2(0.0, -1.0), Vector2.ZERO, 0, sim.tick))
		sim.step(DT)
		if not me.tagged:
			break
	assert_false(me.tagged)
	assert_eq(me.hp, RULES.player_max_hp)
	assert_eq(me.position, me.spawn_position, "back at the post")
	assert_true(LAYOUT.in_base(sim.side_for_team(0), me.position))
	assert_gt(me.weapon_cooldowns[0], 0.0, "cooldowns kept running, not reset")
	assert_signal_emitted_with_parameters(sim, "player_rescued", [1, 2])


func test_an_enemy_in_the_box_rescues_nobody() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	var them: PlayerState = sim.add_player(2, 1)
	sim.kill(1)
	them.position = _box(sim, 0).get_center()
	_wait(sim, 1.0)
	assert_true(me.tagged)


func test_one_rescue_frees_everyone_in_the_box() -> void:
	var sim: MatchSim = _sim()
	var a: PlayerState = sim.add_player(1, 0)
	var b: PlayerState = sim.add_player(2, 0)
	var friend: PlayerState = sim.add_player(3, 0)
	sim.kill(1)
	sim.kill(2)
	friend.position = _box(sim, 0).get_center()
	sim.step(DT)
	assert_false(a.tagged)
	assert_false(b.tagged)


func test_one_per_touch_when_the_toggle_is_off() -> void:
	var rules: GameRules = RULES.duplicate() as GameRules
	rules.rescue_frees_all = false
	var sim: MatchSim = MatchSim.new(rules, LAYOUT, 3)
	var a: PlayerState = sim.add_player(1, 0)
	var b: PlayerState = sim.add_player(2, 0)
	var friend: PlayerState = sim.add_player(3, 0)
	sim.kill(1)
	sim.kill(2)
	friend.position = _box(sim, 0).get_center()
	sim.step(DT)
	assert_ne(a.tagged, b.tagged, "only one walked out")


func test_tagged_training_dummies_walk_out_on_their_own() -> void:
	var sim: MatchSim = _sim()
	var dummy: PlayerState = sim.add_dummy(5, 1, Vector2(2.0, 3.0), DummyBrain.standing())
	sim.kill(5)
	assert_true(dummy.tagged)
	_wait(sim, RULES.dummy_release_time - 0.2)
	assert_true(dummy.tagged)
	watch_signals(sim)
	_wait(sim, 0.4)
	assert_false(dummy.tagged)
	assert_eq(dummy.position, Vector2(2.0, 3.0))
	assert_signal_emitted_with_parameters(sim, "player_rescued", [5, MatchSim.RELEASED_ALONE])


func test_players_never_walk_out_on_their_own() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = sim.add_player(1, 0)
	sim.add_player(2, 1)
	sim.kill(1)
	_wait(sim, RULES.dummy_release_time + 1.0)
	assert_true(me.tagged)


func test_weapons_can_be_swapped_only_while_tagged() -> void:
	var sim: MatchSim = _sim()
	sim.add_player(1, 0)
	sim.set_loadout(1, &"bato_light", &"lata")
	assert_false(sim.swap_loadout(1, &"jacks", &"bola"), "not while free")
	sim.kill(1)
	assert_true(sim.swap_loadout(1, &"jacks", &"bola"))
	assert_eq(sim.players[1].weapons, [&"jacks", &"bola"] as Array[StringName])
