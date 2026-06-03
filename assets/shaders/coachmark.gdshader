shader_type canvas_item;
// 홈 코치마크: 화면 전체를 어둡게(dim) 하되, hole_center 반경 hole_radius 안만 투명(버튼 강조).
uniform vec2 hole_center = vec2(0.0);          // px(화면)
uniform float hole_radius : hint_range(10.0, 600.0) = 90.0;
uniform vec2 screen_size = vec2(1152.0, 648.0);
uniform float dim : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec2 px = UV * screen_size;
	float d = distance(px, hole_center);
	// 구멍 안(d<radius)=투명, 밖=dim. 가장자리 부드럽게.
	float a = dim * smoothstep(hole_radius - 2.0, hole_radius + 12.0, d);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
