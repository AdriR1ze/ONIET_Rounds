shader_type canvas_item;

// Paleta editable: agregá o quitá paradas (stops) al Gradient del
// GradientTexture2D asignado a "palette". Con 2+ colores interpola solo.
uniform sampler2D palette : source_color, hint_default_white;

// Tamaño de cada subdivisión en píxeles (independiente de la forma del objeto).
uniform float cell_size = 80.0;
uniform float jitter = 2.0;
uniform float skip_chance = 0.55;

uniform float warp_amount = 1.5;
uniform float warp_scale = 1.0;

uniform float color_speed = 0.6;

varying vec2 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = world_pos / cell_size;

	vec2 warp = vec2(noise(uv * warp_scale), noise(uv * warp_scale + 31.7)) - 0.5;
	vec2 warped = uv + warp * warp_amount;

	vec2 base_cell = floor(warped);

	float min_dist = 100.0;
	vec2 cell_id = base_cell;

	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 neighbor = base_cell + vec2(float(x), float(y));
			if (hash21(neighbor + 55.5) < skip_chance) {
				continue;
			}
			vec2 offset = vec2(hash21(neighbor), hash21(neighbor + 19.19)) - 0.5;
			vec2 point = neighbor + 0.5 + offset * jitter;
			float d = distance(warped, point);
			if (d < min_dist) {
				min_dist = d;
				cell_id = neighbor;
			}
		}
	}

	float base = hash21(cell_id + 3.7);
	float mixv = 0.5 + 0.5 * sin(TIME * color_speed + base * 6.2831853);

	vec3 col = texture(palette, vec2(mixv, 0.5)).rgb;
	COLOR = vec4(col, 1.0);
}
