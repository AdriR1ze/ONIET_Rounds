shader_type canvas_item;

uniform bool enabled = true;
uniform vec4 color_highlight : source_color = vec4(1.0, 0.95, 0.25, 1.0);
uniform vec4 color_midtone : source_color = vec4(1.0, 0.85, 0.15, 1.0);
uniform vec4 color_shadow : source_color = vec4(0.65, 0.48, 0.08, 1.0);

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
