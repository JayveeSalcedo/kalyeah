class_name MatchSim
extends RefCounted
## Authoritative match simulation. Never touches nodes, input devices or
## rendering; the same class runs on the server, in offline practice and in tests.
## Advances only through step(dt) and uses its own seeded RNG (no randf()).

## At 0 HP a player is tagged: sent to their team's box until a teammate rescues them.
signal player_tagged(id: int)
## `by_id` is the rescuing teammate, or -1 when a training dummy walked out on its own.
signal player_rescued(id: int, by_id: int)

## A team scored (`how` is a CaptureKind). A freeze follows.
signal point_scored(team: int, how: int)
signal set_won(team: int)
signal match_won(team: int)
## The freeze is over: everyone is back at their post at full HP.
signal point_reset
## New set: the teams swapped ends.
signal sides_switched
## Dash / Bookmark used (sounds and effects).
signal player_dashed(id: int)
signal bookmark_used(id: int)
## A status effect landed on a player (stun, slow, polymorph...).
signal effect_applied(id: int, type: int)
## A player regained HP (the heal skill).
signal player_healed(id: int, amount: int)
## A weapon was cast (for sounds and effects).
signal weapon_cast(id: int, weapon_id: StringName)
## A player lost HP.
signal player_damaged(id: int, amount: int)

const RELEASED_ALONE: int = -1

enum Phase { PLAYING, POINT_FREEZE, MATCH_OVER }
## How a team is scoring: everyone in the enemy base, or every enemy in the box.
enum CaptureKind { NONE = -1, BASE = 0, ALL_TAGGED = 1 }

var rules: GameRules
var layout: MapLayout
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
## id -> state, in insertion order (stepping order is deterministic).
var players: Dictionary[int, PlayerState] = {}
## Cover on the street (from the map layout); blocks walking and throws for everyone.
var obstacles: Array[Rect2] = []
## Live weapon effects (projectiles, zones, shields).
var weapons: WeaponSystem = WeaponSystem.new()
## id -> WeaponDef, from rules.weapons.
var weapon_defs: Dictionary[StringName, WeaponDef] = {}
var score: MatchScore
## The team whose capture countdown is running (-1: none), how, and for how long.
var capture_team: int = -1
var capture_kind: CaptureKind = CaptureKind.NONE
var capture_elapsed: float = 0.0
var phase: Phase = Phase.PLAYING
## Seconds left in the freeze after a point.
var freeze_left: float = 0.0

var _inputs: Dictionary[int, PlayerInput] = {}
var _brains: Dictionary[int, DummyBrain] = {}
var _team_counts: Dictionary[int, int] = {}
var _blocking: Array[Rect2] = []
## Which side team 0 defends this set (teams switch bases every set).
var _team0_side: int = MapLayout.SIDE_OWN
var _new_set_pending: bool = false


func _init(p_rules: GameRules, p_layout: MapLayout, seed_value: int) -> void:
	rules = p_rules
	layout = p_layout
	rng.seed = seed_value
	obstacles = layout.obstacle_rects()
	_blocking.append_array(layout.boundary_rects())
	_blocking.append_array(obstacles)
	for def: WeaponDef in rules.weapons:
		weapon_defs[def.id] = def
	score = MatchScore.new(rules)


## Team 0 starts on the own (+Z) end, team 1 on the enemy (-Z) end; they swap
## every set.
func side_for_team(team: int) -> int:
	return _team0_side if team == 0 else -_team0_side


## Network mirror only: the server says which base team 0 defends now.
func set_team0_side(side: int) -> void:
	if side == _team0_side:
		return
	_team0_side = side
	for id: int in players:
		var spawn: Vector2 = players[id].spawn_position
		players[id].spawn_position = -spawn


## Client-side prediction: runs only the movement part of a tick for one player
## (walking and dash travel; obstacles and speed modifiers included). Skills,
## weapons and everything else stay server-side.
func predict_move(id: int, input: PlayerInput, dt: float) -> void:
	var state: PlayerState = players.get(id) as PlayerState
	if state == null or state.tagged or phase != Phase.PLAYING:
		return
	_move(state, input, dt)


func add_player(id: int, team: int) -> PlayerState:
	var slot: int = 0
	if _team_counts.has(team):
		slot = _team_counts[team]
	_team_counts[team] = slot + 1
	var side: int = side_for_team(team)
	var state: PlayerState = PlayerState.new()
	state.id = id
	state.team = team
	state.spawn_position = _spawn_position(side, slot)
	state.position = state.spawn_position
	state.facing = Vector2(0.0, -side)
	state.hp = rules.player_max_hp
	state.radius = rules.player_radius
	players[id] = state
	return state


## Equips two different weapons. Returns false (and changes nothing) for an
## unknown weapon or the same weapon twice; two of the same *type* is fine.
func set_loadout(id: int, first: StringName, second: StringName) -> bool:
	if not players.has(id) or first == second:
		return false
	if not weapon_defs.has(first) or not weapon_defs.has(second):
		return false
	var state: PlayerState = players[id]
	state.weapons = [first, second]
	state.weapon_cooldowns = [0.0, 0.0]
	state.aim_hold = [-1.0, -1.0]
	state.pin_aim_hold = -1.0
	return true


## Box swap: only while tagged (waiting in the box), as often as you like.
## A weapon you keep keeps its cooldown, so swapping away and back clears nothing.
func swap_loadout(id: int, first: StringName, second: StringName) -> bool:
	if not players.has(id) or not players[id].tagged:
		return false
	var state: PlayerState = players[id]
	var kept: Dictionary[StringName, float] = {}
	for slot: int in state.weapons.size():
		kept[state.weapons[slot]] = state.weapon_cooldowns[slot]
	if not set_loadout(id, first, second):
		return false
	for slot: int in state.weapons.size():
		state.weapon_cooldowns[slot] = kept.get(state.weapons[slot], 0.0) as float
	return true


## Two different random weapons (auto-fill when the pick timer runs out).
func random_loadout() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def: WeaponDef in rules.weapons:
		ids.append(def.id)
	var first: int = rng.randi_range(0, ids.size() - 1)
	var second: int = rng.randi_range(0, ids.size() - 2)
	if second >= first:
		second += 1
	return [ids[first], ids[second]]


## Gives every player a random character, no duplicates (seeded, so the server and
## replays agree). Purely cosmetic.
func assign_characters() -> void:
	var ids: Array[StringName] = []
	for character: CharacterDef in rules.characters:
		ids.append(character.id)
	for i: int in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: StringName = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	var index: int = 0
	for id: int in players:
		players[id].character_id = ids[index % ids.size()]
		index += 1


## Players that can be hit (everyone not waiting in a box).
func is_targetable(state: PlayerState) -> bool:
	return not state.tagged


func enemies_of(team: int) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for id: int in players:
		var state: PlayerState = players[id]
		if state.team != team and is_targetable(state):
			result.append(state)
	return result


func nearest_enemy(caster: PlayerState, max_range: float) -> PlayerState:
	var best: PlayerState = null
	var best_distance: float = max_range
	for target: PlayerState in enemies_of(caster.team):
		var distance: float = caster.position.distance_to(target.position)
		if distance <= best_distance:
			best_distance = distance
			best = target
	return best


## Status effect from a weapon. Hard CC also cancels a dash in progress.
func apply_effect(id: int, type: StatusEffects.Type, duration: float, magnitude: float) -> void:
	if not players.has(id) or not is_targetable(players[id]):
		return
	var state: PlayerState = players[id]
	var fresh: bool = type != StatusEffects.Type.NONE and not state.effects.has(type)
	state.effects.apply(type, duration, magnitude)
	if fresh:
		effect_applied.emit(id, type)
	if state.effects.is_hard_cc(type):
		state.dash_time_left = 0.0


## A training dummy: a normal player on `team` placed at `position`, driven by `brain`.
## Tagged dummies walk out of the box on their own after `dummy_release_time` and go
## back to this spot. Dummies don't count for captures.
func add_dummy(id: int, team: int, position: Vector2, brain: DummyBrain) -> PlayerState:
	var state: PlayerState = add_player(id, team)
	state.position = position
	state.spawn_position = position
	_brains[id] = brain
	return state


func set_input(id: int, input: PlayerInput) -> void:
	_inputs[id] = input


## Applies damage. At 0 HP the player is tagged.
func damage(id: int, amount: int) -> void:
	if not players.has(id) or amount <= 0:
		return
	var state: PlayerState = players[id]
	if state.tagged:
		return
	state.hp = maxi(0, state.hp - amount)
	player_damaged.emit(id, amount)
	if state.hp <= 0:
		_tag(state)


## Heals up to max HP; returns the HP actually gained. Nothing while tagged.
func heal(id: int, amount: int) -> int:
	var state: PlayerState = players.get(id) as PlayerState
	if state == null or amount <= 0 or state.tagged:
		return 0
	var gained: int = mini(amount, rules.player_max_hp - state.hp)
	if gained <= 0:
		return 0
	state.hp += gained
	player_healed.emit(id, gained)
	return gained


## Tags a player straight away (scripted or out-of-play).
func kill(id: int) -> void:
	if players.has(id) and not players[id].tagged:
		players[id].hp = 0
		_tag(players[id])


func step(dt: float) -> void:
	if phase == Phase.MATCH_OVER:
		tick += 1
		return
	if phase == Phase.POINT_FREEZE:
		freeze_left -= dt
		if freeze_left <= 0.0:
			_end_freeze()
		tick += 1
		return
	for id: int in _brains:
		if not players[id].tagged:
			_inputs[id] = _brains[id].think(players[id], self)
	for id: int in players:
		var state: PlayerState = players[id]
		var input: PlayerInput = _inputs[id] if _inputs.has(id) else null
		if state.tagged:
			_step_tagged(state, input, dt)
		else:
			_step_free(state, input, dt)
	weapons.step(self, dt)
	_check_rescues()
	_check_captures(dt)
	tick += 1


func _tick_cooldowns(state: PlayerState, dt: float) -> void:
	for slot: int in state.weapon_cooldowns.size():
		state.weapon_cooldowns[slot] = maxf(0.0, state.weapon_cooldowns[slot] - dt)
	state.dash_cooldown_left = maxf(0.0, state.dash_cooldown_left - dt)
	state.bookmark_cooldown_left = maxf(0.0, state.bookmark_cooldown_left - dt)


func _step_free(state: PlayerState, input: PlayerInput, dt: float) -> void:
	state.effects.step(dt)
	_tick_cooldowns(state, dt)
	_tick_boost(state, dt)
	# Skills fire on a fresh press only: holding a key through a cooldown does not
	# queue a cast for the moment it ends (no precasting).
	var previous: int = state.previous_buttons
	var just_pressed: int = input.buttons & ~previous if input != null else 0
	if input != null:
		_handle_pin_button(state, input, previous, dt)
	if input != null and state.can_act():
		if just_pressed & PlayerInput.BTN_DASH and state.dash_cooldown_left <= 0.0:
			_start_dash(state, input)
	if input != null:
		_handle_weapon_buttons(state, input, dt)
	_move(state, input, dt)


## Waiting in the box: no moving or skills, cooldowns keep running. Training dummies
## walk out on their own after a while.
func _step_tagged(state: PlayerState, input: PlayerInput, dt: float) -> void:
	_tick_cooldowns(state, dt)
	state.tag_time += dt
	if input != null:
		state.previous_buttons = input.buttons
	if _brains.has(state.id) and state.tag_time >= rules.dummy_release_time:
		_rescue(state, RELEASED_ALONE)


## Off to the box of the player's team (own: top-left, enemy: bottom-right).
func _tag(state: PlayerState) -> void:
	var waiting: int = 0
	for id: int in players:
		if players[id].team == state.team and players[id].tagged:
			waiting += 1
	state.tagged = true
	state.hp = 0
	state.tag_time = 0.0
	_clear_actions(state)
	state.position = layout.jail_slot(side_for_team(state.team), waiting)
	state.facing = Vector2(0.0, side_for_team(state.team))
	player_tagged.emit(state.id)


## A free teammate stepping into the box frees whoever waits there (everyone, or
## one per touch when `rescue_frees_all` is off).
func _check_rescues() -> void:
	for id: int in players:
		var rescuer: PlayerState = players[id]
		if rescuer.tagged:
			continue
		var box: Rect2 = layout.jail_rect(side_for_team(rescuer.team)).grow(rescuer.radius)
		if not box.has_point(rescuer.position):
			continue
		for other_id: int in players:
			var waiting: PlayerState = players[other_id]
			if waiting.team == rescuer.team and waiting.tagged:
				_rescue(waiting, rescuer.id)
				if not rules.rescue_frees_all:
					break


## Back to the post at full HP.
func _rescue(state: PlayerState, by_id: int) -> void:
	state.tagged = false
	state.tag_time = 0.0
	state.hp = rules.player_max_hp
	state.position = state.spawn_position
	state.facing = Vector2(0.0, -side_for_team(state.team))
	_clear_actions(state)
	player_rescued.emit(state.id, by_id)


## Dash, stumble, bookmark, status effects and weapon aiming end on a tag or rescue.
## Cooldowns keep running.
func _clear_actions(state: PlayerState) -> void:
	state.dash_time_left = 0.0
	state.stumble_time_left = 0.0
	state.cast_lock_left = 0.0
	state.boost_time_left = 0.0
	if state.mark_active:
		state.bookmark_cooldown_left = rules.bookmark_cooldown
	state.mark_active = false
	state.effects.clear()
	state.aim_hold = [-1.0, -1.0]


## Weapons cast on release: a fresh press starts aiming (only if the weapon is
## ready: no precasting during a cooldown), hold time counts up (cone snips) and
## release casts unless it was released over the cancel zone. Auto-aim is taken
## once at the press; hard CC drops a held aim.
func _handle_weapon_buttons(state: PlayerState, input: PlayerInput, dt: float) -> void:
	var bits: Array[int] = [PlayerInput.BTN_WEAPON_1, PlayerInput.BTN_WEAPON_2]
	for slot: int in bits.size():
		var held: bool = input.is_pressed(bits[slot])
		var was_held: bool = (state.previous_buttons & bits[slot]) != 0
		if held and not was_held:
			if weapon_ready(state, slot):
				state.aim_hold[slot] = 0.0
				_lock_aim(state, slot)
			else:
				state.aim_hold[slot] = -1.0
		elif held and state.aim_hold[slot] >= 0.0:
			if state.tagged or not state.effects.can_cast():
				state.aim_hold[slot] = -1.0
			else:
				state.aim_hold[slot] += dt
		elif not held and was_held and state.aim_hold[slot] >= 0.0:
			if not input.is_pressed(PlayerInput.BTN_AIM_CANCEL):
				_try_fire(state, slot, input.aim, state.aim_hold[slot])
			state.aim_hold[slot] = -1.0
	state.previous_buttons = input.buttons


## A weapon slot can start aiming: equipped, off cooldown, and casting allowed.
func weapon_ready(state: PlayerState, slot: int) -> bool:
	return (
		not state.tagged and state.effects.can_cast()
		and slot < state.weapons.size() and state.weapon_cooldowns[slot] <= 0.0
	)


## The aim a release would use: the stick if it is past the deadzone, otherwise the
## auto-aim locked at the press (or a live auto-aim if the slot is not held yet).
func resolved_aim(state: PlayerState, slot: int, stick: Vector2) -> Vector2:
	if stick.length() >= rules.aim_deadzone:
		return stick.limit_length(1.0)
	if state.aim_hold[slot] >= 0.0:
		return state.aim_lock[slot]
	return weapons.auto_aim(self, state, weapon_defs[state.weapons[slot]])


## The target a TARGETED weapon would throw at (locked at the press while held).
func resolved_target(state: PlayerState, slot: int) -> int:
	if state.aim_hold[slot] >= 0.0:
		return state.aim_target[slot]
	var target: PlayerState = nearest_enemy(state, weapon_defs[state.weapons[slot]].max_range)
	return target.id if target != null else -1


func _lock_aim(state: PlayerState, slot: int) -> void:
	var def: WeaponDef = weapon_defs[state.weapons[slot]]
	state.aim_lock[slot] = weapons.auto_aim(self, state, def)
	var target: PlayerState = nearest_enemy(state, def.max_range)
	state.aim_target[slot] = target.id if target != null else -1


func _try_fire(state: PlayerState, slot: int, stick: Vector2, hold_seconds: float) -> void:
	if not state.can_act() or not weapon_ready(state, slot):
		return
	var def: WeaponDef = weapon_defs[state.weapons[slot]]
	var aim: Vector2 = resolved_aim(state, slot, stick)
	if weapons.fire(self, state, def, aim, hold_seconds, state.aim_target[slot]):
		state.weapon_cooldowns[slot] = def.cooldown
		state.cast_lock_left = def.cast_lock
		weapon_cast.emit(state.id, def.id)


func _start_dash(state: PlayerState, input: PlayerInput) -> void:
	var direction: Vector2 = state.facing
	if input.move.length_squared() > 0.0:
		direction = input.move.normalized()
	state.dash_direction = direction
	state.facing = direction
	state.dash_time_left = rules.dash_duration
	state.dash_cooldown_left = rules.dash_cooldown
	player_dashed.emit(state.id)


## The pin button works like an aimed skill: press while it is ready and you aim
## (drag to choose the direction), release to dash; a tap dashes the way the player
## faces. Pressing while out on the pin brings you back at once, even mid-tumble.
func _handle_pin_button(state: PlayerState, input: PlayerInput, previous: int, dt: float) -> void:
	var held: bool = input.is_pressed(PlayerInput.BTN_BOOKMARK)
	var was_held: bool = (previous & PlayerInput.BTN_BOOKMARK) != 0
	if held and not was_held:
		if state.mark_active:
			_return_to_mark(state)
			state.pin_aim_hold = -1.0
		elif state.can_act() and state.bookmark_ready():
			state.pin_aim_hold = 0.0
		else:
			state.pin_aim_hold = -1.0
	elif held and state.pin_aim_hold >= 0.0:
		state.pin_aim_hold = -1.0 if not state.can_act() else state.pin_aim_hold + dt
	elif not held and was_held and state.pin_aim_hold >= 0.0:
		state.pin_aim_hold = -1.0
		if not input.is_pressed(PlayerInput.BTN_AIM_CANCEL) and state.can_act() and state.bookmark_ready():
			_use_bookmark(state, input.aim)


## The direction a pin dash would take now: the drag past the deadzone, otherwise
## the way the player faces.
func resolved_pin_aim(state: PlayerState, stick: Vector2) -> Vector2:
	if stick.length() >= rules.aim_deadzone:
		return stick.normalized()
	return state.facing


## The pin (Bookmark): stick a pin where you stand, dash a short way in `aim` (or
## the facing), tumble, and after `bookmark_boost_duration` snap back to the pin.
func _use_bookmark(state: PlayerState, aim: Vector2 = Vector2.ZERO) -> void:
	var direction: Vector2 = resolved_pin_aim(state, aim)
	state.facing = direction
	state.mark_position = state.position
	state.mark_active = true
	state.boost_time_left = rules.bookmark_boost_duration
	_move_by(state, direction * rules.bookmark_blink)
	state.stumble_time_left = rules.bookmark_tumble
	bookmark_used.emit(state.id)


## Back to the pin (early, or when the timer runs out); the cooldown starts now.
func _return_to_mark(state: PlayerState) -> void:
	if state.mark_active and rules.bookmark_returns:
		state.position = state.mark_position
	state.mark_active = false
	state.boost_time_left = 0.0
	state.stumble_time_left = 0.0
	# the cooldown only starts once the player is back at the pin
	state.bookmark_cooldown_left = rules.bookmark_cooldown


func _tick_boost(state: PlayerState, dt: float) -> void:
	if state.boost_time_left <= 0.0:
		return
	state.boost_time_left -= dt
	if state.boost_time_left <= 0.0:
		_return_to_mark(state)


func _move(state: PlayerState, input: PlayerInput, dt: float) -> void:
	if state.dash_time_left > 0.0:
		var active: float = minf(dt, state.dash_time_left)
		_move_by(state, state.dash_direction * (rules.dash_distance / rules.dash_duration) * active)
		state.dash_time_left -= dt
		if state.dash_time_left <= 0.0:
			state.dash_time_left = 0.0
			state.stumble_time_left = rules.dash_stumble
		return
	if state.stumble_time_left > 0.0:
		state.stumble_time_left = maxf(0.0, state.stumble_time_left - dt)
		return
	if state.cast_lock_left > 0.0:
		# a heavy attack's cast animation: aiming was free while moving, but now stand still
		state.cast_lock_left = maxf(0.0, state.cast_lock_left - dt)
		return
	if input == null or not state.effects.can_move():
		return
	var move: Vector2 = input.move.limit_length(1.0)
	if move.length_squared() > 0.0:
		state.facing = move.normalized()
	var speed: float = rules.move_speed
	if state.boost_time_left > 0.0:
		speed *= 1.0 + rules.bookmark_speed_bonus
	speed *= state.effects.speed_multiplier(rules.polymorph_speed_scale)
	_move_by(state, move * speed * dt)


## Moves by `delta` in sub-steps no longer than the player's radius so fast
## moves (dash, blink) can never tunnel through an obstacle.
func _move_by(state: PlayerState, delta: Vector2) -> void:
	var length: float = delta.length()
	if length <= 0.0:
		return
	var count: int = maxi(1, ceili(length / state.radius))
	var piece: Vector2 = delta / count
	for i: int in count:
		state.position = Collision.resolve(state.position + piece, state.radius, _blocking)


## Slot 0 next to the post, then alternating +x / -x by spawn_spacing.
func _spawn_position(side: int, slot: int) -> Vector2:
	var base: Vector2 = layout.spawn_center(side)
	var offset: int = ceili(slot / 2.0)
	var direction: int = 1 if slot % 2 == 1 else -1
	return base + Vector2(direction * offset * rules.spawn_spacing, 0.0)


## What stops `team`'s players and throws: the street edges and every obstacle
## (cover is the same for both teams).
func blocking_rects_for_team(_team: int) -> Array[Rect2]:
	return _blocking


## Index of the obstacle at `point`, or -1.
func obstacle_at_point(point: Vector2) -> int:
	for index: int in obstacles.size():
		if obstacles[index].has_point(point):
			return index
	return -1


## The players a capture needs: everyone on `team` except training dummies.
func _capture_members(team: int) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for id: int in players:
		if players[id].team == team and not _brains.has(id):
			result.append(players[id])
	return result


## Every player of `team` free and standing in the enemy base.
func team_in_enemy_base(team: int) -> bool:
	var members: Array[PlayerState] = _capture_members(team)
	if members.is_empty():
		return false
	var enemy_side: int = -side_for_team(team)
	for state: PlayerState in members:
		if state.tagged or not layout.in_base(enemy_side, state.position):
			return false
	return true


## Every player of the other team waiting in a box (a team of training dummies
## never scores this way).
func all_enemies_tagged(team: int) -> bool:
	var members: Array[PlayerState] = _capture_members(1 - team)
	if members.is_empty() or _capture_members(team).is_empty():
		return false
	for state: PlayerState in members:
		if not state.tagged:
			return false
	return true


## The capture countdown runs while a team keeps a capture going (whole team in the
## enemy base, or every enemy tagged); it restarts as soon as that breaks.
func _check_captures(dt: float) -> void:
	var team: int = -1
	var kind: CaptureKind = CaptureKind.NONE
	for candidate: int in [0, 1]:
		if team_in_enemy_base(candidate):
			team = candidate
			kind = CaptureKind.BASE
			break
		if all_enemies_tagged(candidate):
			team = candidate
			kind = CaptureKind.ALL_TAGGED
			break
	if team != capture_team or kind != capture_kind:
		capture_team = team
		capture_kind = kind
		capture_elapsed = 0.0
	if team < 0:
		return
	capture_elapsed += dt
	if capture_elapsed >= rules.capture_time:
		_score_point(team, kind)


## Seconds left on the running capture countdown (0 when none runs).
func capture_time_left() -> float:
	if capture_team < 0:
		return 0.0
	return maxf(0.0, rules.capture_time - capture_elapsed)


func _score_point(team: int, how: CaptureKind) -> void:
	var result: MatchScore.Result = score.award_point(team)
	_clear_capture()
	point_scored.emit(team, how)
	if result == MatchScore.Result.MATCH:
		phase = Phase.MATCH_OVER
		set_won.emit(team)
		match_won.emit(team)
		return
	if result == MatchScore.Result.SET:
		_new_set_pending = true
		set_won.emit(team)
	phase = Phase.POINT_FREEZE
	freeze_left = rules.point_freeze_time


func _end_freeze() -> void:
	if _new_set_pending:
		_new_set_pending = false
		_team0_side = -_team0_side
		for id: int in players:
			var spawn: Vector2 = players[id].spawn_position
			players[id].spawn_position = -spawn
		sides_switched.emit()
	_reset_round()
	phase = Phase.PLAYING
	point_reset.emit()


func _clear_capture() -> void:
	capture_team = -1
	capture_kind = CaptureKind.NONE
	capture_elapsed = 0.0


## Everyone back to their post at full HP, out of the boxes, cooldowns and effects
## cleared; weapon objects are removed.
func _reset_round() -> void:
	weapons.reset()
	_clear_capture()
	for id: int in players:
		var state: PlayerState = players[id]
		var was_tagged: bool = state.tagged
		_clear_actions(state)
		state.position = state.spawn_position
		state.facing = Vector2(0.0, -side_for_team(state.team))
		state.hp = rules.player_max_hp
		state.tagged = false
		state.tag_time = 0.0
		state.dash_cooldown_left = 0.0
		state.bookmark_cooldown_left = 0.0
		for slot: int in state.weapon_cooldowns.size():
			state.weapon_cooldowns[slot] = 0.0
		if was_tagged:
			player_rescued.emit(id, RELEASED_ALONE)
