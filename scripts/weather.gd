extends Node2D
## 날씨 — 화면 앞 레이어(z55). 입자(비/눈/낙엽/먼지/반딧불)는 바닥선(Layout.ground_y)에서 착지(±50px),
##   빛/하늘(쾌청/노을/달밤)은 오버레이, 번개는 섬광, 전환은 비→쾌청.
##   스테이지별 WEATHER. 헤드리스에선 안 보이고 F5/웹에서만.

const WEATHER := {
	"1-1": "rain",       # 비
	"1-2": "snow",       # 눈
	"1-3": "sunny",      # 쾌청(햇살·갓레이)
	"1-4": "sunset",     # 노을/황혼
	"1-5": "moonlit",    # 달밤
	"1-6": "leaves",     # 낙엽
	"1-7": "motes",      # 먼지/꽃가루 부유
	"1-8": "fireflies",  # 반딧불
	"1-9": "lightning",  # 번개(+빗줄기)
	"1-11": "transition",# 비→쾌청 전환
}

const RAIN_COL := Color(0.72, 0.80, 0.95, 0.55)
const SNOW_COL := Color(1.0, 1.0, 1.0, 0.92)
const LAND := 50.0   # 착지 ground_y ± 이 값 랜덤

var _mode := "none"
var _p: Array = []
var _splash: Array = []
var _t := 0.0
var _flash := 0.0
var _flash_next := 3.0
var _trans := 0.0       # 전환 진행(0=비 → 1=쾌청)


func _ready() -> void:
	_mode = WEATHER.get("%d-%d" % [GameState.stage_major, GameState.stage_minor], "none")
	if _mode == "none":
		set_process(false)
		return
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()
	_flash_next = randf_range(2.5, 6.0)


func _is_particle(m: String) -> bool:
	return m in ["rain", "snow", "leaves", "motes", "fireflies", "lightning", "transition"]


func _rebuild() -> void:
	_p.clear()
	_splash.clear()
	if not _is_particle(_mode):
		return
	var vp := get_viewport().get_visible_rect().size
	var counts := {"rain": 140, "snow": 100, "leaves": 46, "motes": 90, "fireflies": 36, "lightning": 90, "transition": 140}
	for i in int(counts.get(_mode, 0)):
		_p.append(_make(vp, true))


func _make(vp: Vector2, scatter: bool) -> Dictionary:
	var base := _mode
	if base == "lightning" or base == "transition":
		base = "rain"
	var y := (randf() * vp.y) if scatter else (-randf_range(10.0, vp.y * 0.4))
	match base:
		"rain":
			return {"k": "rain", "x": randf() * (vp.x + 120.0) - 60.0, "y": y,
				"spd": randf_range(1000.0, 1500.0), "len": randf_range(16.0, 30.0), "land": randf_range(-LAND, LAND)}
		"snow":
			return {"k": "snow", "x": randf() * (vp.x + 80.0) - 40.0, "y": y,
				"spd": randf_range(70.0, 150.0), "r": randf_range(2.0, 4.2),
				"amp": randf_range(8.0, 24.0), "sw": randf_range(0.5, 1.3), "ph": randf() * TAU, "land": randf_range(-LAND, LAND)}
		"leaves":
			var pal := [Color(0.78, 0.42, 0.18), Color(0.85, 0.6, 0.2), Color(0.65, 0.25, 0.18), Color(0.6, 0.5, 0.2)]
			return {"k": "leaf", "x": randf() * (vp.x + 100.0) - 50.0, "y": y,
				"spd": randf_range(60.0, 130.0), "r": randf_range(8.0, 15.0),
				"amp": randf_range(26.0, 55.0), "sw": randf_range(0.6, 1.4), "ph": randf() * TAU,
				"rot": randf() * TAU, "rspd": randf_range(-2.5, 2.5), "col": pal[randi() % pal.size()], "land": randf_range(-LAND, LAND)}
		"motes":
			return {"k": "mote", "x": randf() * vp.x, "y": randf() * vp.y,
				"vx": randf_range(-14.0, 14.0), "vy": randf_range(-10.0, 6.0),
				"r": randf_range(1.5, 3.2), "ph": randf() * TAU}
		"fireflies":
			return {"k": "fly", "x": randf() * vp.x, "y": vp.y * randf_range(0.30, 0.85),
				"vx": randf_range(-22.0, 22.0), "vy": randf_range(-14.0, 14.0),
				"r": randf_range(2.4, 4.0), "ph": randf() * TAU, "bs": randf_range(1.5, 3.0)}
	return {"k": "rain", "x": 0.0, "y": 0.0, "spd": 1200.0, "len": 20.0, "land": 0.0}


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport().get_visible_rect().size
	var gy := Layout.ground_y()
	# 입자 갱신
	for d in _p:
		_step_one(d, delta, vp, gy)
	# 비 splash 수명
	var keep: Array = []
	for s in _splash:
		s.t += delta
		if s.t < 0.26:
			keep.append(s)
	_splash = keep
	# 번개 섬광
	if _mode == "lightning":
		_flash = maxf(0.0, _flash - delta * 4.5)
		_flash_next -= delta
		if _flash_next <= 0.0:
			_flash = 1.0
			_flash_next = randf_range(2.5, 6.5)
	# 전환 진행
	if _mode == "transition":
		_trans = minf(1.0, _trans + delta / 12.0)
	queue_redraw()


func _step_one(d: Dictionary, delta: float, vp: Vector2, gy: float) -> void:
	match d.k:
		"rain":
			d.y += d.spd * delta
			d.x -= d.spd * 0.18 * delta
			if d.y >= gy + d.land:
				_splash.append({"x": d.x, "y": gy + d.land, "t": 0.0})
				var n := _make(vp, false)
				for kk in n.keys(): d[kk] = n[kk]
		"snow":
			d.y += d.spd * delta
			d.x += sin(_t * d.sw + d.ph) * d.amp * delta
			if d.y >= gy + d.land:
				var n := _make(vp, false)
				for kk in n.keys(): d[kk] = n[kk]
		"leaf":
			d.y += d.spd * delta
			d.x += sin(_t * d.sw + d.ph) * d.amp * delta
			d.rot += d.rspd * delta
			if d.y >= gy + d.land:
				var n := _make(vp, false)
				for kk in n.keys(): d[kk] = n[kk]
		"mote":
			d.x += d.vx * delta
			d.y += d.vy * delta
			if d.x < -10.0: d.x += vp.x + 20.0
			elif d.x > vp.x + 10.0: d.x -= vp.x + 20.0
			if d.y < -10.0: d.y += vp.y + 20.0
			elif d.y > vp.y + 10.0: d.y -= vp.y + 20.0
		"fly":
			d.x += d.vx * delta
			d.y += d.vy * delta
			if d.x < 20.0 or d.x > vp.x - 20.0: d.vx = -d.vx
			if d.y < vp.y * 0.25 or d.y > vp.y * 0.9: d.vy = -d.vy


func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	var gy := Layout.ground_y()
	# 빛/하늘 오버레이
	match _mode:
		"sunny": _draw_sunny(vp, 1.0)
		"sunset": _draw_sunset(vp)
		"moonlit": _draw_moonlit(vp)
		"transition":
			var rainA: float = 1.0 - smoothstep(0.35, 0.7, _trans)
			var sunA: float = smoothstep(0.5, 1.0, _trans)
			_draw_particles(gy, rainA)
			if sunA > 0.0: _draw_sunny(vp, sunA)
			return
	# 입자
	_draw_particles(gy, 1.0)
	# 번개 섬광(맨 위)
	if _mode == "lightning" and _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, _flash * 0.5), true)


func _draw_particles(gy: float, gA: float) -> void:
	for d in _p:
		match d.k:
			"rain":
				var near: float = clampf((gy + float(d.land) - float(d.y)) / 40.0, 0.2, 1.0)
				var l: float = float(d.len) * near
				draw_line(Vector2(d.x, d.y), Vector2(float(d.x) + 0.18 * l, float(d.y) - l), _a(RAIN_COL, gA), 2.0)
			"snow":
				var fade: float = clampf((gy + float(d.land) - float(d.y)) / 28.0, 0.0, 1.0)
				draw_circle(Vector2(d.x, d.y), float(d.r), _a(SNOW_COL, (0.4 + 0.6 * fade) * gA))
			"leaf":
				var fade2: float = clampf((gy + float(d.land) - float(d.y)) / 30.0, 0.0, 1.0)
				_draw_leaf(Vector2(d.x, d.y), float(d.r), float(d.rot), _a(d.col, (0.45 + 0.55 * fade2) * gA))
			"mote":
				var tw: float = 0.35 + 0.25 * sin(_t * 1.5 + float(d.ph))
				draw_circle(Vector2(d.x, d.y), float(d.r), Color(1.0, 0.95, 0.75, tw * gA))
			"fly":
				var bl: float = 0.15 + 0.85 * pow(maxf(0.0, sin(_t * float(d.bs) + float(d.ph))), 2.0)
				draw_circle(Vector2(d.x, d.y), float(d.r) * 2.2, Color(0.9, 1.0, 0.4, 0.10 * bl * gA))  # 글로우
				draw_circle(Vector2(d.x, d.y), float(d.r), Color(1.0, 1.0, 0.5, 0.9 * bl * gA))
	for s in _splash:
		var a: float = 1.0 - float(s.t) / 0.26
		var rad: float = 3.0 + float(s.t) * 60.0
		draw_arc(Vector2(s.x, s.y), rad, PI, TAU, 10, _a(RAIN_COL, 0.5 * a * gA), 2.0)


func _draw_leaf(c: Vector2, r: float, rot: float, col: Color) -> void:
	var dir := Vector2(cos(rot), sin(rot))
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([c - dir * r, c + perp * r * 0.55, c + dir * r, c - perp * r * 0.55])
	draw_colored_polygon(pts, col)


## 쾌청 — 우상단 태양 글로우 + 갓레이(빛줄기, 천천히 흔들), 따뜻한 틴트. a=세기(전환용).
func _draw_sunny(vp: Vector2, a: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.93, 0.66, 0.08 * a), true)   # 따뜻한 틴트
	var sun := Vector2(vp.x * 0.86, vp.y * 0.15)
	var base_ang := PI * 0.72
	var L := vp.length()
	for k in range(8):
		var ang := base_ang + (k - 3.5) * 0.10 + sin(_t * 0.15 + k) * 0.04
		var dd := Vector2(cos(ang), sin(ang))
		var pp := Vector2(-dd.y, dd.x)
		var w := 12.0
		draw_colored_polygon(PackedVector2Array([sun, sun + dd * L + pp * w, sun + dd * L - pp * w]), Color(1.0, 0.9, 0.6, 0.045 * a))
	for k in range(7):
		draw_circle(sun, 30.0 + k * 16.0, Color(1.0, 0.95, 0.72, 0.05 * a))
	draw_circle(sun, 30.0, Color(1.0, 0.98, 0.82, 0.55 * a))


## 노을/황혼 — 따뜻한 세로 그라데이션 틴트(위 주황 → 아래 분홍).
func _draw_sunset(vp: Vector2) -> void:
	var bands := 8
	for i in range(bands):
		var f := float(i) / float(bands - 1)
		var col := Color(0.95, 0.55, 0.25).lerp(Color(0.85, 0.4, 0.55), f)
		col.a = 0.14
		draw_rect(Rect2(0.0, vp.y * f / 1.0 * 0.0 + vp.y * float(i) / bands, vp.x, vp.y / bands + 1.0), col, true)
	draw_circle(Vector2(vp.x * 0.5, vp.y * 0.62), 70.0, Color(1.0, 0.75, 0.4, 0.18))   # 낮은 해 글로우


## 달밤 — 차가운 틴트 + 달.
func _draw_moonlit(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.30, 0.40, 0.72, 0.16), true)
	var moon := Vector2(vp.x * 0.82, vp.y * 0.18)
	for k in range(6):
		draw_circle(moon, 36.0 + k * 12.0, Color(0.8, 0.86, 1.0, 0.05))
	draw_circle(moon, 34.0, Color(0.95, 0.96, 1.0, 0.9))


func _a(base: Color, alpha: float) -> Color:
	return Color(base.r, base.g, base.b, base.a * alpha)
