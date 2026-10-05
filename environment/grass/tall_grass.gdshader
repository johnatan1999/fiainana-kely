shader_type canvas_item;

// Tall grass that sways in the wind, leans away from the player and
// whips back and forth after they pass through (TallGrassLayer feeds the
// player position and the recent "rustles").
//
// Art convention: every tuft's texture is a single row, tufts standing on
// its bottom edge - so UV.y says how high a vertex is: the top (UV.y = 0)
// moves, the foot (UV.y = 1) stays planted.

// Wind - uses TIME, so it also plays in the editor.
uniform float wind_strength = 1.2; // tip offset, in px
uniform float wind_speed = 1.7;
uniform float wind_wavelength = 90.0; // px between two gusts

// Player pushing through.
uniform vec2 player_position = vec2(-100000.0);
uniform float push_radius = 18.0;
uniform float push_strength = 5.0;

// Rustles: where the player crossed the grass and when (xy = position,
// z = rustle_time at that moment, w = 1 if used). Each one is a damped
// oscillation: the grass whips, swings a few times, and settles.
const int MAX_RUSTLES = 8;
uniform vec4 rustles[MAX_RUSTLES];
uniform float rustle_time = 0.0;
uniform float rustle_radius = 26.0;
uniform float rustle_strength = 4.0;
uniform float rustle_frequency = 13.0;
uniform float rustle_damping = 3.2;

// Tuft height in px, to find a vertex's foot from its height.
uniform float tuft_height = 32.0;

void vertex() {
	float bend = 1.0 - UV.y;
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 foot = world + vec2(0.0, bend * tuft_height);

	float phase = (foot.x + foot.y * 0.5) / wind_wavelength * 6.2832;
	float offset_x = sin(TIME * wind_speed + phase) * wind_strength
			+ sin(TIME * wind_speed * 2.7 + phase * 1.9) * wind_strength * 0.35;
	float offset_y = 0.0;

	vec2 from_player = foot - player_position;
	float push = 1.0 - smoothstep(push_radius * 0.25, push_radius, length(from_player));
	offset_x += sign(from_player.x) * push * push_strength;
	offset_y += push * push_strength * 0.4; // flattened a little under the feet

	for (int i = 0; i < MAX_RUSTLES; i++) {
		vec4 rustle = rustles[i];
		float age = rustle_time - rustle.z;
		if (rustle.w > 0.5 && age >= 0.0) {
			vec2 from_rustle = foot - rustle.xy;
			float reach = 1.0 - smoothstep(0.0, rustle_radius, length(from_rustle));
			float side = from_rustle.x >= 0.0 ? 1.0 : -1.0;
			offset_x += side * sin(age * rustle_frequency) * exp(-age * rustle_damping) * rustle_strength * reach;
		}
	}

	VERTEX += vec2(offset_x, offset_y) * bend;
}
