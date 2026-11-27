shader_type canvas_item;

uniform sampler2D cursor_base_texture;
uniform sampler2D cursor_stroke_texture;
uniform sampler2D cursor_fill_texture;
uniform sampler2D cursor_mask_texture;

uniform vec4 cooldown_tint : source_color = vec4(1.0, 0.0, 0.0, 1.0);

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float smoothness : hint_range(0.0, 1.0) = 0.1;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 uv = UV - 0.5;

	float angle = atan(-uv.x, uv.y);

	float normalized_angle = (angle / (2.0 * 3.14159265)) + 0.5;

	float mask = mix(0, smoothstep(progress - smoothness, progress, normalized_angle), step(progress, 0.999));

	vec4 base_texture = texture(cursor_base_texture, UV);
	vec4 stroke_texture = texture(cursor_stroke_texture, UV);
	vec4 fill_texture = texture(cursor_fill_texture, UV);
	vec4 mask_texture = texture(cursor_mask_texture, UV);

	vec4 final_color = mix(stroke_texture + base_texture, stroke_texture + (base_texture + fill_texture) * cooldown_tint * mask, mask);
	COLOR = final_color;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
