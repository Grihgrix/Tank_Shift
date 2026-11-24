shader_type spatial;

uniform sampler2D noise : source_color;
uniform float noise_speed = 1.;
uniform vec3 tint : source_color  = vec3(1.0);
uniform float contrast = 0.0;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 timed_uv = vec2(UV.x, UV.y + TIME * noise_speed);
	vec4 noise_tex = texture(noise, timed_uv);

	ALPHA = smoothstep(contrast, 1.0 - contrast, COLOR.r);
	ALBEDO = tint * noise_tex.r;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
