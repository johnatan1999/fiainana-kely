shader_type canvas_item;

// Tree foliage: a slow sway of the whole crown, leaves shimmering inside
// it, and both stronger while the player stands under the tree. Applied by
// TreeVisual, in game only, to its Canopy sprites - or to every state
// sprite (and the placeholder drawing) when it has none.
//
// Same anchoring as crops: a sprite's bottom edge is at local y = 0 and
// stays put, its top moves. A canopy sprite placed above the trunk pivots on
// its own bottom edge.

// Global, set by PlayerController (see [shader_globals] in project.godot).
global uniform vec2 player_position;

// Sway: tip offset as a fraction of the height - slower and smaller than
// crops, a tree is heavier.
uniform float sway_tilt = 0.012;
uniform float sway_speed = 0.8;
uniform float sway_wavelength = 320.0; // px between two gusts

// Leaf shimmer: pixels wobble inside the crown, in texture pixels.
uniform float shimmer_px = 0.6;
uniform float shimmer_speed = 2.2;
uniform float shimmer_scale = 0.17; // higher = smaller ripples

// Player under the tree.
uniform float rustle_radius = 48.0;
uniform float rustle_shimmer_boost = 2.5;
uniform float rustle_tilt = 0.03;

varying float v_bend; // 0 at the bottom edge, 1 from 40 px up
varying float v_rustle; // 1 right under the tree, 0 away from it
varying vec2 v_world;

void vertex() {
	float height = max(-VERTEX.y, 0.0);
	vec2 foot = (MODEL_MATRIX * vec4(VERTEX.x, 0.0, 0.0, 1.0)).xy;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_bend = clamp(height / 40.0, 0.0, 1.0);

	vec2 from_player = foot - player_position;
	v_rustle = 1.0 - smoothstep(rustle_radius * 0.3, rustle_radius, length(from_player));

	float phase = (foot.x + foot.y * 0.3) / sway_wavelength * 6.2832;
	float tilt = sin(TIME * sway_speed + phase) * sway_tilt
			+ sin(TIME * sway_speed * 2.1 + phase * 1.6) * sway_tilt * 0.35;
	// Away from the player in the world: undo a mirrored (flipped) sprite.
	float local_right = sign(MODEL_MATRIX[0].x);
	tilt += (from_player.x >= 0.0 ? 1.0 : -1.0) * local_right * v_rustle * rustle_tilt;

	VERTEX.x += tilt * height;
}

void fragment() {
	float strength = shimmer_px * v_bend * (1.0 + v_rustle * rustle_shimmer_boost);
	vec2 wobble = vec2(
			sin(v_world.y * shimmer_scale + TIME * shimmer_speed),
			cos(v_world.x * shimmer_scale * 1.3 + TIME * shimmer_speed * 1.2));
	COLOR = texture(TEXTURE, UV + wobble * strength * TEXTURE_PIXEL_SIZE) * COLOR;
}
