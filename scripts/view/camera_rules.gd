class_name CameraRules
extends Resource
## The gameplay camera for a portrait (9:16) phone: a perspective camera above and
## behind the hero at a fixed, fairly low downward angle (40 degrees, like the
## street-game reference: you see far up the street) with a wide lens, straight behind
## (`yaw_offset_degrees`), with the hero held near the lower centre of the screen
## so the battlefield ahead fills the rest. The distance is derived so that
## `visible_width` metres of lane are on screen at the camera's aim point, whatever
## the phone's aspect ratio. The aim point follows the hero and is clamped by the
## map: the camera stops scrolling when its view reaches an edge of the map, and
## the hero then walks toward that screen edge. Pure math on data from
## data/rules/camera_rules.tres.

## The design screen: portrait 9:16.
const DESIGN_ASPECT: float = 9.0 / 16.0

## The camera sits behind and to the right of the hero (a bird's-eye view from the
## back right): it is turned this many degrees around the hero, so the street runs
## diagonally up the screen from bottom left to top right.
@export var yaw_offset_degrees: float = 0.0
## Pitch from horizontal, in degrees.
@export var pitch_degrees: float = 0.0
## VERTICAL field of view, in degrees.
@export var vfov_degrees: float = 0.0
## Metres of lane width visible at the hero (the camera distance follows from it).
@export var visible_width: float = 0.0
## How far past the lane edge (m) the view may reach when the hero is at the curb.
@export var edge_margin: float = 0.0
## How far past each lane end (m) the view may reach (the outer wall stays on screen).
@export var end_margin: float = 0.0
## Where the hero sits on screen, as a fraction of the height from the top (0.5 =
## centre, larger = lower). The aim point is placed ahead of the hero to match.
@export var player_screen_y: float = 0.5
## The top of the screen under the HUD (minimap, score), as a fraction of the height.
## The far end of the map stops here, so a hero at the enemy end stays in sight.
@export var top_safe_y: float = 0.0
## Most ground (m) ahead of the aim point that counts as seen. At a low angle the top of
## the screen shows a far horizon (or sky), so this caps how far the view is said to reach.
@export var far_reach: float = 0.0
## How fast the camera catches up (1/s). Higher = snappier.
@export var follow_rate: float = 0.0
## Fraction of the hero's sideways position the camera follows.
@export var side_follow: float = 0.0
## Aspect ratios (width / height) the distance is computed for are kept in this range.
@export var min_aspect: float = 0.0
@export var max_aspect: float = 0.0


## Camera distance from the target for a screen of `aspect` (width / height):
## visible width = 2 * d * tan(vfov / 2) * aspect.
func distance(aspect: float) -> float:
	var clamped: float = clampf(aspect, min_aspect, max_aspect)
	return visible_width / (2.0 * tan(deg_to_rad(vfov_degrees / 2.0)) * clamped)


## Camera position relative to the target. Own side (+Z, no flip) looks toward -Z,
## so the camera sits behind on the +Z side (and `yaw_offset_degrees` to the right);
## the other team is mirrored.
func camera_offset(camera_distance: float, flip: bool) -> Vector3:
	var pitch: float = deg_to_rad(pitch_degrees)
	var back: float = camera_distance * cos(pitch)
	var yaw: float = deg_to_rad(yaw_degrees(flip))
	return Vector3(back * sin(yaw), camera_distance * sin(pitch), back * cos(yaw))


## The camera's turn around the vertical axis (0 = looking straight down -Z).
func yaw_degrees(flip: bool) -> float:
	return yaw_offset_degrees + (180.0 if flip else 0.0)


## Ground distance (m) from the aim point to the place that shows `screen_y` of the
## way down the screen (0 = top, 1 = bottom): positive = behind the aim point
## (toward the camera), negative = ahead of it. Exact perspective, no approximation.
func ground_offset(camera_distance: float, screen_y: float) -> float:
	var pitch: float = deg_to_rad(pitch_degrees)
	var height: float = camera_distance * sin(pitch)
	var back: float = camera_distance * cos(pitch)
	var below_axis: float = atan((screen_y * 2.0 - 1.0) * tan(deg_to_rad(vfov_degrees / 2.0)))
	var depression: float = pitch + below_axis
	if depression <= 0.001:
		return -INF  # the top of the screen shows the sky
	return back - height / tan(depression)


## How far ahead of the hero the camera aims so the hero sits at `player_screen_y`.
func look_ahead(camera_distance: float) -> float:
	return ground_offset(camera_distance, player_screen_y)


## Where the camera aims: ahead of the hero toward the enemy base, following them
## sideways. Clamped by the map: the view (bottom edge behind the aim point, the top
## below the HUD ahead of it) never runs past a lane end by more than `end_margin`, and its
## width never past a lane side by more than `edge_margin`. When the view is bigger
## than the map in a direction, it stays centred.
func clamp_target(world_pos: Vector2, layout: MapLayout, flip: bool = false, camera_distance: float = -1.0) -> Vector2:
	var reach: float = camera_distance if camera_distance > 0.0 else distance(DESIGN_ASPECT)
	var forward: float = 1.0 if flip else -1.0  # toward the enemy base, in world Z
	var behind: float = ground_offset(reach, 1.0)
	var ahead: float = minf(-ground_offset(reach, top_safe_y), far_reach)
	var end: float = layout.lane_length / 2.0 + end_margin
	var z: float = world_pos.y + forward * look_ahead(reach)
	# the view spans [z - forward * behind ... z + forward * ahead] along Z
	var low: float = -end + (behind if flip else ahead)
	var high: float = end - (ahead if flip else behind)
	z = (low + high) / 2.0 if low > high else clampf(z, low, high)
	var side_limit: float = maxf(0.0, layout.lane_width / 2.0 + edge_margin - visible_width / 2.0)
	var x: float = clampf(world_pos.x * side_follow, -side_limit, side_limit)
	return Vector2(x, z)


## Fraction of the remaining distance to cover this frame (frame-rate independent).
func follow_weight(delta: float) -> float:
	return 1.0 - exp(-follow_rate * delta)
