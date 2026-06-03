extends ColorRect
## 하프톤 배경 셰이더 제어 — 시간 주입 + 스테이지별 모션/속도 랜덤 + 특정 스테이지 폭풍 분위기.
##   material(ShaderMaterial)의 uniform을 _ready에서 스테이지에 맞게 세팅, u_time은 매 프레임 주입.

## 폭풍(휘몰아치는 강풍) 분위기 스테이지. 키="막-스테이지". 다른 스테이지도 추가 가능.
const STORM := {
	"1-20": true,
}

var _t := 0.0


func _ready() -> void:
	if material is ShaderMaterial:
		_setup(material as ShaderMaterial)


func _setup(m: ShaderMaterial) -> void:
	var key := "%d-%d" % [GameState.stage_major, GameState.stage_minor]
	if STORM.has(key):
		# 폭풍: 빠르고 강하게 휘몰아침 + 한 방향 강풍
		m.set_shader_parameter("anim_speed", 1.7)
		m.set_shader_parameter("warp_strength", 2.9)
		m.set_shader_parameter("drift", -0.8)          # 한쪽으로 세게 부는 바람
		m.set_shader_parameter("noise_scale", 2.7)
		m.set_shader_parameter("contrast", 2.0)
		m.set_shader_parameter("alpha", 0.6)           # 더 짙게(몰아치는 느낌)
	else:
		# 일반: 스테이지(이번 판)마다 모션·속도 랜덤
		m.set_shader_parameter("anim_speed", randf_range(0.4, 1.0))
		m.set_shader_parameter("warp_strength", randf_range(1.2, 2.4))
		m.set_shader_parameter("drift", randf_range(-0.4, 0.4))
		m.set_shader_parameter("noise_scale", randf_range(1.6, 2.6))
		m.set_shader_parameter("contrast", 1.6)
		m.set_shader_parameter("alpha", 0.45)


func _process(delta: float) -> void:
	_t += delta
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("u_time", _t)
