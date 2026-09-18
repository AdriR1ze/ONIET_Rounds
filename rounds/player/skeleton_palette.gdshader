shader_type canvas_item;

uniform bool enabled = true;
uniform vec4 color_highlight : source_color = vec4(0.97, 0.93, 0.62, 1.0);
uniform vec4 color_midtone : source_color = vec4(0.90, 0.82, 0.42, 1.0);
uniform vec4 color_shadow : source_color = vec4(0.40, 0.33, 0.16, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.02) {
		discard;
	}
	if (!enabled) {
		COLOR = tex * COLOR;
	} else {
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		vec4 target_col;
		if (lum > 0.3) {
			target_col = color_highlight;
		} else if (lum > 0.15) {
			target_col = color_midtone;
		} else {
			target_col = color_shadow;
		}
		COLOR = vec4(target_col.rgb * COLOR.rgb, tex.a * target_col.a * COLOR.a);
	}
}
