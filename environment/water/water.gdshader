shader_type canvas_item;

// Animated water, drawn procedurally in world space so neighbouring tiles
// always line up: slow ripples between a shallow and a deep tint, a few
// glints, and faint sky reflections. The tile texture only gives the shape
// (its alpha) - shallow, muddy paddy water and a deeper stream are the same
// shader with different materials.

uniform vec4 shallow_color : source_color = vec4(0.36, 0.52, 0.50, 0.55);
uniform vec4 deep_color : source_color = vec4(0.22, 0.40, 0.48, 0.70);
uniform vec4 glint_color : source_color = vec4(0.85, 0.95, 1.0, 0.6);
uniform float ripple_scale = 0.05; // higher = smaller ripples
uniform float ripple_speed = 0.6;
uniform float glint_amount = 0.5; // 0 = no glints
// Flow direction and speed (px/s) - zero for still paddy water.
uniform vec2 flow = vec2(0.0, 0.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = TIME * ripple_speed;
	vec2 p = (world - flow * TIME) * ripple_scale;
	float w = sin(p.x + sin(p.y * 0.7 + t) * 1.5 + t)
			+ sin(p.y * 1.4 + sin(p.x * 0.5 - t * 0.8) * 1.2 - t * 0.7);
	w = w * 0.25 + 0.5; // 0..1
	vec4 col = mix(shallow_color, deep_color, w);
	float glint = smoothstep(1.0 - glint_amount * 0.12, 1.0, w);
	col.rgb = mix(col.rgb, glint_color.rgb, glint * glint_color.a);
	float streak = smoothstep(0.93, 1.0, sin(world.y * 0.3 + sin(world.x * 0.02 + t) * 2.0 + t * 2.0));
	col.rgb += streak * 0.05;
	COLOR = vec4(col.rgb, col.a * texture(TEXTURE, UV).a);
}
