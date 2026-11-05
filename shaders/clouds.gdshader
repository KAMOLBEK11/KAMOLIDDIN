shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform sampler2D cloud_tex : filter_linear_mipmap;
uniform float spin = 0.0;
varying vec3 lpos;
void vertex() { lpos = normalize(VERTEX); }
void fragment() {
	float lat = asin(clamp(lpos.y, -1.0, 1.0));
	float lon = atan(lpos.x, lpos.z) + spin;
	vec2 uv = vec2(fract(lon / (2.0 * PI) + 0.5), 0.5 - lat / PI);
	float a = texture(cloud_tex, uv).a;
	ALBEDO = vec3(1.0);
	ALPHA = a * 0.85;
	ROUGHNESS = 1.0;
}
