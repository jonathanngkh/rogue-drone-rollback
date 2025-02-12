// By tlaverne (Modified for shadow-aware world-space crosshatching with depth control)
shader_type spatial;
render_mode unshaded;

uniform float zNear = 0.05;
uniform float zFar = 100;
uniform float outlineThickness = 1.5;
uniform vec3 outlineColor : source_color = vec3(0.0);
uniform float wiggleFrequency = 0.08;
uniform float wiggleAmplitude = 2.0;
uniform float shadow_threshold = 0.2; // Ignore shadows below this luminance
uniform float depth_range : hint_range(0.1, 10.0) = 1.0; // Adjustable depth range slider
uniform float hatch_scale : hint_range(0.1, 10.0) = 1.0; // Scale for hatching

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

const mat3 Sy = mat3(
	vec3(1.0, 0.0, -1.0),
	vec3(2.0, 0.0, -2.0),
	vec3(1.0, 0.0, -1.0)
);

const mat3 Sx = mat3(
	vec3(1.0, 2.0, 1.0),
	vec3(0.0, 0.0, 0.0),
	vec3(-1.0, -2.0, -1.0)
);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Retrieve and scale depth from the depth buffer
float get_depth(sampler2D depth_texture, vec2 screen_uv, mat4 inv_projection_matrix) {
	float raw_depth = texture(depth_texture, screen_uv)[0];
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	vec4 view_space = inv_projection_matrix * vec4(ndc, 1.0);
	view_space.xyz /= view_space.w;
	float linear_depth = view_space.z;
	float scaled_depth = (zFar - zNear) / (zNear + linear_depth * (zNear - zFar));

	// Scale depth effect based on user input (depth_range slider)
	return scaled_depth * depth_range;
}

// Sobel edge detection for depth buffer
float sobel_depth(in vec2 uv, in vec2 offset, mat4 inv_projection_matrix) {
	float xSobelDepth = 0.0;
	float ySobelDepth = 0.0;

	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 sample_offset = vec2(float(i), float(j)) * offset;
			float depth_sample = get_depth(DEPTH_TEXTURE, uv + sample_offset, inv_projection_matrix);
			xSobelDepth += depth_sample * Sx[i + 1][j + 1];
			ySobelDepth += depth_sample * Sy[i + 1][j + 1];
		}
	}

	return sqrt(pow(xSobelDepth, 2.0) + pow(ySobelDepth, 2.0));
}

// Compute luminance of a color
float luminance(vec3 color) {
	const vec3 weights = vec3(0.2125, 0.7154, 0.0721);
	return dot(weights, color);
}

// Sobel edge detection for normals
float sobel_normal(in vec2 uv, in vec2 offset) {
	float xSobelNormal = 0.0;
	float ySobelNormal = 0.0;

	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 sample_offset = vec2(float(i), float(j)) * offset;
			float normal_sample = luminance(texture(NORMAL_TEXTURE, uv + sample_offset).rgb);
			xSobelNormal += normal_sample * Sx[i + 1][j + 1];
			ySobelNormal += normal_sample * Sy[i + 1][j + 1];
		}
	}

	return sqrt(pow(xSobelNormal, 2.0) + pow(ySobelNormal, 2.0));
}

// Random hash function for wiggly lines
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 offset = outlineThickness / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;

	// Convert to world-space UVs (fixes zoom-scaling issue)
	vec2 world_uv = (FRAGCOORD.xy / VIEWPORT_SIZE.xy) * hatch_scale;

	// Displacement for hand-drawn effect
	vec2 displ = vec2(
		(hash(world_uv) * sin(world_uv.y * wiggleFrequency)),
		(hash(world_uv) * cos(world_uv.x * wiggleFrequency))
	) * wiggleAmplitude;

	// Get depth information
	float depth = get_depth(DEPTH_TEXTURE, uv, INV_PROJECTION_MATRIX);

	// Avoid cross-hatching in shadows and discard very distant objects
	if (depth < 0.01 || depth > 1.5) { // Upper limit prevents infinite depth
		discard;
	}

	// Get screen texture color
	vec3 pixelColor = texture(SCREEN_TEXTURE, uv).rgb;
	float pixelLuma = luminance(pixelColor);

	// Get Sobel edges
	float edgeDepth = sobel_depth(uv + displ, offset, INV_PROJECTION_MATRIX);
	float edgeNormal = sobel_normal(uv + displ, offset);
	float outlineFactor = smoothstep(0.0, 1.0, 25.0 * edgeDepth + edgeNormal);

	// Apply hatching only on **mesh surfaces** (avoid shadows)
	if (pixelLuma > shadow_threshold) {
		// Apply cross-hatching based on brightness
		float modVal = 8.0;

		// Apply cross-hatching in world space (ensures consistency across zoom levels)
		if (pixelLuma <= 0.25) {
			if (mod((world_uv.y + world_uv.x + displ.y), modVal) < outlineThickness) {
				pixelColor = mix(pixelColor, outlineColor, 1.0);
			}
		}

		if (pixelLuma <= 0.35) {
			if (mod((world_uv.y - world_uv.x * 0.707 + displ.y), modVal) < outlineThickness) {
				pixelColor = mix(pixelColor, outlineColor, 1.0);
			}
		}
	}

	// Mix edges and final color
	ALBEDO = mix(pixelColor, outlineColor, outlineFactor);
}