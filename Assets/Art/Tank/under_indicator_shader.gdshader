shader_type spatial;
render_mode unshaded;

uniform float power = 10.0;
uniform vec3 tint : source_color;
uniform float opacity_factor = 1.0;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 center = UV - 0.5;
	float dist_to_center = sqrt(pow(center.x, 2) + pow(center.y, 2));
	float shadow = 1. - clamp(dist_to_center * 2.0, 0. ,1.);
	float eased_shadow = -(cos(PI * shadow) - 1.0) / 2.;
	float powered_shadow = pow(eased_shadow, power);

	ALPHA = powered_shadow * opacity_factor;
	ALBEDO = tint.rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
