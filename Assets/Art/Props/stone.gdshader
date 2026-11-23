shader_type spatial;

uniform sampler2D tex : source_color, repeat_enable;
uniform vec3 base_color : source_color = vec3(0.4);
uniform float scale = 0.5;
uniform float threshold : hint_range(0.0, 1.0) = 0.7;
uniform float softness : hint_range(0.0, 0.5) = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
    float up = normalize(world_normal).y;
    float mask = smoothstep(threshold - softness, threshold + softness + 0.0001, up);

    vec4 projected = texture(tex, world_pos.xz * scale).rgba;
	vec3 projected_t = mix(base_color, projected.rgb, projected.a);
    ALBEDO = mix(base_color, projected_t, mask);
}