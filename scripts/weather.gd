extends Node2D
## 날씨(비/눈) — 화면 위에서 입자가 떨어져 바닥선(Layout.ground_y)에서 착지.
##   비 = 빗줄기 + 착지 튀김(splash) / 눈 = 흩날리며 내려와 바닥에서 사르르.
##   스테이지별 모드(WEATHER). z_index로 캐릭터 앞(HUD 뒤).

## 스테이지별 날씨. 키="막-스테이지". 없으면 없음.
const WEATHER := {
	"1-1": "rain",
	"1-2": "snow",
}

const RAIN_COL := Color(0.72, 0.80, 0.95, 0.55)
const SNOW_COL := Color(1.0, 1.0, 1.0, 0.92)

var _mode := "none"
var _p: Array = []        # 입자 [{x,y,spd,...}]
var _splash: Array = []   # 비 착지 튀김 [{x,y,t}]
var _t := 0.0


func _ready() -> void:
	_mode = WEATHER.get("%d-%d" % [GameState.stage_major, GameState.stage_minor], "none")
	if _mode == "none":
		set_process(false)
		return
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	_p.clear()
	_splash.clear()
	var vp := get_viewport().get_visible_rect().size
	var n := 140 if _mode == "rain" else 100
	for i in n:
		_p.append(_make(vp, true))


## 입자 1개 생성. scatter=true면 화면 전체에 흩뿌림(초기), false면 화면 위에서.
func _make(vp: Vector2, scatter: bool) -> Dictionary:
	var y := (randf() * vp.y) if scatter else (-randf_range(10.0, vp.y * 0.4))
	if _mode == "rain":
		return {
			"x": randf() * (vp.x + 120.0) - 60.0, "y": y,
			"spd": randf_range(1000.0, 1500.0), "len": randf_range(16.0, 30.0),
			"land": randf_range(-30.0, 30.0),   # ground_y ±30px 랜덤 착지(깊이감)
		}
	return {  # snow
		"x": randf() * (vp.x + 80.0) - 40.0, "y": y,
		"spd": randf_range(70.0, 150.0), "r": randf_range(2.0, 4.2),
		"amp": randf_range(8.0, 24.0), "sw": randf_range(0.5, 1.3), "ph": randf() * TAU,
		"land": randf_range(-30.0, 30.0),   # ground_y ±30px 랜덤 착지
	}


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport().get_visible_rect().size
	var gy := Layout.ground_y()
	if _mode == "rain":
		_step_rain(delta, vp, gy)
	else:
		_step_snow(delta, vp, gy)
	queue_redraw()


func _step_rain(delta: float, vp: Vector2, gy: float) -> void:
	for d in _p:
		d.y += d.spd * delta
		d.x -= d.spd * 0.18 * delta          # 살짝 비스듬히(바람)
		if d.y >= gy + d.land:
			_splash.append({"x": d.x, "y": gy + d.land, "t": 0.0})
			var nd := _make(vp, false)
			d.x = nd.x; d.y = nd.y; d.spd = nd.spd; d.len = nd.len; d.land = nd.land
	var keep: Array = []
	for s in _splash:
		s.t += delta
		if s.t < 0.26:
			keep.append(s)
	_splash = keep


func _step_snow(delta: float, vp: Vector2, gy: float) -> void:
	for f in _p:
		f.y += f.spd * delta
		f.x += sin(_t * f.sw + f.ph) * f.amp * delta   # 좌우 흩날림
		if f.y >= gy + f.land:
			var nf := _make(vp, false)
			f.x = nf.x; f.y = nf.y; f.spd = nf.spd; f.r = nf.r; f.amp = nf.amp; f.sw = nf.sw; f.ph = nf.ph; f.land = nf.land


func _draw() -> void:
	var gy := Layout.ground_y()
	if _mode == "rain":
		for d in _p:
			# 착지 직전엔 점점 짧아지게(땅에 닿는 느낌)
			var near: float = clampf((gy + float(d.land) - float(d.y)) / 40.0, 0.2, 1.0)
			var l: float = float(d.len) * near
			draw_line(Vector2(d.x, d.y), Vector2(float(d.x) + 0.18 * l, float(d.y) - l), RAIN_COL, 2.0)   # 꼬리=진행 반대(우상단)
		for s in _splash:
			var a: float = 1.0 - float(s.t) / 0.26
			var rad: float = 3.0 + float(s.t) * 60.0
			draw_arc(Vector2(s.x, s.y), rad, PI, TAU, 10, Color(RAIN_COL.r, RAIN_COL.g, RAIN_COL.b, 0.5 * a), 2.0)
	else:
		for f in _p:
			# 바닥 근처에서 사르르 사라짐(스밈)
			var fade: float = clampf((gy + float(f.land) - float(f.y)) / 28.0, 0.0, 1.0)
			var c := SNOW_COL
			c.a *= (0.4 + 0.6 * fade)
			draw_circle(Vector2(f.x, f.y), f.r, c)
