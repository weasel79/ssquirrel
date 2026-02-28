shader_type canvas_item;
render_mode blend_mul;
// CRT multiplicative overlay — scanlines, blue phosphor tint, vignette,
// sub-pixel grid, flicker. Multiplies with everything underneath.

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;
uniform float blue_tint : hint_range(0.0, 1.0) = 0.15;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.45;
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.012;
uniform float glow_boost : hint_range(1.0, 1.5) = 1.10;
uniform vec2 resolution = vec2(640.0, 360.0);

void fragment() {
	vec2 uv = UV;

	// Scanlines — darken every other pixel row
	float scan = sin(uv.y * resolution.y * PI) * 0.5 + 0.5;
	float scanline = 1.0 - scanline_strength * (1.0 - scan);

	// RGB sub-pixel phosphor columns (every 3rd pixel)
	float col_pos = uv.x * resolution.x;
	float sub = mod(col_pos, 3.0);
	vec3 phosphor = vec3(1.0);
	if (sub < 1.0)      phosphor = vec3(1.0, 0.94, 0.94);
	else if (sub < 2.0) phosphor = vec3(0.94, 1.0, 0.94);
	else                 phosphor = vec3(0.94, 0.94, 1.0);

	// Blue phosphor tint — reduce red, slightly reduce green, boost blue
	vec3 tint = vec3(1.0 - blue_tint * 0.35, 1.0 - blue_tint * 0.05, 1.0 + blue_tint * 0.25);

	// Vignette — dark edges, bright center (CRT monitor glow)
	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig = 1.0 - dot(vig_uv, vig_uv) * vignette_strength;
	vig = clamp(vig, 0.0, 1.0);

	// Center glow boost — simulate CRT phosphor brightness in center
	float glow = mix(1.0, glow_boost, 1.0 - length(vig_uv) * 0.7);

	// Flicker — subtle brightness wobble
	float flick = 1.0 + flicker_strength * sin(TIME * 8.0) * cos(TIME * 3.7);

	// Combine all multiplication factors
	vec3 mul = tint * phosphor * scanline * vig * glow * flick;

	COLOR = vec4(mul, 1.0);
}
