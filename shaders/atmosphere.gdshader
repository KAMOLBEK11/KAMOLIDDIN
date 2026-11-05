shader_type spatial;
// Atmosfera: sharning chetida ko'kimtir nur (fresnel)
render_mode blend_add, unshaded, depth_draw_never, cull_back;
uniform vec4 glow : source_color = vec4(0.35, 0.6, 1.0, 1.0);
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float a = pow(f, 3.0) * 1.6;
	ALBEDO = glow.rgb * a;
	ALPHA = a;
}
