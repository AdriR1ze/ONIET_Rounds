shader_type canvas_item;

// Paleta editable: agregá o quitá paradas (stops) al Gradient del
// GradientTexture2D asignado a "palette". Con 2+ colores interpola solo.
uniform sampler2D palette : source_color, hint_default_white;

// Tamaño de cada subdivisión en píxeles (solo se usa en modo mundo, o sea con
// "fit_to_shape" desactivado).
uniform float cell_size = 80.0;
uniform float jitter = 0.4;
uniform float skip_chance = 0.55;

uniform float warp_amount = 0.6;
uniform float warp_scale = 1.0;

uniform float color_speed = 0.6;

// false = patrón global en espacio de mundo (ideal para tilemaps o paredes
// continuas). true = ajusta el patrón al rectángulo repartiendo una cantidad
// fija de celdas, así cualquier forma (ancha, alta o cuadrada) se ve pareja
// y sin franjas diminutas ni blobs recortados.
uniform bool fit_to_shape = false;

// Con "fit_to_shape" activo, cuántas celdas se reparten a lo largo del lado
// largo del rectángulo (un cuadrado usa 3x3 = 9).
uniform float target_cells = 9.0;

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

// Reparte las celdas dentro del rectángulo: el lado largo recibe ~target_cells
// celdas repartidas de forma que las celdas queden lo más cuadradas posible, y
// el lado corto recibe un mínimo de 2 para que nunca quede una sola fila o
// columna. Deduce el tamaño comparando cuánto cambia la posición de mundo
// respecto del UV; funciona con ColorRect y sprites por igual.
vec2 fit_uv(vec2 wp, vec2 obj_uv) {
	vec2 size = fwidth(wp) / fwidth(obj_uv);
	float aspect = size.x / max(size.y, 1e-6);
	float budget = max(target_cells, 4.0);
	float ratio = max(aspect, 1.0 / max(aspect, 1e-6));
	float long_side = max(round(sqrt(budget * ratio)), 2.0);
	float short_side = max(round(budget / long_side), 2.0);
	vec2 cells;
	if (aspect >= 1.0) {
		cells = vec2(long_side, short_side);
	} else {
		cells = vec2(short_side, long_side);
	}
	return obj_uv * cells;
}

void fragment() {
	vec2 d_uv = fwidth(UV);
	vec2 uv;
	if (fit_to_shape && d_uv.x > 1e-7 && d_uv.y > 1e-7) {
		uv = fit_uv(world_pos, UV);
	} else {
		uv = world_pos / cell_size;
	}

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
	// El alpha lo aporta la textura del tile: un tile cuya textura sea opaca se
	// dibuja entero; uno cuya textura sólo sea opaca arriba se recorta, lo que
	// permite plataformas de una sola cara sin tocar la paleta ni el material.
	COLOR = vec4(col, texture(TEXTURE, UV).a);
}
