shader_type canvas_item;
// A soft focus for everything beyond the two ends of the play area (the far buildings above the top
// end, anything below the bottom end), like a camera focused on the street. The match view tells
// the shader where the two end lines are on screen each frame; the further past them, the blurrier.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// screen heights (0 top .. 1 bottom) of the far end line and the near end line of the play area
uniform float top_line = 0.0;
uniform float bottom_line = 1.0;
// how far past a line (in screen heights) the blur reaches full strength
uniform float falloff = 0.12;
// the blur radius at full strength, in pixels
uniform float radius_px = 5.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float above = clamp((top_line - uv.y) / falloff, 0.0, 1.0);
	float below = clamp((uv.y - bottom_line) / falloff, 0.0, 1.0);
	float amount = max(above, below);
	amount = amount * amount * (3.0 - 2.0 * amount);
	if (amount <= 0.001) {
		COLOR = vec4(texture(screen_tex, uv).rgb, 1.0);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE * radius_px * amount;
		vec3 sum = texture(screen_tex, uv).rgb * 0.16;
		// two rings of taps (a soft disc)
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 d = vec2(cos(a), sin(a));
			sum += texture(screen_tex, uv + d * px * 0.5).rgb * 0.07;
			sum += texture(screen_tex, uv + d * px).rgb * 0.035;
		}
		COLOR = vec4(sum, 1.0);
	}
}
