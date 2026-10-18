class_name PresoSim
extends RefCounted
## Tumbang Preso (docs/GDD.md "Tumbang Preso"): one taya guards a can in a chalk circle;
## everyone else throws their one slipper at it from behind the home line. A thrown
## slipper lies where it lands and its owner has to run out and pick it up. While the
## can stands, the taya tags any thrower outside the line by touching them; a knocked
## can has to be carried back into its circle first. A tagged thrower becomes the new
## taya. The match runs on a clock and the kid tagged the fewest times wins.
## Same shape as MatchSim: no nodes, only step(dt), its own seeded RNG.

signal intro_finished
signal slipper_thrown(id: int)
signal slipper_picked_up(id: int)
## The slipper of `by_id` knocked the can over.
signal can_knocked(by_id: int)
signal can_picked_up(id: int)
## The taya stood the can back up in its circle: tagging is on again.
signal can_set(id: int)
## `id` is out: touched by the taya `by_id`, or TOO_SLOW. A freeze follows.
signal player_tagged(id: int, by_id: int)
## The freeze is over: `id` guards the can now and everyone is back at their spot.
signal taya_changed(id: int)
signal match_over

## `by_id` of player_tagged when a thrower waited too long behind the line without their slipper.
const TOO_SLOW: int = -1
## Max distance a slipper moves between can checks (a fast one can never skip the can).
const SLIPPER_STEP: float = 0.25
## The forward direction (up the street, toward -Z).
const FORWARD: Vector2 = Vector2(0.0, -1.0)

enum Phase { PLAYING, TAG_FREEZE, MATCH_OVER, INTRO }
enum CanState { STANDING, DOWN, CARRIED }


class Slipper extends RefCounted:
	var owner_id: int
	var position: Vector2
	var direction: Vector2
	var travelled: float = 0.0
	## Still in the air; false once it lies on the street.
	var flying: bool = true


var rules: GameRules
var preso: PresoRules
var layout: MapLayout
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
## id -> state, in insertion order (stepping order is deterministic).
var players: Dictionary[int, PresoPlayer] = {}
var taya_id: int = -1
var can_state: CanState = CanState.STANDING
var can_position: Vector2 = Vector2.ZERO
## owner id -> their slipper while it is out of their hand.
var slippers: Dictionary[int, Slipper] = {}
var phase: Phase = Phase.PLAYING
## Seconds left of the opening show or of the freeze after a tag.
var phase_left: float = 0.0
## Seconds of play so far (stops in the intro and the freezes).
var match_time: float = 0.0
## Who becomes the taya when the freeze ends.
var next_taya: int = -1

var _inputs: Dictionary[int, PlayerInput] = {}
var _brains: Dictionary[int, PresoBrain] = {}
var _blocking: Array[Rect2] = []


func _init(p_rules: GameRules, p_preso: PresoRules, p_layout: MapLayout, seed_value: int) -> void:
	rules = p_rules
	preso = p_preso
	layout = p_layout
	rng.seed = seed_value
	_blocking = layout.boundary_rects()
	can_position = preso.can_spot


func add_player(id: int) -> PresoPlayer:
	var state: PresoPlayer = PresoPlayer.new()
	state.id = id
	state.radius = rules.player_radius
	state.facing = FORWARD
	players[id] = state
	return state


## A practice bot: a normal player driven by `brain`.
func add_bot(id: int, brain: PresoBrain) -> PresoPlayer:
	_brains[id] = brain
	return add_player(id)


func set_input(id: int, input: PlayerInput) -> void:
	_inputs[id] = input


## Every kid gets a different character (seeded); `local_id` keeps `local_kid` when it is one.
## Purely cosmetic.
func assign_characters(local_id: int, local_kid: StringName) -> void:
	var ids: Array[StringName] = []
	for character: CharacterDef in rules.characters:
		if character.id != local_kid:
			ids.append(character.id)
	for i: int in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: StringName = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	var keep: bool = rules.characters.any(func(c: CharacterDef) -> bool: return c.id == local_kid)
	var index: int = 0
	for id: int in players:
		if id == local_id and keep:
			players[id].character_id = local_kid
			continue
		players[id].character_id = ids[index % ids.size()]
		index += 1


## Starts the match with `first_taya` guarding the can (that does not count as a tag),
## after the opening show. Call once, after adding everyone.
func start(first_taya: int) -> void:
	taya_id = first_taya
	_reset_round()
	phase = Phase.INTRO
	phase_left = preso.intro_time
	if phase_left <= 0.0:
		phase = Phase.PLAYING


func is_taya(id: int) -> bool:
	return id == taya_id


## Behind the home line (the throwers' side, +Z).
func in_home(position: Vector2) -> bool:
	return position.y > preso.throw_line_z


## Where the taya waits: by the can, on the home-line side.
func guard_spot() -> Vector2:
	return preso.can_spot + Vector2(0.0, preso.guard_offset)


## A thrower holding their slipper behind the line, in play.
func can_throw(state: PresoPlayer) -> bool:
	return phase == Phase.PLAYING and not is_taya(state.id) and state.has_slipper and in_home(state.position)


## The direction a throw with `aim` goes (before any auto-aim spread): the stick when it is
## past the deadzone, otherwise at the can; never more than max_throw_angle off straight ahead.
func throw_direction(state: PresoPlayer, aim: Vector2) -> Vector2:
	var direction: Vector2 = aim.normalized() if aim.length() >= rules.aim_deadzone else state.position.direction_to(preso.can_spot)
	return _forward_clamped(direction)


## Seconds left before a held slipper is thrown for you (0 when the clock is not running).
func shot_clock_left(id: int) -> float:
	var state: PresoPlayer = players[id]
	return maxf(0.0, preso.shot_clock - state.shot_time) if can_throw(state) else 0.0


## Seconds a thrower without their slipper may still wait behind the line.
func home_grace_left(id: int) -> float:
	return maxf(0.0, preso.home_grace - players[id].home_wait)


func time_left() -> float:
	return maxf(0.0, preso.match_length - match_time)


## Player ids best first: fewest times tagged, then most knock-downs, then least time as
## the taya, then the lower id.
func ranking() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(players.keys())
	ids.sort_custom(func(a: int, b: int) -> bool:
		var pa: PresoPlayer = players[a]
		var pb: PresoPlayer = players[b]
		if pa.times_tagged != pb.times_tagged:
			return pa.times_tagged < pb.times_tagged
		if pa.knockdowns != pb.knockdowns:
			return pa.knockdowns > pb.knockdowns
		if not is_equal_approx(pa.taya_time, pb.taya_time):
			return pa.taya_time < pb.taya_time
		return a < b)
	return ids


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
		Phase.TAG_FREEZE:
			phase_left -= dt
			if phase_left <= 0.0:
				_new_round()
			return
	for id: int in _brains:
		_inputs[id] = _brains[id].think(players[id], self)
	for id: int in players:
		_step_player(players[id], _inputs.get(id) as PlayerInput, dt)
		if phase != Phase.PLAYING:
			return
	_step_slippers(dt)
	_step_can()
	_check_tags()
	if phase != Phase.PLAYING:
		return
	match_time += dt
	if match_time >= preso.match_length:
		match_time = preso.match_length
		phase = Phase.MATCH_OVER
		match_over.emit()


## Throws `state`'s slipper. `aim` is a world-space stick (zero = at the can, with spread).
## False when they cannot throw now.
func throw(state: PresoPlayer, aim: Vector2) -> bool:
	if not can_throw(state):
		return false
	var direction: Vector2 = throw_direction(state, aim)
	if aim.length() < rules.aim_deadzone:
		direction = _forward_clamped(direction.rotated(deg_to_rad(rng.randf_range(-preso.auto_aim_spread, preso.auto_aim_spread))))
	var slipper: Slipper = Slipper.new()
	slipper.owner_id = state.id
	slipper.position = state.position
	slipper.direction = direction
	slippers[state.id] = slipper
	state.has_slipper = false
	state.shot_time = 0.0
	state.home_wait = 0.0
	state.facing = direction
	slipper_thrown.emit(state.id)
	return true


func _step_player(state: PresoPlayer, input: PlayerInput, dt: float) -> void:
	_move(state, input, dt)
	if is_taya(state.id):
		state.taya_time += dt
		return
	if input != null:
		var held: bool = input.is_pressed(PlayerInput.BTN_WEAPON_1)
		var was_held: bool = (state.previous_buttons & PlayerInput.BTN_WEAPON_1) != 0
		if was_held and not held and not input.is_pressed(PlayerInput.BTN_AIM_CANCEL):
			throw(state, input.aim)
		state.previous_buttons = input.buttons
	if can_throw(state):
		state.shot_time += dt
		if state.shot_time >= preso.shot_clock:
			throw(state, Vector2.ZERO)
	_try_pick_up(state)
	if not state.has_slipper and in_home(state.position):
		state.home_wait += dt
		if state.home_wait >= preso.home_grace:
			_tag(state, TOO_SLOW)


func _move(state: PresoPlayer, input: PlayerInput, dt: float) -> void:
	if input == null:
		return
	var move: Vector2 = input.move.limit_length(1.0)
	if move.length_squared() <= 0.0:
		return
	state.facing = move.normalized()
	var delta: Vector2 = move * rules.move_speed * dt
	var count: int = maxi(1, ceili(delta.length() / state.radius))
	for i: int in count:
		state.position = Collision.resolve(state.position + delta / count, state.radius, _blocking)
		if is_taya(state.id):
			# the taya never crosses the home line
			state.position.y = minf(state.position.y, preso.throw_line_z - state.radius)


func _try_pick_up(state: PresoPlayer) -> void:
	if state.has_slipper or not slippers.has(state.id):
		return
	var slipper: Slipper = slippers[state.id]
	if slipper.flying or state.position.distance_to(slipper.position) > preso.slipper_pickup_distance:
		return
	slippers.erase(state.id)
	state.has_slipper = true
	state.home_wait = 0.0
	state.shot_time = 0.0
	slipper_picked_up.emit(state.id)


func _step_slippers(dt: float) -> void:
	var street: Rect2 = layout.lane_rect().grow(-preso.edge_margin)
	for id: int in slippers:
		var slipper: Slipper = slippers[id]
		if not slipper.flying:
			continue
		var left: float = minf(preso.slipper_speed * dt, preso.slipper_range - slipper.travelled)
		while left > 0.0 and slipper.flying:
			var move: float = minf(SLIPPER_STEP, left)
			var previous: Vector2 = slipper.position
			slipper.position += slipper.direction * move
			slipper.travelled += move
			left -= move
			if can_state == CanState.STANDING and _segment_distance(preso.can_spot, previous, slipper.position) <= preso.can_hit_radius:
				_knock_can(slipper)
			elif not street.has_point(slipper.position):
				slipper.position = slipper.position.clamp(street.position, street.end)
				slipper.flying = false
		if slipper.travelled >= preso.slipper_range:
			slipper.flying = false


func _knock_can(slipper: Slipper) -> void:
	var street: Rect2 = layout.lane_rect().grow(-preso.edge_margin)
	var rest: Vector2 = (preso.can_spot + slipper.direction * preso.knock_distance).clamp(street.position, street.end)
	rest.y = minf(rest.y, preso.throw_line_z - preso.can_line_margin)
	can_state = CanState.DOWN
	can_position = rest
	# the slipper drops by the can
	slipper.position = preso.can_spot
	slipper.flying = false
	players[slipper.owner_id].knockdowns += 1
	can_knocked.emit(slipper.owner_id)


func _step_can() -> void:
	var taya: PresoPlayer = players.get(taya_id) as PresoPlayer
	if taya == null:
		return
	if can_state == CanState.DOWN and taya.position.distance_to(can_position) <= preso.can_pickup_distance:
		can_state = CanState.CARRIED
		can_picked_up.emit(taya_id)
	if can_state == CanState.CARRIED:
		can_position = taya.position
		if taya.position.distance_to(preso.can_spot) <= preso.can_circle_radius:
			can_state = CanState.STANDING
			can_position = preso.can_spot
			can_set.emit(taya_id)


## While the can stands, the taya touching a thrower outside the line tags them.
func _check_tags() -> void:
	if can_state != CanState.STANDING or not players.has(taya_id):
		return
	var taya: PresoPlayer = players[taya_id]
	for id: int in players:
		var state: PresoPlayer = players[id]
		if id == taya_id or in_home(state.position):
			continue
		if state.position.distance_to(taya.position) <= preso.tag_distance:
			_tag(state, taya_id)
			return


func _tag(state: PresoPlayer, by_id: int) -> void:
	state.times_tagged += 1
	next_taya = state.id
	phase = Phase.TAG_FREEZE
	phase_left = preso.tag_freeze_time
	player_tagged.emit(state.id, by_id)


func _new_round() -> void:
	taya_id = next_taya
	next_taya = -1
	_reset_round()
	phase = Phase.PLAYING
	taya_changed.emit(taya_id)


## The can back in its circle, every slipper back in its owner's hand, the throwers in a row
## behind the line (in id order) and the taya by the can.
func _reset_round() -> void:
	can_state = CanState.STANDING
	can_position = preso.can_spot
	slippers.clear()
	var throwers: Array[int] = []
	for id: int in players:
		if id != taya_id:
			throwers.append(id)
	var row_z: float = preso.throw_line_z + preso.home_row_offset
	for index: int in throwers.size():
		var x: float = (index - (throwers.size() - 1) / 2.0) * preso.home_spacing
		players[throwers[index]].home_spot = Vector2(x, row_z)
	for id: int in players:
		var state: PresoPlayer = players[id]
		state.has_slipper = true
		state.shot_time = 0.0
		state.home_wait = 0.0
		state.previous_buttons = 0
		if id == taya_id:
			state.position = guard_spot()
			state.facing = -FORWARD
		else:
			state.position = state.home_spot
			state.facing = FORWARD
	for id: int in _brains:
		_brains[id].reset()


func _forward_clamped(direction: Vector2) -> Vector2:
	var limit: float = deg_to_rad(preso.max_throw_angle)
	var angle: float = FORWARD.angle_to(direction)
	if absf(angle) <= limit:
		return direction.normalized()
	return FORWARD.rotated(signf(angle) * limit)


## Shortest distance from `point` to the segment a-b.
static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var length_squared: float = ab.length_squared()
	if length_squared <= 0.0:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)
