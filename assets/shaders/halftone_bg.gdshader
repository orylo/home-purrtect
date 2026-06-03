shader_type canvas_item;
// 절차적 AM(진폭변조) 하프톤 배경 — 검정 위 흰 점이 그리드에 고정되고,
// 점의 '반지름'이 흐르는 노이즈 밝기 필드에 따라 커졌다 작아지며 구름처럼 일렁인다.
// 풀스크린 ColorRect에 ShaderMaterial로 붙여서 배경 레이어로 사용.
// 해상도 무관: 정규화 UV(0~1) + SCREEN_PIXEL_SIZE로 종횡비 보정(점이 항상 정사각).

render_mode blend_mix;   // 게임 위에 부드럽게 깔림. (가산광 느낌 원하면 blend_add 로 바꿔도 됨)

// ── 인스펙터 조절 ───────────────────────────────────────────────
group_uniforms grid;
uniform float grid_density : hint_range(20.0, 480.0) = 220.0;   // 가로 셀 개수(클수록 점이 작고 촘촘)
uniform float dot_min : hint_range(0.0, 0.5) = 0.0;             // 최소 점 반지름(셀 기준, 0=완전 사라짐)
uniform float dot_max : hint_range(0.1, 0.75) = 0.58;          // 최대 점 반지름(0.5=맞닿음, 그 이상=살짝 겹침)

group_uniforms field;
uniform float noise_scale : hint_range(0.3, 8.0) = 2.0;        // 밝기 덩어리 크기(작을수록 큰 구름)
uniform float anim_speed : hint_range(0.0, 1.0) = 0.06;        // 흐르는 속도(천천히 흐름)
uniform float contrast : hint_range(0.2, 4.0) = 1.6;          // 밝고 어두움 대비
uniform float brightness : hint_range(0.0, 1.0) = 0.5;        // 전체 밝기(점 평균 크기)

group_uniforms look;
uniform float alpha : hint_range(0.0, 1.0) = 0.45;            // 전체 불투명도(게임 안 가리게 약하게)
uniform vec4 dot_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0); // 점 사이 배경(기본 투명=오버레이). 검정 불투명으로 두면 단독 배경.

// ── value noise + fbm ──────────────────────────────────────────
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i + vec2(0.0, 0.0)).x;
	float b = hash2(i + vec2(1.0, 0.0)).x;
	float c = hash2(i + vec2(0.0, 1.0)).x;
	float d = hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// 종횡비(가로/세로). SCREEN_PIXEL_SIZE = 1/해상도.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 grid = vec2(grid_density, grid_density / aspect);   // 세로 셀 = 가로/aspect → 정사각 셀

	// 셀 좌표 / 셀 중심 기준 로컬 좌표
	vec2 cell = UV * grid;
	vec2 cell_id = floor(cell);
	vec2 local = fract(cell) - 0.5;                          // -0.5~0.5

	// 밝기 필드: 셀 중심에서 1회 샘플(→ 점은 셀에 고정) + TIME으로 흐름
	vec2 field_uv = (cell_id + 0.5) / grid;
	float t = TIME * anim_speed;
	// 두 방향으로 흐르는 fbm을 겹쳐 구름처럼 일렁이게
	vec2 q = field_uv * noise_scale * vec2(aspect, 1.0);
	float n = fbm(q + vec2(t, t * 0.6));
	n = mix(n, fbm(q * 1.7 + vec2(-t * 0.5, t * 0.9)), 0.4);

	// 대비/밝기 적용
	float b = clamp((n - 0.5) * contrast + brightness, 0.0, 1.0);

	// 점 반지름 = 밝기에 비례
	float radius = mix(dot_min, dot_max, b);
	float dist = length(local);

	// 점 가장자리 안티에일리어싱(smoothstep, 화면 픽셀 기준 폭)
	float aa = fwidth(dist) + 1e-4;
	float dot = 1.0 - smoothstep(radius - aa, radius + aa, dist);

	// 합성: 배경 ↔ 점
	vec4 col = mix(bg_color, dot_color, dot);
	col.a *= alpha;
	COLOR = col;
}
