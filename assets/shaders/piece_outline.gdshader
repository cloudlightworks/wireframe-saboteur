shader_type canvas_item;
uniform float outline_width : hint_range(0.0, 8.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int state = 0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
void fragment() {
	// COLOR arrives pre-multiplied by the node's modulate. Capture it now so we
	// can reapply the tint after we overwrite COLOR below. (Godot 4 canvas_item
	// shaders have no separate MODULATE built-in; the modulate lives in COLOR
	// on entry to fragment().)
	vec4 mod_tint = COLOR;

	vec4 col = texture(TEXTURE, UV);
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 border = vec2(outline_width) / tex_size;
	bool on_border = UV.x < border.x || UV.x > 1.0 - border.x ||
	                 UV.y < border.y || UV.y > 1.0 - border.y;
	if (on_border) {
		vec4 border_col = outline_color;
		if (state == 1) {
			float pulse = sin(TIME * pulse_speed * 1.5) * 0.4 + 0.6;
			border_col = vec4(1.0, 0.85, 0.1, pulse * 0.5 + 0.5);
		} else if (state == 2) {
			float pulse = sin(TIME * pulse_speed * 0.8) * 0.3 + 0.7;
			border_col = vec4(1.0, 1.0, 1.0, pulse * 0.85);
		} else if (state == 3) {
			float pulse = sin(TIME * pulse_speed * 2.0) * 0.5 + 0.5;
			border_col = vec4(1.0, 0.1, 0.7, pulse * 0.6 + 0.4);  // bold magenta, faster, min 40% alpha
		}
		COLOR = border_col;
	} else {
		COLOR = col;
	}
	// Reapply the node's modulate (overwriting COLOR above discarded it). This is
	// what lets the whole-piece green "saboteur candidate" pulse work via a
	// modulate tween in piece_view.gd, matching the discard cards' red pulse. At
	// the default modulate (white) this multiply is a no-op, so every other state
	// is visually unchanged.
	COLOR *= mod_tint;
}