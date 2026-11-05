shader_type spatial;
// Yer shari: kenglik/uzunlik bo'yicha ekvirektangulyar tekstura, okeanlar yaltiraydi, tun tomoni qorong'i.
uniform sampler2D day_tex : source_color, filter_linear_mipmap;
uniform sampler2D spec_tex : filter_linear_mipmap;
// siyosiy xarita (davlatlar ranglari) globus ustiga: lon/lat -> xarita koordinatasi -> overlay UV
uniform sampler2D ov_tex : source_color, filter_linear;
uniform vec4 geo = vec4(0.03251, 84.91, -0.02495, 39.98);   // LON_A, LON_B, LAT_A, LAT_B
uniform vec4 ov_rect = vec4(0.0, 0.0, 1.0, 1.0);            // xarita chegarasi: x, y, w, h
uniform float ov_amount = 1.0;
varying vec3 lpos;

void vertex() {
	lpos = normalize(VERTEX);
}

void fragment() {
	float lat = asin(clamp(lpos.y, -1.0, 1.0));
	float lon = atan(lpos.x, lpos.z);
	vec2 uv = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);
	vec3 c = texture(day_tex, uv).rgb;
	float water = texture(spec_tex, uv).r;
	vec2 mp = vec2((degrees(lon) - geo.y) / geo.x, (degrees(lat) - geo.w) / geo.z);
	vec2 ouv = (mp - ov_rect.xy) / ov_rect.zw;
	if (ouv.x > 0.0 && ouv.x < 1.0 && ouv.y > 0.0 && ouv.y < 1.0) {
		vec4 ov = texture(ov_tex, ouv);
		c = mix(c, ov.rgb, clamp(ov.a * 1.6, 0.0, 0.9) * ov_amount);
	}
	ALBEDO = c * 1.05;
	ROUGHNESS = mix(0.85, 0.25, water);
	METALLIC = 0.0;
	SPECULAR = mix(0.3, 0.8, water);
}
