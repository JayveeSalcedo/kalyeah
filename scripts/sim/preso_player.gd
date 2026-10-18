class_name PresoPlayer
extends PlayerState
## One kid in Tumbang Preso: the shared PlayerState (position, facing, kid) plus the
## slipper and the tallies. Plain data; PresoSim owns and mutates it. Nobody is ever
## `tagged` in the PlayerState sense here: a tag makes you the taya instead.

## The slipper is in your hand (false while it flies or lies on the street).
var has_slipper: bool = true
## Times this kid became the taya by a tag or by being too slow (the match is won by the fewest).
var times_tagged: int = 0
## Times this kid's slipper knocked the can over (first tie-break).
var knockdowns: int = 0
## Seconds spent as the taya (second tie-break: less is better).
var taya_time: float = 0.0
## Seconds held behind the line with the slipper since the last throw (see PresoRules.shot_clock).
var shot_time: float = 0.0
## Seconds waited behind the line without the slipper since it left your hand (see PresoRules.home_grace).
var home_wait: float = 0.0
## Where this kid stands behind the line at the start of a round.
var home_spot: Vector2 = Vector2.ZERO
