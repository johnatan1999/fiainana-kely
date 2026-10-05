shader_type canvas_item;

// Crops swaying in the wind and leaning away when the player brushes past.
// Applied by CropVisual to every stage sprite, in game only.
//
// Relies on CropVisual's anchoring: each sprite's bottom-center sits on its
// own origin, so its bottom vertices are at local y = 0 (the foot, which
// stays planted) and its top ones at -height (the top, which moves). Offsets
// are a fraction of that height, so a sprout barely stirs while mature corn
// visibly sways - with no setting per crop.

// Global, set by PlayerController (see [shader_globals] in project.godot).
global uniform vec2 player_position;

// Wind: tip offset as a fraction of the plant's height.
uniform float wind_tilt = 0.035;
uniform float wind_speed = 1.4;
uniform float wind_wavelength = 160.0; // px between two gusts

// Brushing past: within brush_radius of the foot, the plant leans away.
uniform float brush_radius = 26.0;
uniform float brush_tilt = 0.14;

void vertex() {
	float height = max(-VERTEX.y, 0.0); // 0 at the foot
	if (height > 0.5) {
		vec2 foot = (MODEL_MATRIX * vec4(VERTEX.x, 0.0, 0.0, 1.0)).xy;
		float phase = (foot.x + foot.y * 0.4) / wind_wavelength * 6.2832;
		float tilt = sin(TIME * wind_speed + phase) * wind_tilt
				+ sin(TIME * wind_speed * 2.3 + phase * 1.7) * wind_tilt * 0.3;

		vec2 from_player = foot - player_position;
		float brush = 1.0 - smoothstep(brush_radius * 0.3, brush_radius, length(from_player));
		tilt += (from_player.x >= 0.0 ? 1.0 : -1.0) * brush * brush_tilt;

		VERTEX.x += tilt * height;
	}
}
