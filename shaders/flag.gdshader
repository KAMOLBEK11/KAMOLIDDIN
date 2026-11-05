shader_type spatial;
render_mode cull_disabled;
// Hilpillovchi bayroq: dastaga yaqin tomoni qimirlamaydi, uchi to'lqinlanadi.
uniform vec4 color : source_color = vec4(0.2, 0.5, 0.3, 1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool use_tex = false;
uniform float speed = 6.0;
uniform float amp = 0.12;

void vertex() {
	float k = UV.x;   // 0 - dasta tomoni, 1 - uchi
	float w = sin(TIME * speed - UV.x * 7.0) * amp * k + sin(TIME * speed * 0.7 - UV.x * 4.0 + UV.y * 2.0) * amp * 0.5 * k;
	VERTEX.z += w;
	VERTEX.y -= k * k * 0.06;
}

void fragment() {
	vec3 c = use_tex ? texture(tex, UV).rgb : color.rgb;
	float shade = 0.85 + 0.15 * sin(TIME * speed - UV.x * 7.0);
	ALBEDO = c * shade;
	ROUGHNESS = 0.9;
}
