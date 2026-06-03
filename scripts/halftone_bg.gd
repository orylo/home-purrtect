extends ColorRect
## 하프톤 배경 셰이더에 시간 주입 — canvas TIME이 안 도는 환경 대비, 매 프레임 u_time을 직접 넣어 확실히 흐르게.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("u_time", _t)
