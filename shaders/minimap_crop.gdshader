shader_type canvas_item;
// Crops everything the minimap draws to a rounded rectangle with a smooth (anti-aliased) edge.

uniform vec2 rect_size = vec2(90.0, 180.0);
uniform float radius = 12.0;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX; // in the minimap's own pixels
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 corner = abs(local_position - half_size) - (half_size - vec2(radius));
	float distance_to_edge = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - radius;
	COLOR.a *= 1.0 - smoothstep(-0.7, 0.7, distance_to_edge);
}
