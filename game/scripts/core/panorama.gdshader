shader_type canvas_item;
// Equirectangular panorama viewer. Same math as scripts/core/pano_math.gd (keep in sync).
// u = 0.5 + yaw/360 (image centre = yaw 0), v = 0.5 - pitch/180.

uniform sampler2D pano : source_color, filter_linear, repeat_enable;
uniform float cam_yaw = 0.0;      // radians
uniform float cam_pitch = 0.0;    // radians
uniform float tan_half = 0.4;     // tan(vfov/2)
uniform float aspect = 2.2;
uniform float dim = 0.0;          // 0..1 darkening (dialogue background)
uniform float blur = 0.0;         // blur radius in uv units (dialogue background)

vec2 dir_to_uv(vec3 d) {
	float y = atan(d.x, -d.z);
	float p = asin(clamp(d.y, -1.0, 1.0));
	return vec2(0.5 + y / (2.0 * PI), 0.5 - p / PI);
}

void fragment() {
	vec2 ndc = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec3 f = vec3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), -cos(cam_yaw) * cos(cam_pitch));
	vec3 r = vec3(cos(cam_yaw), 0.0, sin(cam_yaw));
	vec3 u = cross(r, f);
	vec3 d = normalize(f + r * (ndc.x * tan_half * aspect) + u * (ndc.y * tan_half));
	vec2 uv = dir_to_uv(d);
	vec4 c;
	if (blur > 0.0) {
		c = vec4(0.0);
		for (int i = -2; i <= 2; i++) {
			for (int j = -2; j <= 2; j++) {
				c += texture(pano, uv + vec2(float(i), float(j)) * blur);
			}
		}
		c /= 25.0;
	} else {
		c = texture(pano, uv);
	}
	COLOR = vec4(c.rgb * (1.0 - dim), 1.0);
}
