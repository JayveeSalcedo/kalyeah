class_name PresoRules
extends Resource
## Tumbang Preso numbers (docs/GDD.md "Tumbang Preso"). Values live in
## data/rules/preso_rules.tres; nothing here is hardcoded. Walking speed, the kids'
## size and the tick rate come from GameRules, the street from MapLayout.

## The home line across the street: throwers are safe behind it (z greater than this)
## and throw from there; the taya can never cross it.
@export var throw_line_z: float = 0.0
## Where the can stands, in the middle of its chalk circle.
@export var can_spot: Vector2 = Vector2.ZERO
## The chalk circle round the can: a taya carrying the can into it stands it back up.
@export var can_circle_radius: float = 0.0
## A slipper passing this close to the standing can knocks it over.
@export var can_hit_radius: float = 0.0
## How far a knocked can rolls on along the slipper's path.
@export var knock_distance: float = 0.0
## A knocked can always stops at least this far in front of the home line (the taya must reach it).
@export var can_line_margin: float = 0.0
## Slippers and the can stay this far inside the street edges.
@export var edge_margin: float = 0.0
## The taya picks a fallen can up within this distance.
@export var can_pickup_distance: float = 0.0
## Where the taya starts each round: this far from the can toward the home line.
@export var guard_offset: float = 0.0
## Where the throwers start each round: a row this far behind the line, this far apart.
@export var home_row_offset: float = 0.0
@export var home_spacing: float = 0.0
@export var slipper_speed: float = 0.0
@export var slipper_range: float = 0.0
## A throw always goes up the street: at most this many degrees off straight ahead.
@export var max_throw_angle: float = 0.0
## A tap (no drag) aims at the can, off by up to this many degrees either way.
@export var auto_aim_spread: float = 0.0
## A thrower picks their own slipper up within this distance.
@export var slipper_pickup_distance: float = 0.0
## The taya tags a thrower within this distance (centre to centre).
@export var tag_distance: float = 0.0
## Holding your slipper behind the line this long throws it for you.
@export var shot_clock: float = 0.0
## Waiting behind the line without your slipper this long (in total, until you pick it
## up again) counts as being tagged ("too slow").
@export var home_grace: float = 0.0
## Match length in seconds of play (the clock stops in the freeze after a tag).
@export var match_length: float = 0.0
## Freeze after a tag before the new taya takes the can.
@export var tag_freeze_time: float = 0.0
## The opening show before play (everyone at their spot, nothing moves).
@export var intro_time: float = 0.0
## Practice bots: seconds a bot waits behind the line before it throws (random between).
@export var bot_reaction_min: float = 0.0
@export var bot_reaction_max: float = 0.0
## Practice bots miss the can's centre by up to this many degrees either way.
@export var bot_aim_error: float = 0.0
## A bot runs for its slipper when the taya is at least this far from it.
@export var bot_safe_distance: float = 0.0
## A bot out of home runs back when the taya comes this close.
@export var bot_danger_distance: float = 0.0
## A bot goes for its slipper whatever the taya does with this little home time left.
@export var bot_desperate_time: float = 0.0
## A taya bot chases throwers this close to the can; farther ones it lets go.
@export var bot_guard_radius: float = 0.0
