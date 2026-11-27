shader_type spatial;
render_mode unshaded, depth_test_disabled;

uniform float radius = 0.5;
uniform float edge_thickness = 0.1;
uniform float smoothness = 0.01;

uniform vec3 fill_color : source_color;
uniform vec3 edge_color : source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 center = UV - 0.5;
	float dist_to_center = sqrt(pow(center.x, 2) + pow(center.y, 2));
	float circle_mask = smoothstep(dist_to_center, dist_to_center+smoothness, radius);
	float edge_mask = 1.0 - step(dist_to_center,  radius - edge_thickness);

	ALPHA = circle_mask;
	ALBEDO = mix(fill_color, edge_color, edge_mask);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
