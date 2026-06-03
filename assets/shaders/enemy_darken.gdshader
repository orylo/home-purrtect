shader_type canvas_item;
// 검은쥐 리스킨: 회색 몸통만 어둡게, 흰 부분(손·눈)은 그대로 보존.
// 밝기(luminance)가 white_keep 이상이면 원본 유지, 그 아래는 darken 배율로 곱.
uniform float darken : hint_range(0.0, 1.0) = 0.40;     // 몸통 어둡기(낮을수록 검정)
uniform float white_keep : hint_range(0.0, 1.0) = 0.74; // 이 밝기 이상은 흰색 보존

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float w = smoothstep(white_keep, 0.95, lum);   // 1=흰색 보존, 0=어둡게
	vec3 body = tex.rgb * darken;
	vec3 outc = mix(body, tex.rgb, w);
	COLOR.rgb = outc * COLOR.rgb;                   // 노드 modulate(피격 플래시 등) 반영
	COLOR.a = tex.a * COLOR.a;
}
