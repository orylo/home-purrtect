extends ColorRect
## 하프톤 배경 셰이더 제어 — 시간 주입 + 스테이지별 모션/속도 랜덤 + 특정 스테이지 폭풍 분위기.
##   material(ShaderMaterial)의 uniform을 _ready에서 스테이지에 맞게 세팅, u_time은 매 프레임 주입.

## 하프톤 날씨 프리셋 — 셰이더 uniform 묶음. 점 크기/밀도는 셰이더 기본값 유지, 모션·농도만 바꿈.
const PRESETS := {
	"calm":    {"anim_speed": 0.25, "warp": 1.0, "drift": 0.05, "contrast": 1.5, "brightness": 0.30, "alpha": 0.35, "noise": 2.0},  # 잔잔
	"fog":     {"anim_speed": 0.28, "warp": 1.2, "drift": 0.10, "contrast": 1.2, "brightness": 0.55, "alpha": 0.55, "noise": 1.2},  # 안개 자욱(큰 덩어리·짙음)
	"windy":   {"anim_speed": 0.80, "warp": 0.8, "drift": 0.65, "contrast": 1.6, "brightness": 0.40, "alpha": 0.45, "noise": 1.6},  # 빠른 구름(옆으로 좍좍)
	"shimmer": {"anim_speed": 0.60, "warp": 2.7, "drift": 0.00, "contrast": 1.7, "brightness": 0.35, "alpha": 0.40, "noise": 2.4},  # 아지랑이(제자리 일렁)
	"storm":   {"anim_speed": 1.70, "warp": 2.9, "drift": 0.80, "contrast": 2.0, "brightness": 0.50, "alpha": 0.60, "noise": 2.7},  # 폭풍
}
## 일반 스테이지는 이 중 랜덤
const NORMAL_POOL := ["calm", "fog", "windy", "shimmer"]
## 스테이지 고정 날씨. 키="막-스테이지".
const STAGE_WEATHER := {
	"1-10": "storm",
	"1-20": "storm",
}

var _t := 0.0


func _ready() -> void:
	if material is ShaderMaterial:
		_setup(material as ShaderMaterial)


func _setup(m: ShaderMaterial) -> void:
	var key := "%d-%d" % [GameState.stage_major, GameState.stage_minor]
	var name: String = STAGE_WEATHER.get(key, NORMAL_POOL[randi() % NORMAL_POOL.size()])
	var p: Dictionary = PRESETS[name]
	# drift 방향은 매 판 랜덤(왼/오) — 한쪽으로만 흐르지 않게
	var dir := 1.0 if randf() < 0.5 else -1.0
	m.set_shader_parameter("anim_speed", p["anim_speed"])
	m.set_shader_parameter("warp_strength", p["warp"])
	m.set_shader_parameter("drift", float(p["drift"]) * dir)
	m.set_shader_parameter("contrast", p["contrast"])
	m.set_shader_parameter("brightness", p["brightness"])
	m.set_shader_parameter("alpha", p["alpha"])
	m.set_shader_parameter("noise_scale", p["noise"])


func _process(delta: float) -> void:
	_t += delta
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("u_time", _t)
