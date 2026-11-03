shader_type canvas_item;
render_mode unshaded;

uniform vec2 virtual_resolution = vec2(320.0, 180.0);
uniform sampler2D source_texture;
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 7.0;
uniform int dither_mode = 1;
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform bool outline_enabled = true;
uniform float outline_strength : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float outline_threshold : hint_range(0.02, 0.8, 0.01) = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float v = 0.0;

	if (i == 0) v = 0.0;
	if (i == 1) v = 8.0;
	if (i == 2) v = 2.0;
	if (i == 3) v = 10.0;
	if (i == 4) v = 12.0;
	if (i == 5) v = 4.0;
	if (i == 6) v = 14.0;
	if (i == 7) v = 6.0;
	if (i == 8) v = 3.0;
	if (i == 9) v = 11.0;
	if (i == 10) v = 1.0;
	if (i == 11) v = 9.0;
	if (i == 12) v = 15.0;
	if (i == 13) v = 7.0;
	if (i == 14) v = 13.0;
	if (i == 15) v = 5.0;

	return (v + 0.5) / 16.0;
}

vec3 posterize(vec3 color, float levels) {
	float safe_levels = max(levels - 1.0, 1.0);
	return floor(color * safe_levels + 0.5) / safe_levels;
}

float edge_at(vec2 uv, vec2 texel) {
	vec3 c = texture(source_texture, uv).rgb;
	vec3 r = texture(source_texture, uv + vec2(texel.x, 0.0)).rgb;
	vec3 l = texture(source_texture, uv - vec2(texel.x, 0.0)).rgb;
	vec3 u = texture(source_texture, uv + vec2(0.0, texel.y)).rgb;
	vec3 d = texture(source_texture, uv - vec2(0.0, texel.y)).rgb;
	return (length(c - r) + length(c - l) + length(c - u) + length(c - d)) * 0.5;
}

void fragment() {
	vec2 safe_resolution = max(virtual_resolution, vec2(1.0, 1.0));
	vec2 pixel_coord = floor(UV * safe_resolution);
	vec2 pixel_uv = (pixel_coord + vec2(0.5, 0.5)) / safe_resolution;
	vec2 texel = 1.0 / safe_resolution;

	vec4 source = texture(source_texture, pixel_uv);

	float dither_value = 0.5;
	if (dither_mode == 1) {
		dither_value = hash(pixel_coord);
	} else if (dither_mode == 2) {
		dither_value = bayer4(pixel_coord);
	}

	if (dither_mode != 0) {
		source.rgb += (dither_value - 0.5) * dither_strength / max(color_levels, 1.0);
	}

	source.rgb = posterize(clamp(source.rgb, vec3(0.0), vec3(1.0)), color_levels);

	if (outline_enabled) {
		float edge = edge_at(pixel_uv, texel);
		float line = smoothstep(outline_threshold, outline_threshold + 0.08, edge);
		vec3 outline_color = vec3(0.025, 0.027, 0.035);
		source.rgb = mix(source.rgb, outline_color, line * outline_strength);
	}

	COLOR = vec4(source.rgb, source.a);
}
