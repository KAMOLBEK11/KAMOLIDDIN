shader_type spatial;
// Viloyat relyefi: pasttekislik (o'tloq/dala), qirlar, tog' (tosh, qor), cho'l - balandlik va qiyalikka qarab
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 grass : source_color = vec3(0.24, 0.36, 0.16);
uniform vec3 dry : source_color = vec3(0.52, 0.47, 0.30);
uniform float desert = 0.3;
varying float vh;
varying vec3 wn;
varying vec3 wp;
void vertex() {
	vh = VERTEX.y;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float n = texture(detail, wp.xz * 0.004).r;
	float n2 = texture(detail, wp.xz * 0.0007).r;
	vec3 sand = vec3(0.72, 0.62, 0.44);
	vec3 rock = vec3(0.42, 0.38, 0.34);
	vec3 snow = vec3(0.93, 0.94, 0.96);
	vec3 field = mix(grass, dry, smoothstep(0.3, 0.75, n2 + desert * 0.5));
	field = mix(field, sand, smoothstep(0.55, 0.95, desert + (n2 - 0.5) * 0.4));
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	vec3 c = mix(field, rock, clamp(smoothstep(0.25, 0.55, slope) + smoothstep(60.0, 140.0, vh), 0.0, 1.0));
	c = mix(c, snow, smoothstep(170.0, 230.0, vh + (n - 0.5) * 30.0) * (1.0 - smoothstep(0.45, 0.7, slope)));
	c *= 0.84 + n * 0.3;
	ALBEDO = c;
	ROUGHNESS = 0.94;
	NORMAL_MAP = texture(detail_n, wp.xz * 0.02).rgb;
	NORMAL_MAP_DEPTH = 0.7;
}
