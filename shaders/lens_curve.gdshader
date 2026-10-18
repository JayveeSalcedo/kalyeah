shader_type canvas_item;
// The wide curve lens (owner): the 3D picture is bent like a wide-angle lens, the middle kept at
// its size and the edges pulled in (barrel distortion). The camera renders a wider field of view
// to feed it (FollowCamera), so the middle looks as before and more of the street shows at the
// sides. Keep the maths in step with scripts/view/lens_curve.gd (it moves the health bars the
// same way). Drawn under the HUD, which is not bent.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float k = 0.25;

void fragment() {
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	vec2 source = p * (1.0 + k * dot(p, p)) / (1.0 + k);
	COLOR = vec4(texture(screen_tex, clamp(source * 0.5 + 0.5, vec2(0.0), vec2(1.0))).rgb, 1.0);
}
