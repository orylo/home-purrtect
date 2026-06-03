extends Node2D
## 날씨 — 화면 앞 레이어(z55). 입자(비/눈/낙엽/먼지/반딧불)는 바닥선(Layout.ground_y)에서 착지(±50px),
##   빛/하늘(쾌청/노을/밤)은 오버레이, 번개는 불규칙 섬광+천둥, 전환은 비→쾌청.
##   스테이지별 WEATHER. 헤드리스에선 안 보이고 F5/웹에서만.

const WEATHER := {
	"1-1": "rain",       # 비
	"1-2": "snow",       # 눈
	"1-3": "sunny",      # 쾌청(렌즈 플레어 햇살)
	"1-4": "sunset",     # 노을(주황→노랑→분홍)
	"1-5": "night",      # 밤(인디고 그라데이션)
	"1-6": "leaves",     # 낙엽
	"1-7": "motes",      # 먼지(갈색/회색 알갱이)
	"1-8": "fireflies",  # 반딧불
	"1-9": "lightning",  # 번개(불규칙 섬광+천둥+비)
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
var _flash2 := 0.0      # 잔섬광 대기
var _trans := 0.0       # 전환 진행(0=비 → 1=쾌청)


func _ready() -> void:
	_mode = WEATHER.get("%d-%d" % [GameState.stage_major, GameState.stage_minor], "none")
	if _mode == "none":
		set_process(false)
		return
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()
	_flash_next = randf_range(1.5, 5.0)


func _is_particle(m: String) -> bool:
	return m in ["rain", "snow", "leaves", "motes", "fireflies", "lightning", "transition"]


func _rebuild() -> void:
	_p.clear()
	_splash.clear()
	if not _is_particle(_mode):
		return
	var vp := get_viewport().get_visible_rect().size
	var counts := {"rain": 140, "snow": 100, "leaves": 46, "motes": 95, "fireflies": 36, "lightning": 90, "transition": 140}
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
			var pal := [Color(0.78, 0.42, 0.18), Color(0.85, 0.6, 0.2), Color(0.62, 0.25, 0.16), Color(0.55, 0.5, 0.18)]
			return {"k": "leaf", "x": randf() * (vp.x + 100.0) - 50.0, "y": y,
				"spd": randf_range(55.0, 120.0), "r": randf_range(9.0, 16.0),
				"amp": randf_range(28.0, 58.0), "sw": randf_range(0.6, 1.3), "ph": randf() * TAU,
				"rot": randf() * TAU, "rspd": randf_range(-2.2, 2.2), "col": pal[randi() % pal.size()], "land": randf_range(-LAND, LAND)}
		"motes":
			var dust := [Color(0.55, 0.46, 0.36), Color(0.5, 0.5, 0.52), Color(0.6, 0.52, 0.42), Color(0.46, 0.44, 0.46)]
			return {"k": "mote", "x": randf() * vp.x, "y": randf() * vp.y,
				"vx": randf_range(-20.0, 20.0), "vy": randf_range(-16.0, 16.0),
				"r": randf_range(1.6, 3.6), "ph": randf() * TAU, "col": dust[randi() % dust.size()]}
		"fireflies":
			return {"k": "fly", "x": randf() * vp.x, "y": vp.y * randf_range(0.30, 0.85),
				"vx": randf_range(-22.0, 22.0), "vy": randf_range(-14.0, 14.0),
				"r": randf_range(2.4, 4.0), "ph": randf() * TAU, "bs": randf_range(1.5, 3.0)}
	return {"k": "rain", "x": 0.0, "y": 0.0, "spd": 1200.0, "len": 20.0, "land": 0.0}


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport().get_visible_rect().size
	var gy := Layout.ground_y()
	for d in _p:
		_step_one(d, delta, vp, gy)
	var keep: Array = []
	for s in _splash:
		s.t += delta
		if s.t < 0.26:
			keep.append(s)
	_splash = keep
	# 번개: 불규칙 간격 + 가끔 잔섬광 + 천둥
	if _mode == "lightning":
		_flash = maxf(0.0, _flash - delta * 5.5)
		if _flash2 > 0.0:
			_flash2 -= delta
			if _flash2 <= 0.0:
				_flash = maxf(_flash, 0.65)
		_flash_next -= delta
		if _flash_next <= 0.0:
			_flash = 1.0
			Sfx.play("thunder", randf_range(0.85, 1.15), -2.0)
			_flash_next = randf_range(1.4, 7.5)              # 불규칙
			_flash2 = randf_range(0.07, 0.18) if randf() < 0.4 else 0.0
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
		"mote", "fly":
			d.x += d.vx * delta
			d.y += d.vy * delta
			var top := (vp.y * 0.25) if d.k == "fly" else 10.0
			var bot := (vp.y * 0.9) if d.k == "fly" else (vp.y - 10.0)
			if d.x < 10.0 or d.x > vp.x - 10.0: d.vx = -d.vx
			if d.y < top or d.y > bot: d.vy = -d.vy


func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	var gy := Layout.ground_y()
	match _mode:
		"sunny": _draw_sunny(vp, 1.0)
		"sunset": _draw_sunset(vp)
		"night": _draw_night(vp)
		"transition":
			var rainA: float = 1.0 - smoothstep(0.35, 0.7, _trans)
			var sunA: float = smoothstep(0.5, 1.0, _trans)
			_draw_particles(gy, rainA)
			if sunA > 0.0: _draw_sunny(vp, sunA)
			return
	_draw_particles(gy, 1.0)
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
				_draw_leaf(Vector2(d.x, d.y), float(d.r), float(d.rot), _a(d.col, (0.5 + 0.5 * fade2) * gA))
			"mote":
				var tw: float = 0.40 + 0.35 * sin(_t * 1.2 + float(d.ph))
				draw_circle(Vector2(d.x, d.y), float(d.r), _a(d.col, tw * gA))
			"fly":
				var bl: float = 0.15 + 0.85 * pow(maxf(0.0, sin(_t * float(d.bs) + float(d.ph))), 2.0)
				draw_circle(Vector2(d.x, d.y), float(d.r) * 2.2, Color(0.9, 1.0, 0.4, 0.10 * bl * gA))
				draw_circle(Vector2(d.x, d.y), float(d.r), Color(1.0, 1.0, 0.5, 0.9 * bl * gA))
	for s in _splash:
		var a: float = 1.0 - float(s.t) / 0.26
		var rad: float = 3.0 + float(s.t) * 60.0
		draw_arc(Vector2(s.x, s.y), rad, PI, TAU, 10, _a(RAIN_COL, 0.5 * a * gA), 2.0)


## 잎 — 양끝 뾰족, 가운데 볼록 + 잎맥(다이아 대신 진짜 잎 모양).
func _draw_leaf(c: Vector2, r: float, rot: float, col: Color) -> void:
	var dir := Vector2(cos(rot), sin(rot))
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var t := float(i) / steps
		pts.append(c + dir * lerp(-r, r, t) + perp * (sin(t * PI) * r * 0.5))
	for i in range(steps + 1):
		var t2 := float(steps - i) / steps
		pts.append(c + dir * lerp(-r, r, t2) - perp * (sin(t2 * PI) * r * 0.5))
	draw_colored_polygon(pts, col)
	draw_line(c - dir * r * 0.85, c + dir * r * 0.85, Color(col.r * 0.55, col.g * 0.55, col.b * 0.5, col.a * 0.85), 1.5)   # 잎맥


## 쾌청 — 우상단 태양 렌즈 플레어(스타버스트 + 고스트 체인), 치즈 위치로 미세 흔들.
func _draw_sunny(vp: Vector2, a: float) -> void:
	var sun := Vector2(vp.x * 0.86, vp.y * 0.15)
	var px := 0.0
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl is Node2D:
		px = clampf((pl as Node2D).global_position.x / maxf(vp.x, 1.0), 0.0, 1.0) - 0.5
	var center := vp * 0.5 + Vector2(px * 46.0, 0.0)   # 걸을 때 플레어가 살짝 움직임
	draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.95, 0.78, 0.07 * a))   # 따뜻한 틴트
	for k in range(9):
		draw_circle(sun, 30.0 + k * 17.0, Color(1.0, 0.97, 0.8, 0.05 * a))  # 글로우
	for i in range(12):                                   # 스타버스트 스파이크
		var ang := TAU * float(i) / 12.0 + 0.05 * sin(_t * 0.3)
		var L: float = (vp.x * 0.5 if i % 3 == 0 else vp.x * 0.22) * (0.9 + 0.1 * sin(_t * 0.7 + i))
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x) * 2.5
		draw_colored_polygon(PackedVector2Array([sun + perp, sun - perp, sun + dir * L]), Color(1, 1, 1, 0.18 * a))
	draw_circle(sun, 26.0, Color(1, 1, 1, 0.9 * a))       # 코어
	# 렌즈 플레어 고스트(태양→중심선 따라)
	var v := center - sun
	var pal := [Color(0.6, 0.72, 1.0), Color(1.0, 0.82, 0.6), Color(0.75, 1.0, 0.8), Color(1.0, 0.7, 0.85), Color(0.85, 0.85, 1.0)]
	var gs := [0.35, 0.6, 0.85, 1.05, 1.35, 1.7, 2.0]
	var rr := [16.0, 9.0, 26.0, 12.0, 40.0, 18.0, 30.0]
	for i in range(gs.size()):
		var pos: Vector2 = sun + v * float(gs[i])
		var rad: float = float(rr[i])
		var col: Color = pal[i % pal.size()]; col.a = 0.10 * a
		draw_circle(pos, rad, col)
		if i % 2 == 0:
			draw_arc(pos, rad * 1.1, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.12 * a), 2.0)


## 노을 — 상단 진한 주황 → 노랑 → 하단 분홍(상단 진하게, 전투무관 영역). 해=쾌청과 동일 우상단.
func _draw_sunset(vp: Vector2) -> void:
	var bands := 12
	for i in range(bands):
		var f := float(i) / float(bands - 1)
		var col: Color
		if f < 0.5:
			col = Color(0.96, 0.45, 0.10).lerp(Color(1.0, 0.80, 0.22), f / 0.5)
		else:
			col = Color(1.0, 0.80, 0.22).lerp(Color(0.96, 0.45, 0.62), (f - 0.5) / 0.5)
		col.a = lerp(0.36, 0.14, f)
		draw_rect(Rect2(0.0, vp.y * float(i) / bands, vp.x, vp.y / bands + 1.0), col, true)
	var sun := Vector2(vp.x * 0.86, vp.y * 0.15)
	for k in range(8):
		draw_circle(sun, 36.0 + k * 18.0, Color(1.0, 0.85, 0.45, 0.06))
	draw_circle(sun, 42.0, Color(1.0, 0.9, 0.6, 0.55))


## 밤 — 상단 진한 인디고 → 하단 푸르스름(달 없음).
func _draw_night(vp: Vector2) -> void:
	var bands := 12
	for i in range(bands):
		var f := float(i) / float(bands - 1)
		var col := Color(0.08, 0.08, 0.30).lerp(Color(0.28, 0.40, 0.62), f)
		col.a = lerp(0.52, 0.22, f)
		draw_rect(Rect2(0.0, vp.y * float(i) / bands, vp.x, vp.y / bands + 1.0), col, true)


func _a(base: Color, alpha: float) -> Color:
	return Color(base.r, base.g, base.b, base.a * alpha)
