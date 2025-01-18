shader_type spatial;

uniform float cloud_scale : hint_range(0.1, 10.0) = 5.0;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 highlight_color : source_color = vec3(1.2, 1.2, 1.5);

// Noise function
float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float perlin_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(
			mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x),
			f.y
		),
		mix(
			mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x),
			f.y
		),
		f.z
	);
}

// Fractional Brownian Motion
float fbm(vec3 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < octaves; i++) {
		value += amplitude * perlin_noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}

	return value;
}

void fragment() {
	// Generate 3D coordinates for noise
	vec3 world_pos = (VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 noise_pos = world_pos / cloud_scale + vec3(TIME * cloud_speed, 0.0, 0.0);

	// Compute FBM noise for cloud density
	float noise = fbm(noise_pos, 4);

	// Adjust noise value with density control
	noise = smoothstep(0.0, 1.0, noise - (1.0 - cloud_density));

	// Add depth fading (fade clouds toward horizon)
	float depth_fade = clamp((world_pos.y + 50.0) / 10.0, 0.0, 1.0);

	// Calculate final color with highlights
	vec3 final_color = mix(cloud_color, highlight_color, pow(noise, 2.0)) * noise * depth_fade;

	// Set the fragment's color
	ALBEDO = final_color;
}
