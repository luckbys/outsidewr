shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 step_uv = vec2(0.003, 0.005);
	vec3 color = texture(TEXTURE, UV).rgb * 0.2;
	color += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).rgb * 0.12;
	color += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).rgb * 0.12;
	color += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).rgb * 0.12;
	color += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).rgb * 0.12;
	color += texture(TEXTURE, UV + step_uv).rgb * 0.08;
	color += texture(TEXTURE, UV - step_uv).rgb * 0.08;
	color += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).rgb * 0.08;
	color += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).rgb * 0.08;
	color = mix(color, vec3(0.65, 0.62, 0.55), 0.16 + (1.0 - UV.y) * 0.15);
	float vignette = smoothstep(0.25, 0.76, length((UV - vec2(0.5, 0.32)) * vec2(0.9, 1.0)));
	color *= 1.0 - vignette * 0.58;
	COLOR = vec4(color, 1.0);
}
