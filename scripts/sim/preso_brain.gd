class_name PresoBrain
extends RefCounted
## A Tumbang Preso practice bot. Produces a PlayerInput each tick from the sim state and
## draws its randomness from the sim's seeded RNG, so a match always plays out the same.
## As the taya it fetches a fallen can and carries it home, chases throwers who come
## near the can and otherwise waits by it. As a thrower it walks to its spot behind the
## line, waits a moment and throws at the can (a little off); without its slipper it runs
## for it when the can is down or the taya is far away, and back home when the taya comes.

## A bot this close to where it is going stands still.
const ARRIVE: float = 0.3

## Seconds left before the next throw (-1: not counting yet).
var _wait: float = -1.0
## The throw button was held last tick: this tick lets go with `_aim`.
var _pressed: bool = false
var _aim: Vector2 = Vector2.ZERO


## A new round: forget any throw being lined up.
func reset() -> void:
	_wait = -1.0
	_pressed = false


func think(state: PresoPlayer, sim: PresoSim) -> PlayerInput:
	if sim.is_taya(state.id):
		_pressed = false
		return _guard(state, sim)
	if state.has_slipper:
		return _throw(state, sim)
	return _fetch(state, sim)


func _guard(state: PresoPlayer, sim: PresoSim) -> PlayerInput:
	match sim.can_state:
		PresoSim.CanState.DOWN:
			return _go(state, sim.can_position)
		PresoSim.CanState.CARRIED:
			return _go(state, sim.preso.can_spot)
	var target: PresoPlayer = null
	for id: int in sim.players:
		var other: PresoPlayer = sim.players[id]
		if id == state.id or sim.in_home(other.position):
			continue
		if other.position.distance_to(sim.preso.can_spot) > sim.preso.bot_guard_radius:
			continue
		if target == null or other.position.distance_to(state.position) < target.position.distance_to(state.position):
			target = other
	return _go(state, target.position if target != null else sim.guard_spot())


func _throw(state: PresoPlayer, sim: PresoSim) -> PlayerInput:
	if _pressed:
		_pressed = false
		return PlayerInput.create(Vector2.ZERO, _aim, 0, sim.tick)
	if not sim.in_home(state.position) or state.position.distance_to(state.home_spot) > ARRIVE:
		_wait = -1.0
		return _go(state, state.home_spot)
	if _wait < 0.0:
		_wait = sim.rng.randf_range(sim.preso.bot_reaction_min, sim.preso.bot_reaction_max)
	_wait -= sim.rules.tick_dt()
	if _wait > 0.0:
		return _idle(sim)
	_wait = -1.0
	_pressed = true
	var error: float = deg_to_rad(sim.rng.randf_range(-sim.preso.bot_aim_error, sim.preso.bot_aim_error))
	_aim = state.position.direction_to(sim.preso.can_spot).rotated(error)
	return PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, sim.tick)


func _fetch(state: PresoPlayer, sim: PresoSim) -> PlayerInput:
	var slipper: PresoSim.Slipper = sim.slippers.get(state.id) as PresoSim.Slipper
	if slipper == null or slipper.flying:
		return _idle(sim)
	var taya: PresoPlayer = sim.players[sim.taya_id]
	var can_down: bool = sim.can_state != PresoSim.CanState.STANDING
	var desperate: bool = sim.home_grace_left(state.id) <= sim.preso.bot_desperate_time
	var clear: bool = taya.position.distance_to(slipper.position) >= sim.preso.bot_safe_distance
	var threatened: bool = not sim.in_home(state.position) and taya.position.distance_to(state.position) < sim.preso.bot_danger_distance
	if can_down or desperate or (clear and not threatened):
		return _go(state, slipper.position)
	return _go(state, state.home_spot)


func _go(state: PresoPlayer, target: Vector2) -> PlayerInput:
	var offset: Vector2 = target - state.position
	if offset.length() <= ARRIVE:
		return PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, 0)
	return PlayerInput.create(offset.normalized(), Vector2.ZERO, 0, 0)


func _idle(sim: PresoSim) -> PlayerInput:
	return PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick)
