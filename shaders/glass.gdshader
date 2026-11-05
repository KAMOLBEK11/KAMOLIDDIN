shader_type canvas_item;
// Glassmorphism: panel ortidagi ko'rinishni xiralashtirib (blur), ustiga shaffof rang qo'yadi.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float radius = 7.0;
uniform float lod = 2.5;

void fragment() {
	vec4 c = COLOR;
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 acc = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.2;
	acc += textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), lod).rgb * 0.1;
	acc += textureLod(screen_tex, SCREEN_UV - vec2(px.x, 0.0), lod).rgb * 0.1;
	acc += textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), lod).rgb * 0.1;
	acc += textureLod(screen_tex, SCREEN_UV - vec2(0.0, px.y), lod).rgb * 0.1;
	acc += textureLod(screen_tex, SCREEN_UV + px, lod).rgb * 0.1;
	acc += textureLod(screen_tex, SCREEN_UV - px, lod).rgb * 0.1;
	acc += textureLod(screen_tex, SCREEN_UV + vec2(px.x, -px.y), lod).rgb * 0.1;
	acc += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, px.y), lod).rgb * 0.1;
	// yengil sovuq tus (shisha)
	acc = mix(acc, vec3(dot(acc, vec3(0.33))), 0.25) * 0.85;
	float a = clamp(c.a * 2.2, 0.0, 1.0);
	COLOR = vec4(mix(acc, c.rgb, c.a), a);
}
