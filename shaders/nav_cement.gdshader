shader_type canvas_item;
// Light gray cement for the main screen's bottom bar: soft blotches, a mottle, fine grain and a few
// specks, all from value noise (no image file). Works in screen pixels, so it never repeats.

uniform vec4 base_color : source_color = vec4(0.66, 0.665, 0.675, 1.0);
uniform float strength = 1.0;

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
	vec2 p = FRAGCOORD.xy;
	float shade = 1.0;
	shade += (value_noise(p / 90.0) - 0.5) * 0.16 * strength;
	shade += (value_noise(p / 22.0 + 7.0) - 0.5) * 0.12 * strength;
	shade += (value_noise(p / 3.0 + 3.0) - 0.5) * 0.09 * strength;
	// a few darker pits and pale specks
	shade -= smoothstep(0.86, 0.97, value_noise(p / 5.0 + 17.0)) * 0.12 * strength;
	shade += smoothstep(0.9, 0.99, value_noise(p / 4.0 + 41.0)) * 0.07 * strength;
	COLOR = vec4(base_color.rgb * shade, 1.0);
}
