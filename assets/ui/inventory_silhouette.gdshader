shader_type canvas_item;

uniform vec4 silhouette_color : source_color = vec4(0.075, 0.065, 0.06, 0.82);

void fragment() {
	float source_alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(silhouette_color.rgb, source_alpha * silhouette_color.a);
}
