shader_type canvas_item;
// Full-screen grade: grey world while sober, colour floods back while dosed,
// blur + double vision + dark vignette while crashing.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 2.0) = 0.2;
uniform float contrast : hint_range(0.5, 2.0) = 1.05;
uniform vec4 tint : source_color = vec4(1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float blur : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float lod = blur * 3.5;
	vec3 c = textureLod(screen_tex, uv, lod).rgb;
	if (blur > 0.01) {
		vec2 ghost = vec2(sin(TIME * 1.3 + time_offset), cos(TIME * 0.9)) * 0.012 * blur;
		c = mix(c, textureLod(screen_tex, uv + ghost, lod).rgb, 0.45 * blur);
	}
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint.rgb;
	float d = distance(uv, vec2(0.5));
	c *= mix(1.0, smoothstep(0.85, 0.25, d), vignette);
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
