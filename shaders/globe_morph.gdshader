shader_type spatial;
// Yer shari <-> tekis xarita: bitta to'r. flatten = 0 - globus, 1 - tekis xarita.
// Har nuqta globusdagi (CUSTOM0.xyz) va tekis xaritadagi (VERTEX) o'rni orasida silliq ko'chadi:
// markazdagi yerlar avval tekislanadi, uzoq qirg'oqlar keyinroq - Yer shari ko'z oldida ochilib yoyiladi.
render_mode cull_disabled;
uniform sampler2D day_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D spec_tex : filter_linear_mipmap;
uniform sampler2D ov_tex : source_color, filter_linear;
uniform vec4 geo = vec4(0.03251, 84.91, -0.02495, 39.98);
uniform vec4 ov_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float ov_amount = 1.0;
uniform float flatten = 0.0;

void vertex() {
	vec3 sph = CUSTOM0.xyz;
	float d = CUSTOM0.w;
	float a = clamp((flatten - d * 0.8) / 0.2, 0.0, 1.0);
	a = a * a * (3.0 - 2.0 * a);
	vec3 fl = VERTEX;
	VERTEX = mix(sph, fl, a);
	NORMAL = normalize(mix(normalize(sph), vec3(0.0, 1.0, 0.0), a));
}

void fragment() {
	vec2 uv = UV;
	float lon = uv.x * 360.0 - 180.0;
	float lat = 90.0 - uv.y * 180.0;
	vec3 c = texture(day_tex, uv).rgb;
	float water = texture(spec_tex, uv).r;
	vec2 mp = vec2((lon - geo.y) / geo.x, (lat - geo.w) / geo.z);
	vec2 ouv = (mp - ov_rect.xy) / ov_rect.zw;
	if (ouv.x > 0.0 && ouv.x < 1.0 && ouv.y > 0.0 && ouv.y < 1.0) {
		vec4 ov = texture(ov_tex, ouv);
		c = mix(c, ov.rgb, clamp(ov.a * 1.6, 0.0, 0.9) * ov_amount);
	}
	ALBEDO = c * 1.05;
	ROUGHNESS = mix(0.85, 0.25, water);
	SPECULAR = mix(0.3, 0.8, water);
}
