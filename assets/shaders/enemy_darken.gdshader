shader_type canvas_item;
// 검은쥐 리스킨: "회색 털"만 어둡게. 흰색(손·눈)과 색깔 장비(분홍 헬멧·스케이트·포대 등)는 보존.
//   판정: 채도 낮고(회색) + 너무 밝지 않은(흰색 아님) 픽셀만 = 털 → 어둡게.
uniform float darken : hint_range(0.0, 1.0) = 0.40;     // 털 어둡기(낮을수록 검정)
uniform float white_keep : hint_range(0.0, 1.0) = 0.74; // 이 밝기 이상 = 흰색 보존
uniform float sat_keep : hint_range(0.0, 1.0) = 0.20;   // 이 채도 이상 = 색깔 장비 보존

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mx = max(tex.r, max(tex.g, tex.b));
	float mn = min(tex.r, min(tex.g, tex.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float is_gray = 1.0 - smoothstep(sat_keep - 0.05, sat_keep + 0.05, sat);   // 1=무채색(털), 0=유채색(장비)
	float not_white = 1.0 - smoothstep(white_keep - 0.06, white_keep + 0.10, lum); // 1=어두움(털), 0=흰색
	float fur = is_gray * not_white;            // 회색 + 흰색 아님 = 털
	vec3 dark = tex.rgb * darken;
	vec3 outc = mix(tex.rgb, dark, fur);        // 털만 어둡게, 나머지 원본
	COLOR.rgb = outc * COLOR.rgb;               // 노드 modulate(피격 플래시 등) 반영
	COLOR.a = tex.a * COLOR.a;
}
