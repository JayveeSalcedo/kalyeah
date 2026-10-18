class_name StreetGameView
extends RefCounted
## Camera finish shared by the street-game practice screens (Tumbang Preso, Patintero), the same
## as the main match (PracticeMatchPresentation): the wide curve lens, the soft focus beyond the
## ends of the play area and the film finish, plus the mouse on the ground through the lens.
## View only.


## Adds the lens, the far blur and the film finish over `owner`'s 3D view; returns the far blur's
## material (null when it is off), for update_far_blur().
static func add_camera_finish(owner: Node, camera: FollowCamera) -> ShaderMaterial:
	Cinematic.add_lens(owner, camera.rules.lens_k())
	var blur: ShaderMaterial = Cinematic.add_depth_blur(owner, camera.rules.far_blur_pixels, camera.rules.far_blur_falloff, camera.rules.far_blur_hold)
	Cinematic.add_film_finish(owner)
	return blur


## Tells the far blur where the two ends of the play area are on screen, so everything beyond
## them goes out of focus (call after the camera moved).
static func update_far_blur(blur: ShaderMaterial, camera: FollowCamera, layout: MapLayout) -> void:
	if blur == null or not camera.is_inside_tree():
		return
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	if size.y <= 0.0:
		return
	var half: float = layout.lane_length / 2.0
	var rows: Array[float] = []
	for z: float in [-half, half]:
		rows.append(camera.screen_position(Vector3(0.0, 0.0, z)).y / size.y)
	blur.set_shader_parameter("top_line", minf(rows[0], rows[1]))
	blur.set_shader_parameter("bottom_line", maxf(rows[0], rows[1]))


## The point on the ground under the mouse (x, z), through the lens; null when the ray misses.
static func mouse_on_ground(camera: FollowCamera) -> Variant:
	var viewport: Viewport = camera.get_viewport()
	if viewport == null:
		return null
	var flat: Vector2 = camera.flat_position(viewport.get_mouse_position())
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(flat), camera.project_ray_normal(flat))
	if hit == null:
		return null
	var point: Vector3 = hit as Vector3
	return Vector2(point.x, point.z)
