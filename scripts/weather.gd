extends Node2D
## 날씨 — 그라운드 BG 앞 / 근경 뒤 레이어(z49). 입자(비/눈/낙엽/먼지/반딧불)는 바닥선(Layout.ground_y)에서 착지(±50px),
##   빛/하늘(쾌청/노을/밤)은 부드러운 세로 그라데이션 오버레이, 번개는 불규칙 섬광+천둥, 전환은 비→쾌청.
##   스테이지별 WEATHER. 헤드리스에선 안 보이고 F5/웹에서만.

const WEATHER := {
	"1-1": "rain",       # 비
	"1-2": "snow",       # 눈
	"1-3": "sunny",      # 쾌청(렌즈 플레어 햇살)
	"1-4": "sunset",     # 노을(주황→노랑→분홍)
	"1-5": "night",      # 밤(네이비→하늘색 그라데이션)
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
	var counts := {"rain": 140, "snow": 100, "leaves": 46, "motes": 120, "fireflies": 36, "lightning": 90, "transition": 140}
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
				"spd": randf_range(55.0, 120.0), "r": randf_range(11.0, 18.0),
				"amp": randf_range(28.0, 58.0), "sw": randf_range(0.6, 1.3), "ph": randf() * TAU,
				"rot": randf() * TAU, "rspd": randf_range(-2.2, 2.2), "col": pal[randi() % pal.size()], "land": randf_range(-LAND, LAND)}
		"motes":
			# 갈색 알갱이와 회색 알갱이를 각각 만들어 섞음(다양한 낙엽처럼)
			var brown := [Color(0.55, 0.40, 0.26), Color(0.62, 0.48, 0.30), Color(0.48, 0.34, 0.20)]
			var gray := [Color(0.52, 0.52, 0.54), Color(0.45, 0.46, 0.48), Color(0.60, 0.60, 0.62)]
			var pool: Array = brown if randf() < 0.55 else gray
			return {"k": "mote", "x": randf() * vp.x, "y": randf() * vp.y,
				"vx": randf_range(-20.0, 20.0), "vy": randf_range(-16.0, 16.0),
				"r": randf_range(1.8, 4.0), "ph": randf() * TAU, "col": pool[randi() % pool.size()]}
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
			Sfx.play("thunder", randf_range(0.9, 1.1), -1.0)
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
			var top := (vp.y * 0.25) if d.k == "fly" else 8.0
			var bot := (vp.y * 0.9) if d.k == "fly" else (vp.y - 8.0)
			if d.x < 8.0 or d.x > vp.x - 8.0: d.vx = -d.vx
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
				var tw: float = 0.45 + 0.35 * sin(_t * 1.2 + float(d.ph))
				draw_circle(Vector2(d.x, d.y), float(d.r) * 2.6, _a(d.col, 0.10 * tw * gA))   # 글로우(흙먼지라 같은 색)
				draw_circle(Vector2(d.x, d.y), float(d.r), _a(d.col, 0.85 * tw * gA))          # 알갱이
			"fly":
				var bl: float = 0.15 + 0.85 * pow(maxf(0.0, sin(_t * float(d.bs) + float(d.ph))), 2.0)
				draw_circle(Vector2(d.x, d.y), float(d.r) * 2.2, Color(0.9, 1.0, 0.4, 0.10 * bl * gA))
				draw_circle(Vector2(d.x, d.y), float(d.r), Color(1.0, 1.0, 0.5, 0.9 * bl * gA))
	for s in _splash:
		var a: float = 1.0 - float(s.t) / 0.26
		var rad: float = 3.0 + float(s.t) * 60.0
		draw_arc(Vector2(s.x, s.y), rad, PI, TAU, 10, _a(RAIN_COL, 0.5 * a * gA), 2.0)


## 잎 — 잎자루 + 가운데 넓고 끝 뾰족한 잎몸 + 가장자리 톱니 + 잎맥(주맥·측맥).
func _draw_leaf(c: Vector2, r: float, rot: float, col: Color) -> void:
	var dir := Vector2(cos(rot), sin(rot))     # 밑동(-r) → 잎끝(+r)
	var perp := Vector2(-dir.y, dir.x)
	var steps := 16
	var pts := PackedVector2Array()
	for i in range(steps + 1):                 # 한쪽 윤곽(밑동→끝)
		var t := float(i) / steps
		pts.append(c + dir * lerp(-r, r, t) + perp * _leaf_w(t) * r)
	for i in range(steps + 1):                 # 반대쪽(끝→밑동)
		var t2 := float(steps - i) / steps
		pts.append(c + dir * lerp(-r, r, t2) - perp * _leaf_w(t2) * r)
	draw_colored_polygon(pts, col)
	var dark := Color(col.r * 0.5, col.g * 0.5, col.b * 0.45, col.a)
	# 잎자루(밑동 바깥으로)
	draw_line(c - dir * r, c - dir * r * 1.4, dark, maxf(1.0, r * 0.10))
	# 주맥
	draw_line(c - dir * r * 0.92, c + dir * r * 0.92, dark, maxf(1.0, r * 0.08))
	# 측맥(좌우 3쌍, 위로 비스듬히)
	for sv in [-0.45, -0.1, 0.28]:
		var s: float = float(sv)
		var bse: Vector2 = c + dir * (r * s)
		var tip: Vector2 = dir * r * 0.34
		var hw: float = _leaf_w((s + 1.0) * 0.5) * r * 0.75
		draw_line(bse, bse + tip + perp * hw, dark, 1.0)
		draw_line(bse, bse + tip - perp * hw, dark, 1.0)


## 잎 폭 곡선(0=밑동,1=끝) — 밑은 둥글고, 가운데 넓고, 끝 뾰족 + 미세 톱니.
func _leaf_w(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var body: float = pow(sin(t * PI), 0.7)       # 양끝 0, 가운데 볼록
	body *= (0.72 + 0.28 * (1.0 - t))             # 밑동 쪽을 더 넓게(잎다움)
	var teeth: float = 1.0 + 0.09 * sin(t * PI * 9.0)   # 가장자리 톱니
	return body * 0.52 * teeth


## 쾌청 — 우상단 태양(부드럽게 번진 빛) + 렌즈 플레어 고스트 체인, 치즈 위치로 미세 흔들.
func _draw_sunny(vp: Vector2, a: float) -> void:
	var sun := Vector2(vp.x * 0.86, vp.y * 0.15)
	var px := 0.0
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl is Node2D:
		px = clampf((pl as Node2D).global_position.x / maxf(vp.x, 1.0), 0.0, 1.0) - 0.5
	var center := vp * 0.5 + Vector2(px * 46.0, 0.0)   # 걸을 때 플레어가 살짝 움직임
	draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.95, 0.78, 0.07 * a))   # 따뜻한 틴트
	# 넓고 부드러운 후광(바깥 → 안, 겹쳐서 번지게)
	for k in range(22):
		var rr0: float = 240.0 - k * 10.0
		draw_circle(sun, rr0, Color(1.0, 0.96, 0.78, 0.018 * a))
	# 부드러운 코어(작은 원을 겹쳐 가우시안처럼 번지게 — 선명한 동그라미 제거)
	for k in range(16):
		var rr1: float = 60.0 - k * 3.4
		draw_circle(sun, rr1, Color(1.0, 0.99, 0.9, 0.05 * a))
	for i in range(12):                                   # 스타버스트 스파이크(은은)
		var ang := TAU * float(i) / 12.0 + 0.05 * sin(_t * 0.3)
		var L: float = (vp.x * 0.5 if i % 3 == 0 else vp.x * 0.22) * (0.9 + 0.1 * sin(_t * 0.7 + i))
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x) * 3.0
		draw_colored_polygon(PackedVector2Array([sun + perp, sun - perp, sun + dir * L]), Color(1, 1, 1, 0.10 * a))
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


## 노을 — 상단 진한 주황 → 노랑 → 하단 분홍(부드러운 세로 그라데이션, 변화폭 크게). 해=쾌청과 동일 우상단.
func _draw_sunset(vp: Vector2) -> void:
	_draw_vgradient(vp, [
		[0.0,  Color(0.94, 0.34, 0.06, 0.55)],   # 상단 진한 주황
		[0.42, Color(1.0,  0.74, 0.18, 0.34)],   # 노랑
		[0.72, Color(1.0,  0.55, 0.42, 0.24)],   # 살구
		[1.0,  Color(0.97, 0.42, 0.66, 0.16)],   # 하단 분홍
	])
	_draw_soft_sun(Vector2(vp.x * 0.86, vp.y * 0.15), Color(1.0, 0.86, 0.5), 1.0)


## 밤 — 상단 꽤 진한 네이비 → 하단 옅은 하늘색(부드러운 세로 그라데이션, 변화폭 크게). 달 없음.
func _draw_night(vp: Vector2) -> void:
	_draw_vgradient(vp, [
		[0.0,  Color(0.04, 0.05, 0.22, 0.62)],   # 최상단 진한 네이비
		[0.45, Color(0.12, 0.22, 0.46, 0.42)],   # 청록빛 남색
		[1.0,  Color(0.55, 0.74, 0.92, 0.20)],   # 하단 옅은 하늘색
	])


## 세로 그라데이션 — stops=[[pos0..1, Color(알파포함)], ...]. 인접 쿼드가 색을 공유 → 가로 줄(이음새) 없음.
func _draw_vgradient(vp: Vector2, stops: Array) -> void:
	for i in range(stops.size() - 1):
		var p0: float = float(stops[i][0]);     var c0: Color = stops[i][1]
		var p1: float = float(stops[i + 1][0]); var c1: Color = stops[i + 1][1]
		var y0: float = vp.y * p0
		var y1: float = vp.y * p1
		var pts := PackedVector2Array([Vector2(0, y0), Vector2(vp.x, y0), Vector2(vp.x, y1), Vector2(0, y1)])
		var cols := PackedColorArray([c0, c0, c1, c1])
		draw_polygon(pts, cols)


## 부드럽게 번진 태양(겹친 원들). 쾌청/노을 공통.
func _draw_soft_sun(sun: Vector2, tint: Color, a: float) -> void:
	for k in range(20):
		var rr0: float = 210.0 - k * 9.0
		draw_circle(sun, rr0, Color(tint.r, tint.g, tint.b, 0.016 * a))
	for k in range(14):
		var rr1: float = 56.0 - k * 3.4
		draw_circle(sun, rr1, Color(tint.r, min(1.0, tint.g + 0.08), min(1.0, tint.b + 0.12), 0.05 * a))


func _a(base: Color, alpha: float) -> Color:
	return Color(base.r, base.g, base.b, base.a * alpha)
