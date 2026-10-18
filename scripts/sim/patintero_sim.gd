class_name PatinteroSim
extends RefCounted
## Patintero (docs/GDD.md "Patintero"): two teams take turns. The runners start behind the
## start line of a chalk grid and try to get past the back line and home again; each runner
## who makes the round trip scores a point for the team. The taggers stand on the grid's
## lines and can only move along them: a line guard on each line across, a centre guard on
## the line up the middle. A tagger touching a runner inside the grid catches them, and a
## catch (or the turn clock running out) switches the teams. The first team to
## `points_to_win` wins. Same shape as MatchSim: no nodes, only step(dt), its own seeded RNG.

signal intro_finished
## Runner `id` brought a point home for `team`.
signal point_scored(id: int, team: int)
## Runner `id` was caught by tagger `by_id`, or OUT_OF_BOUNDS. A freeze follows, then the switch.
signal runner_caught(id: int, by_id: int)
## Nobody was caught in time. A freeze follows, then the switch.
signal turn_timed_out
## The freeze is over: `team` runs now and everyone is at their spot.
signal sides_switched(team: int)
## `winner` is the winning team, or -1 for a draw (only after max_turns).
signal match_over(winner: int)

## `by_id` of runner_caught when a runner stepped past a side line.
const OUT_OF_BOUNDS: int = -1

enum Phase { PLAYING, SWITCH_FREEZE, MATCH_OVER, INTRO }

var rules: GameRules
var patintero: PatinteroRules
var layout: MapLayout
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
## id -> state, in insertion order (stepping order and role order are deterministic).
var players: Dictionary[int, PatinteroPlayer] = {}
## The team running this turn.
var attacking_team: int = 0
## Points per team (0, 1).
var points: Array[int] = [0, 0]
## Seconds left in this turn.
var turn_left: float = 0.0
## Turns finished so far (a catch or a timeout ends one).
var turns_played: int = 0
var phase: Phase = Phase.PLAYING
## Seconds left of the opening show or of the freeze before the switch.
var phase_left: float = 0.0
## The winning team once the match is over (-1: none yet, or a draw).
var winner: int = -1

var _inputs: Dictionary[int, PlayerInput] = {}
var _brains: Dictionary[int, PatinteroBrain] = {}
var _blocking: Array[Rect2] = []


func _init(p_rules: GameRules, p_patintero: PatinteroRules, p_layout: MapLayout, seed_value: int) -> void:
	rules = p_rules
	patintero = p_patintero
	layout = p_layout
	rng.seed = seed_value
	_blocking = layout.boundary_rects()


func add_player(id: int, team: int) -> PatinteroPlayer:
	var state: PatinteroPlayer = PatinteroPlayer.new()
	state.id = id
	state.team = team
	state.radius = rules.player_radius
	players[id] = state
	return state


## A practice bot: a normal player on `team` driven by `brain`.
func add_bot(id: int, team: int, brain: PatinteroBrain) -> PatinteroPlayer:
	_brains[id] = brain
	return add_player(id, team)


func set_input(id: int, input: PlayerInput) -> void:
	_inputs[id] = input


## Every kid gets a character (seeded); a team never has the same kid twice, the other team may.
## `local_id` keeps `local_kid` when it is one. Purely cosmetic.
func assign_characters(local_id: int, local_kid: StringName) -> void:
	var keep: bool = rules.characters.any(func(c: CharacterDef) -> bool: return c.id == local_kid)
	for team: int in [0, 1]:
		var ids: Array[StringName] = []
		for character: CharacterDef in rules.characters:
			if not (keep and team == players[local_id].team and character.id == local_kid):
				ids.append(character.id)
		for i: int in range(ids.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var swap: StringName = ids[i]
			ids[i] = ids[j]
			ids[j] = swap
		var index: int = 0
		for id: int in players:
			if players[id].team != team:
				continue
			if id == local_id and keep:
				players[id].character_id = local_kid
				continue
			players[id].character_id = ids[index % ids.size()]
			index += 1


## Starts the match with `first_runners` running, after the opening show. Call once, after
## adding everyone.
func start(first_runners: int) -> void:
	attacking_team = first_runners
	_reset_turn()
	phase = Phase.INTRO
	phase_left = patintero.intro_time
	if phase_left <= 0.0:
		phase = Phase.PLAYING


func is_runner(id: int) -> bool:
	return players[id].role == PatinteroPlayer.Role.RUNNER


## Inside the grid, between the start line and the back line (where catches happen).
func in_field(position: Vector2) -> bool:
	return position.y < patintero.start_line_z and position.y > patintero.back_line_z


## Behind the start line: the runners' home.
func in_home(position: Vector2) -> bool:
	return position.y >= patintero.start_line_z


## Past the back line: the turning point.
func in_far(position: Vector2) -> bool:
	return position.y <= patintero.back_line_z


## Where along Z the centre guard starts each turn: half way up the grid.
func centre_start_z() -> float:
	return (patintero.start_line_z + patintero.back_line_z) / 2.0


func step(dt: float) -> void:
	tick += 1
	match phase:
		Phase.MATCH_OVER:
			return
		Phase.INTRO:
			phase_left -= dt
			if phase_left <= 0.0:
				phase_left = 0.0
				phase = Phase.PLAYING
				intro_finished.emit()
			return
		Phase.SWITCH_FREEZE:
			phase_left -= dt
			if phase_left <= 0.0:
				_switch_sides()
			return
	for id: int in _brains:
		_inputs[id] = _brains[id].think(players[id], self)
	for id: int in players:
		_move(players[id], _inputs.get(id) as PlayerInput, dt)
	for id: int in players:
		var state: PatinteroPlayer = players[id]
		if state.role == PatinteroPlayer.Role.RUNNER:
			_step_runner(state)
		if phase != Phase.PLAYING:
			return
	_check_catches()
	if phase != Phase.PLAYING:
		return
	turn_left -= dt
	if turn_left <= 0.0:
		turn_left = 0.0
		_end_turn()
		turn_timed_out.emit()


func _move(state: PatinteroPlayer, input: PlayerInput, dt: float) -> void:
	if input == null:
		return
	var move: Vector2 = input.move.limit_length(1.0)
	var speed: float = rules.move_speed
	match state.role:
		PatinteroPlayer.Role.LINE_GUARD:
			move = Vector2(move.x, 0.0)
			speed *= patintero.tagger_speed_scale
		PatinteroPlayer.Role.CENTRE_GUARD:
			move = Vector2(0.0, move.y)
			speed *= patintero.tagger_speed_scale
	if move.length_squared() <= 0.0:
		return
	state.facing = move.normalized()
	var delta: Vector2 = move * speed * dt
	var count: int = maxi(1, ceili(delta.length() / state.radius))
	for i: int in count:
		state.position = Collision.resolve(state.position + delta / count, state.radius, _blocking)
		_keep_in_place(state)


## Taggers stay on their line; runners stay inside the side lines outside the grid (and inside
## it too when stepping out is not a catch).
func _keep_in_place(state: PatinteroPlayer) -> void:
	var half: float = patintero.field_half_width
	match state.role:
		PatinteroPlayer.Role.LINE_GUARD:
			state.position = Vector2(clampf(state.position.x, -half, half), patintero.guard_lines[state.line_index])
		PatinteroPlayer.Role.CENTRE_GUARD:
			state.position = Vector2(0.0, clampf(state.position.y, patintero.back_line_z, patintero.start_line_z))
		PatinteroPlayer.Role.RUNNER:
			if not in_field(state.position):
				state.position.x = clampf(state.position.x, -half + state.radius, half - state.radius)
			elif not patintero.out_of_bounds_catches:
				state.position.x = clampf(state.position.x, -half, half)


func _step_runner(state: PatinteroPlayer) -> void:
	if in_field(state.position) and absf(state.position.x) > patintero.field_half_width:
		_catch(state, OUT_OF_BOUNDS)
		return
	if in_far(state.position):
		state.reached_back = true
	elif state.reached_back and in_home(state.position):
		state.reached_back = false
		state.points += 1
		points[state.team] += 1
		point_scored.emit(state.id, state.team)
		if points[state.team] >= patintero.points_to_win:
			_finish(state.team)


## A tagger within reach of a runner inside the grid catches them (the first pair found).
func _check_catches() -> void:
	for runner_id: int in players:
		var runner: PatinteroPlayer = players[runner_id]
		if runner.role != PatinteroPlayer.Role.RUNNER or not in_field(runner.position):
			continue
		for tagger_id: int in players:
			var tagger: PatinteroPlayer = players[tagger_id]
			if tagger.role == PatinteroPlayer.Role.RUNNER:
				continue
			if runner.position.distance_to(tagger.position) <= patintero.tag_distance:
				_catch(runner, tagger_id)
				return


func _catch(runner: PatinteroPlayer, by_id: int) -> void:
	_end_turn()
	runner_caught.emit(runner.id, by_id)


func _end_turn() -> void:
	turns_played += 1
	phase = Phase.SWITCH_FREEZE
	phase_left = patintero.switch_freeze_time


func _switch_sides() -> void:
	if turns_played >= patintero.max_turns:
		var lead: int = -1
		if points[0] != points[1]:
			lead = 0 if points[0] > points[1] else 1
		_finish(lead)
		return
	attacking_team = 1 - attacking_team
	_reset_turn()
	phase = Phase.PLAYING
	sides_switched.emit(attacking_team)


func _finish(team: int) -> void:
	winner = team
	phase = Phase.MATCH_OVER
	match_over.emit(team)


## The runners in a row behind the start line (in id order); the taggers one per guarded line,
## then the centre guard, then any more on the lines again; the turn clock full.
func _reset_turn() -> void:
	turn_left = patintero.turn_time
	var runners: Array[int] = []
	var taggers: Array[int] = []
	for id: int in players:
		if players[id].team == attacking_team:
			runners.append(id)
		else:
			taggers.append(id)
	var row_z: float = patintero.start_line_z + patintero.home_row_offset
	for index: int in runners.size():
		var state: PatinteroPlayer = players[runners[index]]
		state.role = PatinteroPlayer.Role.RUNNER
		state.reached_back = false
		state.position = Vector2((index - (runners.size() - 1) / 2.0) * patintero.runner_spacing, row_z)
		state.facing = Vector2(0.0, -1.0)
	var line_count: int = patintero.guard_lines.size()
	for index: int in taggers.size():
		var state: PatinteroPlayer = players[taggers[index]]
		if index == line_count:
			state.role = PatinteroPlayer.Role.CENTRE_GUARD
			state.position = Vector2(0.0, centre_start_z())
		else:
			state.role = PatinteroPlayer.Role.LINE_GUARD
			state.line_index = index % line_count
			state.position = Vector2(0.0, patintero.guard_lines[state.line_index])
		state.facing = Vector2(0.0, 1.0)
	for id: int in players:
		players[id].previous_buttons = 0
	for id: int in _brains:
		_brains[id].reset()
