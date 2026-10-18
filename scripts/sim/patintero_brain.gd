class_name PatinteroBrain
extends RefCounted
## A Patintero practice bot. Produces a PlayerInput each tick from the sim state, deciding again
## every reaction time (random between bot_reaction_min and _max, from the sim's seeded RNG) and
## heading for its last decision in between, so a match always plays out the same.
## As a runner it keeps to the side of the grid away from the next line's guard (crossing the
## middle line only when the centre guard is far), waits just out of the guard's reach until the
## guard is far enough away along the line, then dashes across; past the back line it turns for
## home the same way. A line guard follows the runner nearest its line; the centre guard
## follows the runner nearest the middle line.

## A bot this close to where it is going stands still.
const ARRIVE: float = 0.2
## A runner this close to its side lane (along X) is lined up to cross.
const LINE_UP: float = 0.5

## Seconds left before the next decision.
var _think_left: float = 0.0
var _target: Vector2 = Vector2.ZERO
var _has_target: bool = false


## A new turn: decide afresh.
func reset() -> void:
	_think_left = 0.0
	_has_target = false


func think(state: PatinteroPlayer, sim: PatinteroSim) -> PlayerInput:
	_think_left -= sim.rules.tick_dt()
	if _think_left <= 0.0 or not _has_target:
		_think_left = sim.rng.randf_range(sim.patintero.bot_reaction_min, sim.patintero.bot_reaction_max)
		_target = _decide(state, sim)
		_has_target = true
	var offset: Vector2 = _target - state.position
	if offset.length() <= ARRIVE:
		return PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick)
	return PlayerInput.create(offset.normalized(), Vector2.ZERO, 0, sim.tick)


func _decide(state: PatinteroPlayer, sim: PatinteroSim) -> Vector2:
	match state.role:
		PatinteroPlayer.Role.LINE_GUARD:
			return _guard_line(state, sim)
		PatinteroPlayer.Role.CENTRE_GUARD:
			return _guard_centre(state, sim)
	return _run(state, sim)


## The grid's lines across, from the start line (bottom) to the back line (top).
static func lines(sim: PatinteroSim) -> Array[float]:
	var result: Array[float] = [sim.patintero.start_line_z]
	result.append_array(sim.patintero.guard_lines)
	result.append(sim.patintero.back_line_z)
	return result


## 0 = home, then each box up the grid, last = past the back line.
static func zone_of(sim: PatinteroSim, z: float) -> int:
	var zone: int = 0
	for line: float in lines(sim):
		if line > z:
			zone += 1
	return zone


## The middle of a zone along Z (home and the far end: a step past their line).
static func zone_center(sim: PatinteroSim, zone: int) -> float:
	var all: Array[float] = lines(sim)
	if zone <= 0:
		return sim.patintero.start_line_z + sim.patintero.home_row_offset
	if zone >= all.size():
		return sim.patintero.back_line_z - sim.patintero.bot_far_margin
	return (all[zone - 1] + all[zone]) / 2.0


## The line guard standing on the line at `z`, or null for an unguarded line.
static func guard_on(sim: PatinteroSim, z: float) -> PatinteroPlayer:
	for id: int in sim.players:
		var other: PatinteroPlayer = sim.players[id]
		if other.role == PatinteroPlayer.Role.LINE_GUARD and is_equal_approx(sim.patintero.guard_lines[other.line_index], z):
			return other
	return null


static func centre_guard(sim: PatinteroSim) -> PatinteroPlayer:
	for id: int in sim.players:
		if sim.players[id].role == PatinteroPlayer.Role.CENTRE_GUARD:
			return sim.players[id]
	return null


func _run(state: PatinteroPlayer, sim: PatinteroSim) -> Vector2:
	var zone: int = zone_of(sim, state.position.y)
	var next: int = zone - 1 if state.reached_back else zone + 1
	var line: float = lines(sim)[mini(zone, next)]
	var guard: PatinteroPlayer = guard_on(sim, line)
	var side: float = signf(state.position.x)
	# switch to the side away from the guard, but only across the middle line when its guard is far
	var centre: PatinteroPlayer = centre_guard(sim)
	var middle_clear: bool = centre == null or not sim.in_field(state.position) \
		or absf(centre.position.y - state.position.y) >= sim.patintero.bot_middle_gap
	if guard != null and absf(guard.position.x) > ARRIVE and (middle_clear or side == 0.0):
		side = -signf(guard.position.x)
	if side == 0.0:
		side = 1.0 if sim.rng.randf() < 0.5 else -1.0
	var cross_x: float = side * (sim.patintero.field_half_width - sim.patintero.bot_side_margin)
	# line up on that side first (sideways within the zone), wait just out of the guard's reach,
	# then cross when the guard is away along the line
	var lined_up: bool = absf(state.position.x - cross_x) <= LINE_UP
	var gap: float = sim.rng.randf_range(sim.patintero.bot_gap_min, sim.patintero.bot_gap_max)
	var clear: bool = guard == null or absf(guard.position.x - cross_x) >= gap
	if clear and lined_up:
		return Vector2(cross_x, zone_center(sim, next))
	if guard == null:
		return Vector2(cross_x, zone_center(sim, zone))
	var toward_zone: float = signf(zone_center(sim, zone) - line)
	return Vector2(cross_x, line + toward_zone * (sim.patintero.tag_distance + sim.patintero.bot_line_margin))


func _guard_line(state: PatinteroPlayer, sim: PatinteroSim) -> Vector2:
	var line: float = sim.patintero.guard_lines[state.line_index]
	var nearest: PatinteroPlayer = null
	for id: int in sim.players:
		var runner: PatinteroPlayer = sim.players[id]
		if runner.role != PatinteroPlayer.Role.RUNNER:
			continue
		if nearest == null or absf(runner.position.y - line) < absf(nearest.position.y - line):
			nearest = runner
	var x: float = nearest.position.x if nearest != null else 0.0
	return Vector2(clampf(x, -sim.patintero.field_half_width, sim.patintero.field_half_width), line)


func _guard_centre(_state: PatinteroPlayer, sim: PatinteroSim) -> Vector2:
	var nearest: PatinteroPlayer = null
	for id: int in sim.players:
		var runner: PatinteroPlayer = sim.players[id]
		if runner.role != PatinteroPlayer.Role.RUNNER or not sim.in_field(runner.position):
			continue
		if nearest == null or absf(runner.position.x) < absf(nearest.position.x):
			nearest = runner
	var z: float = nearest.position.y if nearest != null else sim.centre_start_z()
	return Vector2(0.0, clampf(z, sim.patintero.back_line_z, sim.patintero.start_line_z))
