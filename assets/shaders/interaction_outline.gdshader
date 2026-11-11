shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;
uniform vec4 outline_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform float outline_pixels = 1.4;
void vertex() {
 vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
 vec3 view_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
 vec2 direction = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
 direction /= max(length(direction), 0.001);
 clip.xy += direction * clip.w * 2.0 * outline_pixels / VIEWPORT_SIZE;
 POSITION = clip;
}
void fragment() { ALBEDO = outline_color.rgb; }
