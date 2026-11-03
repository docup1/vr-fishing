shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float wave_time = 0.0;
uniform vec4 deep_color : source_color = vec4(0.055, 0.24, 0.29, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.18, 0.43, 0.43, 1.0);
varying vec3 water_world;
varying float wave_height;

void vertex() {
	vec2 p = VERTEX.xz;
	float a = p.x * 0.65 + p.y * 0.35 + wave_time * 0.9;
	float b = p.x * -0.35 + p.y * 0.75 + wave_time * 0.65;
	wave_height = 0.035 * sin(a) + 0.022 * sin(b);
	VERTEX.y += wave_height;
	float dx = 0.035 * 0.65 * cos(a) - 0.022 * 0.35 * cos(b);
	float dz = 0.035 * 0.35 * cos(a) + 0.022 * 0.75 * cos(b);
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
	water_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ripples = sin(water_world.x * 2.2 + water_world.z * 1.3 + wave_time * 1.2)
		* sin(water_world.z * 1.8 - water_world.x * 0.8 - wave_time * 0.8);
	float variation = clamp(0.5 + wave_height * 6.0 + ripples * 0.07, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, variation);
	ROUGHNESS = 0.18;
	SPECULAR = 0.65;
}
