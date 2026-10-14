class_name MapLayout
extends Resource
## Geometry of the playground street, in meters. Pure data + math, no nodes.
## The street runs along Z: +Z is the "own" end (bottom of the portrait screen),
## -Z the enemy end. A side's post stands in its left corner as seen from that
## end (own: bottom-left, enemy: top-right), and the box its tagged players are
## sent to sits at the far end on the same left side (own: top-left, enemy:
## bottom-right). The map is point-symmetric, so both teams play the same street.
## All numbers come from data/rules/map_layout.tres.

const SIDE_OWN: int = 1
const SIDE_ENEMY: int = -1

## Playable street (width along X, length along Z).
@export var lane_length: float = 0.0
@export var lane_width: float = 0.0
## The post stands this far in from both edges of its corner.
@export var post_inset: float = 0.0
## The base is a chalk circle of this radius around the post (clipped by the street).
@export var base_radius: float = 0.0
## Where a side's players start and come back to after a rescue: this far from the
## post toward the middle of the street (along each axis).
@export var spawn_offset: float = 0.0
## The tagged box (a taped rectangle on the road) and its center's inset from its corner of
## the play area; half the size puts the box flush in the corner (no margin).
## It is just big enough for its slots: columns across, rows along the street.
@export var jail_size: Vector2 = Vector2.ZERO
@export var jail_inset: Vector2 = Vector2.ZERO
@export var jail_columns: int = 1
@export var jail_rows: int = 1
## Cover on the own half of the street (x, z rects); the enemy half gets the same
## pieces turned around the center. They block walking and throws for both teams.
@export var obstacles: Array[Rect2] = []
## Cosmetic: what each obstacle is drawn as (bench, cardboard_wall, school_zone, tent).
@export var obstacle_props: Array[StringName] = []
@export var boundary_thickness: float = 0.0
@export var overview_height: float = 0.0
@export var overview_size: float = 0.0


## Center of a side's post in the XZ plane (x, z): own bottom-left, enemy top-right.
func base_center(side: int) -> Vector2:
	return Vector2(-side * (lane_width / 2.0 - post_inset), side * (lane_length / 2.0 - post_inset))


## True when `position` is inside `side`'s base circle (the other team captures there).
func in_base(side: int, position: Vector2) -> bool:
	return position.distance_to(base_center(side)) <= base_radius


## Where a side's players start, and where a rescued player is sent back to.
func spawn_center(side: int) -> Vector2:
	return base_center(side) + Vector2(side, -side) * spawn_offset


## The box a side's tagged players are sent to: own top-left, enemy bottom-right.
func jail_rect(side: int) -> Rect2:
	var center: Vector2 = Vector2(
		-side * (lane_width / 2.0 - jail_inset.x), -side * (lane_length / 2.0 - jail_inset.y)
	)
	return Rect2(center - jail_size / 2.0, jail_size)


## Where the `index`-th tagged player of a side stands in its box (a grid of
## `jail_columns` x `jail_rows` kids; more than that share the first slots).
func jail_slot(side: int, index: int) -> Vector2:
	var box: Rect2 = jail_rect(side)
	var column: int = index % jail_columns
	var row: int = (index / jail_columns) % jail_rows
	return box.position + Vector2(
		box.size.x * (column + 0.5) / jail_columns, box.size.y * (row + 0.5) / jail_rows
	)


func lane_rect() -> Rect2:
	return Rect2(-lane_width / 2.0, -lane_length / 2.0, lane_width, lane_length)


## Every obstacle on the street: the own-half pieces plus the same pieces turned
## around the center for the enemy half. Index i (own) pairs with i + count (enemy).
func obstacle_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect: Rect2 in obstacles:
		result.append(rect)
	for rect: Rect2 in obstacles:
		result.append(Rect2(-rect.end, rect.size))
	return result


## The prop an obstacle is drawn as (same order as obstacle_rects()).
func obstacle_prop(index: int) -> StringName:
	if obstacle_props.is_empty():
		return &"cardboard_wall"
	return obstacle_props[index % obstacles.size() % obstacle_props.size()]


## Left, right and the two end walls enclosing the street.
func boundary_rects() -> Array[Rect2]:
	var t: float = boundary_thickness
	var result: Array[Rect2] = []
	result.append(Rect2(-lane_width / 2.0 - t, -lane_length / 2.0, t, lane_length))
	result.append(Rect2(lane_width / 2.0, -lane_length / 2.0, t, lane_length))
	result.append(Rect2(-lane_width / 2.0 - t, -lane_length / 2.0 - t, lane_width + 2.0 * t, t))
	result.append(Rect2(-lane_width / 2.0 - t, lane_length / 2.0, lane_width + 2.0 * t, t))
	return result
