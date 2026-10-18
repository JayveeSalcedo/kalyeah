class_name PatinteroRules
extends Resource
## Patintero numbers (docs/GDD.md "Patintero"). Values live in data/rules/patintero_rules.tres;
## nothing here is hardcoded. Walking speed, the kids' size and the tick rate come from
## GameRules, the street from MapLayout.

## The grid runs up the street (along Z) and is this wide (x from -half to +half).
@export var field_half_width: float = 0.0
## The start line across the bottom of the grid: the runners' home is behind it (z greater).
@export var start_line_z: float = 0.0
## The back line across the top: a runner who gets past it (z smaller) turns for home.
@export var back_line_z: float = 0.0
## The guarded lines across the grid, bottom to top; one line guard stands on each.
@export var guard_lines: Array[float] = []
## A tagger touching a runner in the grid within this distance (centre to centre) catches them.
@export var tag_distance: float = 0.0
## A runner whose centre steps past a side line inside the grid is caught (off: the side
## lines are walls instead).
@export var out_of_bounds_catches: bool = true
## Taggers walk at this fraction of normal speed along their line.
@export var tagger_speed_scale: float = 0.0
## Where the runners start each turn: a row this far behind the start line, this far apart.
@export var home_row_offset: float = 0.0
@export var runner_spacing: float = 0.0
## A turn ends after this long even if nobody is caught (the teams switch).
@export var turn_time: float = 0.0
## Freeze after a catch or a timeout before the teams switch.
@export var switch_freeze_time: float = 0.0
## The opening show before play (everyone at their spot, nothing moves).
@export var intro_time: float = 0.0
## The first team to this many points wins.
@export var points_to_win: int = 0
## Safety limit: after this many turns the team with more points wins (level = a draw).
@export var max_turns: int = 0
## Practice bots: seconds between a bot's decisions (random between), its reaction time.
@export var bot_reaction_min: float = 0.0
@export var bot_reaction_max: float = 0.0
## A runner bot crosses a guarded line only when its guard is at least this far away along it;
## it picks the gap afresh at each decision between these two (bold to careful).
@export var bot_gap_min: float = 0.0
@export var bot_gap_max: float = 0.0
## Inside the grid a runner bot switches sides across the middle line only when the centre
## guard is at least this far away up or down the grid.
@export var bot_middle_gap: float = 0.0
## Runner bots wait this far outside a guard's reach before dashing across its line.
@export var bot_line_margin: float = 0.0
## Runner bots keep this far inside the side lines.
@export var bot_side_margin: float = 0.0
## Runner bots go this far past the back line before turning for home.
@export var bot_far_margin: float = 0.0
