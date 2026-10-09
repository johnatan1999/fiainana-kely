shader_type canvas_item;

// Tree foliage: a slow sway of the whole crown in the wind, leaves
// shimmering inside it. The player doesn't move it - walking past a tree
// doesn't shake its crown (tall grass and crops react, they're brushed
// against). Applied by TreeVisual, in game only, to its Canopy sprites - or
// to every state sprite (and the placeholder drawing) when it has none.
//
// Same anchoring as crops: a sprite's bottom edge is at local y = 0 and
// stays put, its top moves. A canopy sprite placed above the trunk pivots on
// its own bottom edge.

// Sway: tip offset as a fraction of the height - slower and smaller than
// crops, a tree is heavier.
uniform float sway_tilt = 0.012;
uniform float sway_speed = 0.8;
uniform float sway_wavelength = 320.0; // px between two gusts

// Leaf shimmer: pixels wobble inside the crown, in texture pixels.
uniform float shimmer_px = 0.6;
uniform float shimmer_speed = 2.2;
uniform float shimmer_scale = 0.17; // higher = smaller ripples

varying float v_bend; // 0 at the bottom edge, 1 from 40 px up
varying vec2 v_world;

void vertex() {
	float height = max(-VERTEX.y, 0.0);
	vec2 foot = (MODEL_MATRIX * vec4(VERTEX.x, 0.0, 0.0, 1.0)).xy;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_bend = clamp(height / 40.0, 0.0, 1.0);

	float phase = (foot.x + foot.y * 0.3) / sway_wavelength * 6.2832;
	float tilt = sin(TIME * sway_speed + phase) * sway_tilt
			+ sin(TIME * sway_speed * 2.1 + phase * 1.6) * sway_tilt * 0.35;

	VERTEX.x += tilt * height;
}

void fragment() {
	float strength = shimmer_px * v_bend;
	vec2 wobble = vec2(
			sin(v_world.y * shimmer_scale + TIME * shimmer_speed),
			cos(v_world.x * shimmer_scale * 1.3 + TIME * shimmer_speed * 1.2));
	COLOR = texture(TEXTURE, UV + wobble * strength * TEXTURE_PIXEL_SIZE) * COLOR;
}
