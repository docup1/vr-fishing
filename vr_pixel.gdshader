shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

// Applied to the already rendered view independently for each XR eye.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform float pixel_size : hint_range(1.0, 12.0, 1.0) = 4.0;
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 18.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 pixel_uv = (floor(SCREEN_UV * VIEWPORT_SIZE / pixel_size) + vec2(0.5)) * pixel_size / VIEWPORT_SIZE;
	vec3 color = textureLod(screen_texture, clamp(pixel_uv, vec2(0.0), vec2(1.0)), 0.0).rgb;
	ALBEDO = floor(color * color_levels + vec3(0.5)) / color_levels;
	ALPHA = 1.0;
}
