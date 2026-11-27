shader_type canvas_item;

uniform sampler2D sprite;
uniform float mask_opacity;
uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float smoothness : hint_range(0.0, 0.1) = 0.01;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
 // 1. Shift UVs so (0,0) is at the center
    vec2 uv = UV - 0.5;

    // 2. Calculate angle starting from 12:00 (top) moving clockwise
    // Note: Standard UV Y-axis points down in 2D engines (flip -uv.y if Y points up)
    float angle = atan(-uv.x, uv.y);

    // 3. Normalize angle from [-PI, PI] to [0.0, 1.0]
    float normalized_angle = (angle / (2.0 * 3.14159265)) + 0.5;

    // 4. Create the radial mask (1.0 inside progress, 0.0 outside)
    float mask = mix(0, smoothstep(progress - smoothness, progress, normalized_angle), step(progress, 0.999));

	vec4 sprite_tex = texture(sprite, UV);

	COLOR.a = sprite_tex.a;
	COLOR.rgb = sprite_tex.rgb - mask * mask_opacity;

}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
