class_name PatinteroPlayer
extends PlayerState
## One kid in Patintero: the shared PlayerState (team, position, facing, kid) plus this turn's
## role. Plain data; PatinteroSim owns and mutates it. Nobody is `tagged` in the PlayerState
## sense here: a catch switches the teams instead.

enum Role { RUNNER, LINE_GUARD, CENTRE_GUARD }

var role: Role = Role.RUNNER
## LINE_GUARD: which of PatinteroRules.guard_lines this kid stands on.
var line_index: int = 0
## RUNNER: got past the back line this trip; crossing the start line home now scores.
var reached_back: bool = false
## Points this kid has brought home this match (the team's points are the sum).
var points: int = 0
