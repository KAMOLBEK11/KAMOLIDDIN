shader_type spatial;
// Kosmos: tasodifiy yulduzlar (ichkaridan ko'rinadigan katta shar)
render_mode unshaded, cull_front, depth_draw_never;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void fragment() {
	vec3 d = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	vec3 g = floor(d * 380.0);
	float r = h(g);
	float star = step(0.9965, r) * (0.5 + 0.5 * h(g + 1.0));
	vec3 col = vec3(0.01, 0.012, 0.025) + star * mix(vec3(0.8, 0.85, 1.0), vec3(1.0, 0.9, 0.75), h(g + 2.0));
	ALBEDO = col;
}
