shader_type canvas_item;
// The main screen's bottom bar as a castle wall of light stone slabs (Clash of Clans style): rows of
// bevelled blocks laid like bricks, soft highlights on the top and left of every slab, a shaded
// bottom and right, dark mortar between them, a gentle tone change from slab to slab and a fine
// grain. Everything is drawn here from the control's size, no image file.

uniform vec2 rect_size = vec2(720.0, 104.0);
uniform vec2 slab = vec2(120.0, 50.0);
uniform vec3 stone : source_color = vec3(0.84, 0.81, 0.74);
uniform vec3 mortar : source_color = vec3(0.50, 0.47, 0.42);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * rect_size;
	// the first row of slabs starts just under the bar's lip
	float lip = 7.0;
	float y = max(p.y - lip, 0.0);
	float row = floor(y / slab.y);
	// (a bar one slab high has a single row: every tab sits on its own slab)
	float shift = mod(row, 2.0) * slab.x * 0.5;
	vec2 q = vec2(p.x + shift, y);
	vec2 cell = floor(q / slab);
	vec2 f = fract(q / slab) * slab;
	float to_left = f.x;
	float to_right = slab.x - f.x;
	float to_top = f.y;
	float to_bottom = slab.y - f.y;
	float nearest = min(min(to_left, to_right), min(to_top, to_bottom));

	float tone = hash(cell) - 0.5;
	vec3 colour = stone * (1.0 + tone * 0.10);
	// soft blotches inside the slab and a fine grain
	colour *= 1.0 + (value_noise(p / 17.0 + cell * 3.1) - 0.5) * 0.07;
	colour *= 1.0 + (value_noise(p / 2.5) - 0.5) * 0.05;
	// bevel: lit top and left edges, shaded bottom and right edges
	float lit = (1.0 - smoothstep(2.0, 9.0, to_top)) + 0.6 * (1.0 - smoothstep(2.0, 8.0, to_left));
	float shaded = (1.0 - smoothstep(2.0, 10.0, to_bottom)) + 0.6 * (1.0 - smoothstep(2.0, 9.0, to_right));
	colour += lit * 0.09;
	colour -= shaded * 0.13;
	// a faint dent in the middle of each slab
	colour -= 0.03 * smoothstep(0.35, 0.0, length((f - slab * 0.5) / slab));

	// mortar between the slabs
	float joint = 1.0 - smoothstep(1.2, 3.2, nearest);
	colour = mix(colour, mortar, joint);

	// the lip: a lighter cap along the top edge with a dark line under it
	if (p.y < lip) {
		colour = stone * 1.08 + 0.04 * (1.0 - p.y / lip);
		colour = mix(colour, mortar * 0.85, smoothstep(lip - 3.0, lip - 1.0, p.y));
	}
	// a thin shadow along the very top so the bar sits on the screen
	colour *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, 2.0, p.y));
	COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
