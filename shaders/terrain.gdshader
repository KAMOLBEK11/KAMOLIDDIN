shader_type spatial;
// 3D xarita yer yuzasi: balandlik, qiyalik va iqlimga qarab tabiiy ranglar
// (o'tloq, dasht, cho'l, tosh, qor) + ustiga viloyatlar xaritasi (shaffof ranglar, chegaralar).
render_mode cull_back;

uniform sampler2D overlay : source_color, filter_linear;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float overlay_strength = 0.85;
uniform float antique = 0.0;   // 1- va 2-zamon: eski qo'lyozma xarita (pergament, akvarel bo'yoq, siyoh chiziqlar)
uniform float fade = 1.0;   // globusga o'tishda yer silliq yo'qoladi
uniform float bend = 0.0;   // uzoqlashganda xarita Yer shari egriligiga moslashadi
uniform vec2 bend_center = vec2(0.0);
uniform float bend_radius = 230.0;

varying float vh;

// bikubik o'qish: yaqinlashganda chegaralar zinapoya bo'lib ko'rinmaydi (silliq chiziq)
vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

vec4 tex_bicubic(sampler2D t, vec2 uv) {
	vec2 ts = vec2(textureSize(t, 0));
	vec2 inv = 1.0 / ts;
	uv = uv * ts - 0.5;
	vec2 fxy = fract(uv);
	uv -= fxy;
	vec4 xc = cubic(fxy.x);
	vec4 yc = cubic(fxy.y);
	vec4 c = uv.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 off = c + vec4(xc.yw, yc.yw) / s;
	off *= inv.xxyy;
	vec4 s0 = texture(t, off.xz);
	vec4 s1 = texture(t, off.yz);
	vec4 s2 = texture(t, off.xw);
	vec4 s3 = texture(t, off.yw);
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	return mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
}
varying vec3 wnorm;

void vertex() {
	vh = VERTEX.y;
	vec2 dxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz - bend_center;
	VERTEX.y -= bend * dot(dxz, dxz) / (2.0 * bend_radius);
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (fade < 0.01) {
		discard;
	}
	float m = COLOR.r;
	float d = COLOR.g;
	float n = texture(detail, UV * 46.0).r;
	float n2 = texture(detail, UV * 9.0).r;
	vec3 grass = vec3(0.17, 0.27, 0.10);
	vec3 steppe = vec3(0.40, 0.37, 0.20);
	vec3 desert = vec3(0.62, 0.50, 0.32);
	vec3 rock = vec3(0.33, 0.29, 0.25);
	vec3 snow = vec3(0.94, 0.95, 0.97);
	vec3 base = mix(grass, steppe, smoothstep(0.15, 0.55, d + (n2 - 0.5) * 0.35));
	base = mix(base, desert, smoothstep(0.45, 0.85, d + (n2 - 0.5) * 0.3));
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	base = mix(base, rock, clamp(smoothstep(0.18, 0.45, slope) + smoothstep(2.5, 6.0, vh) * 0.6, 0.0, 1.0));
	base = mix(base, snow, smoothstep(6.5, 9.0, vh + (n - 0.5) * 2.0) * (0.5 + 0.5 * smoothstep(0.2, 0.05, slope)));
	base *= 0.93 + (n2 - 0.5) * 0.1 + (n - 0.5) * 0.05;   // nozik, ko'zni charchatmaydigan naqsh
	vec4 ov = tex_bicubic(overlay, UV);
	vec3 col = base;
	if (ov.a < 0.03) {
		// viloyatlardan tashqarida tekis dunyo xaritasi ko'rinadi
		discard;
	}
	if (ov.a < 0.03) {
		// xaritadan tashqari hudud - xira
		col = mix(base, vec3(dot(base, vec3(0.33))), 0.6) * 0.55;
	} else {
		col = mix(base, ov.rgb, clamp(ov.a * overlay_strength, 0.0, 1.0));
	}
	if (antique > 0.0) {
		float lum = dot(base, vec3(0.3, 0.5, 0.2));
		vec3 parch = vec3(0.80, 0.71, 0.53) * (0.78 + lum * 0.5) * (0.93 + (n2 - 0.5) * 0.2 + (n - 0.5) * 0.06);
		// davlat rangi - pergamentga surtilgan akvarel bo'yoq (har davlat o'z rangida aniq ko'rinadi)
		vec3 tint = ov.rgb * vec3(1.0, 0.95, 0.8) * 0.85 + vec3(0.06, 0.05, 0.02);
		vec3 wash = mix(parch, tint * (0.75 + lum * 0.4) * (0.95 + (n2 - 0.5) * 0.2), clamp(ov.a, 0.0, 1.0) * 0.82);
		// tog'lar - jigarrang shtrix soya
		float mnt = clamp(smoothstep(2.0, 7.0, vh) * 0.45 + smoothstep(0.2, 0.5, slope) * 0.3, 0.0, 0.6);
		wash = mix(wash, vec3(0.42, 0.31, 0.2), mnt * (0.6 + 0.4 * step(0.5, fract((UV.x + UV.y) * 900.0))));
		col = mix(col, wash, antique);
	}
	ALBEDO = col;
	ROUGHNESS = 0.92 - smoothstep(6.5, 9.0, vh) * 0.4;
	NORMAL_MAP = texture(detail_n, UV * 46.0).rgb;
	NORMAL_MAP_DEPTH = 0.22;
	// chegaralar va tanlangan viloyat chizig'i biroz porlaydi
	EMISSION = ov.rgb * smoothstep(0.85, 1.0, ov.a) * 0.18 * (1.0 - antique);
}
