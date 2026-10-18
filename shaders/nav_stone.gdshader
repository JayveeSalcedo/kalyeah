shader_type canvas_item;
// The main screen's bottom bar: dark blue cement with lighter partition lines between the tabs and
// a smooth, lighter top (no hard top line). The open tab's slot is a little lighter. Everything is
// drawn here from the control's size, no image file.

uniform vec2 rect_size = vec2(720.0, 104.0);
uniform float tabs = 5.0;
// where the tabs start and end (the screen's side margins are left outside, like the reference bar)
uniform vec2 inner = vec2(0.0, 720.0);
uniform float active_tab = 2.0;
uniform vec3 cement : source_color = vec3(0.10, 0.17, 0.32);
uniform vec3 top_light : source_color = vec3(0.34, 0.47, 0.70);

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
	float tab_w = (inner.y - inner.x) / tabs;
	vec3 colour = cement;
	// cement: soft blotches, a mottle and a fine grain
	colour *= 1.0 + (value_noise(p / 60.0) - 0.5) * 0.18;
	colour *= 1.0 + (value_noise(p / 14.0 + 5.0) - 0.5) * 0.14;
	colour *= 1.0 + (value_noise(p / 2.5) - 0.5) * 0.10;
	// the open tab's slot is lighter, brightest at the top
	float here = floor((p.x - inner.x) / tab_w);
	float slot = step(here, active_tab) * step(active_tab, here) * step(inner.x, p.x) * step(p.x, inner.y);
	colour += slot * mix(vec3(0.13, 0.17, 0.26), vec3(0.04, 0.06, 0.10), smoothstep(0.0, rect_size.y, p.y));
	// a smooth, lighter top: the light fades down into the cement
	float fade = 1.0 - smoothstep(0.0, 34.0, p.y);
	colour = mix(colour, top_light, fade * fade * 0.85);
	// lighter partition lines between the tabs, each with a thin dark edge beside it
	float k = floor((p.x - inner.x) / tab_w + 0.5);
	if (k >= 0.0 && k <= tabs) {
		float d = p.x - (inner.x + k * tab_w);
		float line = 1.0 - smoothstep(0.6, 1.8, abs(d));
		// the dark edge is always on the inside of the tab strip
		float inward = k < tabs * 0.5 ? 3.0 : -3.0;
		float shadow = 1.0 - smoothstep(0.6, 2.4, abs(d - inward));
		float reach = smoothstep(2.0, 16.0, p.y);
		colour += vec3(0.20, 0.28, 0.42) * line * reach;
		colour -= vec3(0.05, 0.07, 0.10) * shadow * reach;
	}
	COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
