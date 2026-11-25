shader_type spatial;
render_mode unshaded;


uniform float outer_circle_radius = 0.5;
uniform float inner_circle_radius = 0.25;
uniform float edge_thickness = 0.05;
uniform float transparency = 0.0;
uniform vec3 tint : source_color;
uniform vec3 edge_tint : source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 center = UV - 0.5;
	float dist_to_center = sqrt(pow(center.x, 2) + pow(center.y, 2));
	float outer_circle_mask = step(dist_to_center, outer_circle_radius);
	float inner_circle_mask = step(dist_to_center, inner_circle_radius);
	float mask = outer_circle_mask - inner_circle_mask;
	ALPHA = mask * (1.0 - transparency);

	float edge_outer_circle_mask = step(dist_to_center, outer_circle_radius - edge_thickness);
	float edge_inner_circle_mask = step(dist_to_center, inner_circle_radius + edge_thickness);
	float edge_mask = mask - (edge_outer_circle_mask - edge_inner_circle_mask);

	ALBEDO = mix(tint, edge_tint, edge_mask);

}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
