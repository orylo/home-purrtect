extends Node2D
## 날씨 — 3개 하위 레이어로 분리해 근경(z50) 기준 위/아래를 나눈다.
##   · 알갱이/햇빛(비·눈·낙엽·먼지·태양·플레어) = z49 (근경 아래)
##   · 색감 틴트(노을·밤·쾌청 워밍) = z51 (근경 위, 화면 전체 덮음)
##   · 빛(반딧불·번개 섬광) = z52 (색감 위)
##   상태·물리는 부모가 소유, 그리기만 자식 캔버스에 위임 → "밤에 비오다 그치고 아침" 같은 조합 연출 가능.
##   입자는 바닥선(Layout.ground_y)에서 착지(±50px). 헤드리스에선 안 보이고 F5/웹에서만.

const WEATHER := {
	"1-1": "rain",       # 비
	"1-2": "snow",       # 눈
	"1-3": "sunny",      # 쾌청(블러 햇살 + 렌즈 플레어)
	"1-4": "sunset",     # 노을(주황→노랑→분홍 틴트)
	"1-5": "night",      # 밤(네이비→하늘색 틴트)
	"1-6": "leaves",     # 낙엽
	"1-7": "motes",      # 먼지(갈색/회색 알갱이)
	"1-8": "fireflies",  # 반딧불
	"1-9": "lightning",  # 번개(불규칙 천둥→섬광+비)
	"1-11": "transition",# 밤+비 → 여명 → 아침 전환
}

const RAIN_COL := Color(0.72, 0.80, 0.95, 0.55)
const SNOW_COL := Color(1.0, 1.0, 1.0, 0.92)
const LEAF_INK := Color(0.34, 0.19, 0.08)   # 낙엽 잎맥·외곽 갈색
const LAND := 50.0   # 착지 ground_y ± 이 값 랜덤
## 하위 레이어 z (근경=50 기준)
const Z_PARTICLES := 49   # 근경 아래(비·눈·낙엽·먼지·햇빛 알갱이)
const Z_TINT := 51        # 근경 위(화면 전체 색감)
const Z_LIGHT := 52       # 색감 위(반딧불·번개 빛)
## 세로 그라데이션 스톱(틴트) — [pos0..1, Color(알파포함)]
const _SUNSET := [[0.0, Color(0.94, 0.34, 0.06, 0.55)], [0.42, Color(1.0, 0.74, 0.18, 0.34)], [0.72, Color(1.0, 0.55, 0.42, 0.24)], [1.0, Color(0.97, 0.42, 0.66, 0.16)]]
const _NIGHT := [[0.0, Color(0.04, 0.05, 0.22, 0.62)], [0.45, Color(0.12, 0.22, 0.46, 0.42)], [1.0, Color(0.55, 0.74, 0.92, 0.20)]]
const _DAWN := [[0.0, Color(0.22, 0.16, 0.34, 0.55)], [0.5, Color(0.95, 0.48, 0.30, 0.40)], [1.0, Color(1.0, 0.72, 0.58, 0.22)]]
const _MORNING := [[0.0, Color(0.55, 0.74, 0.95, 0.20)], [1.0, Color(1.0, 0.93, 0.72, 0.12)]]


## 하위 레이어 — 자식 캔버스. 자기 _draw 때 부모(w)의 paint를 호출(자기 자신에 그림).
class WLayer extends Node2D:
	var w
	var kind := ""
	func _draw() -> void:
		if w != null:
			w.paint(self, kind)


var _mode := "none"
var _p: Array = []
var _splash: Array = []
var _t := 0.0
var _flash := 0.0
var _flash_next := 3.0
var _flash2 := 0.0      # 잔섬광 대기
var _flash_delay := 0.0 # 천둥 소리 후 섬광까지 대기(소리 먼저)
var _trans := 0.0       # 전환 진행(0=밤+비 → 1=아침)
var _layers: Array = [] # [WLayer ...]
var _glow: GradientTexture2D    # 라디얼 그라데이션(부드러운 글로우/고스트용, 중심부터 falloff)
var _sun: GradientTexture2D     # 태양 코어용 — 중심에 불투명 평지대(스킬슬롯 크기) → 블러 falloff


func _ready() -> void:
	_mode = WEATHER.get("%d-%d" % [GameState.stage_major, GameState.stage_minor], "none")
	if _mode == "none":
		set_process(false)
		return
	_glow = _make_glow()
	_sun = _make_sun()
	for spec in [["particles", Z_PARTICLES], ["tint", Z_TINT], ["light", Z_LIGHT]]:
		var n := WLayer.new()
		n.w = self
		n.kind = spec[0]
		n.z_as_relative = false
		n.z_index = spec[1]
		add_child(n)
		_layers.append(n)
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()
	_flash_next = randf_range(1.5, 5.0)


func _is_particle(m: String) -> bool:
	return m in ["rain", "snow", "leaves", "motes", "fireflies", "lightning", "transition"]


func _rebuild() -> void:
	_p.clear()
	_splash.clear()
	if _is_particle(_mode):
		var vp := get_viewport().get_visible_rect().size
		var counts := {"rain": 140, "snow": 100, "leaves": 46, "motes": 70, "fireflies": 36, "lightning": 90, "transition": 140}
		for i in int(counts.get(_mode, 0)):
			_p.append(_make(vp, true))
	_redraw_all()


func _redraw_all() -> void:
	for n in _layers:
		n.queue_redraw()


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
			var brown := [Color(0.55, 0.40, 0.26), Color(0.62, 0.48, 0.30), Color(0.48, 0.34, 0.20)]
			var gray := [Color(0.52, 0.52, 0.54), Color(0.45, 0.46, 0.48), Color(0.60, 0.60, 0.62)]
			var pool: Array = brown if randf() < 0.55 else gray
			return {"k": "mote", "x": randf() * vp.x, "y": randf() * vp.y,
				"vx": randf_range(-20.0, 20.0), "vy": randf_range(-16.0, 16.0),
				"r": randf_range(3.0, 5.2), "ph": randf() * TAU, "col": pool[randi() % pool.size()]}
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
	# 번개: 불규칙 간격 — 천둥 소리 먼저, 섬광은 _flash_delay 뒤
	if _mode == "lightning":
		_flash = maxf(0.0, _flash - delta * 5.5)
		if _flash2 > 0.0:
			_flash2 -= delta
			if _flash2 <= 0.0:
				_flash = maxf(_flash, 0.65)
		if _flash_delay > 0.0:
			_flash_delay -= delta
			if _flash_delay <= 0.0:
				_flash = 1.0
				_flash2 = randf_range(0.07, 0.18) if randf() < 0.4 else 0.0
		_flash_next -= delta
		if _flash_next <= 0.0:
			Sfx.play("thunder", randf_range(0.9, 1.1), -1.0)  # 소리 먼저
			_flash_delay = randf_range(0.3, 0.7)              # 빛은 잠시 뒤
			_flash_next = randf_range(1.4, 7.5)
	if _mode == "transition":
		_trans = minf(1.0, _trans + delta / 12.0)
	_redraw_all()


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


# ── 하위 레이어별 그리기(자식 캔버스 ci에 그림) ───────────────────────
func paint(ci: CanvasItem, kind: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	var gy := Layout.ground_y()
	match kind:
		"particles": _paint_particles(ci, vp, gy)   # z49 근경 아래
		"tint":      _paint_tint(ci, vp)             # z51 근경 위
		"light":     _paint_light(ci, vp, gy)        # z52 색감 위


## 근경 아래 — 비/눈/낙엽/먼지 + 햇빛(태양·플레어). 반딧불·번개섬광은 제외.
func _paint_particles(ci: CanvasItem, vp: Vector2, gy: float) -> void:
	match _mode:
		"sunny":
			_draw_sun(ci, vp, 1.0)
		"sunset":
			_draw_warm_sun(ci, vp)  # 태양(또렷한 코어+블러)은 근경 아래 z49
		"transition":
			var rainA: float = 1.0 - smoothstep(0.2, 0.5, _trans)   # 비 먼저 그침
			var sunA: float = smoothstep(0.55, 1.0, _trans)         # 해는 아침에 떠오름
			_draw_ground_particles(ci, gy, rainA)
			if sunA > 0.0: _draw_sun(ci, vp, sunA)
		_:
			_draw_ground_particles(ci, gy, 1.0)


## 근경 위 — 화면 전체 색감(노을·밤 그라데이션, 쾌청 워밍 틴트, 반딧불=밤 색감).
func _paint_tint(ci: CanvasItem, vp: Vector2) -> void:
	match _mode:
		"sunny":
			ci.draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, 0.06))
		"sunset":
			_draw_vgradient(ci, vp, _SUNSET)
		"night":
			_draw_vgradient(ci, vp, _NIGHT)
		"fireflies":
			_draw_vgradient(ci, vp, _NIGHT)     # 반딧불은 밤 색감 위에서 반짝
		"transition":
			# 밤 → 여명 → 아침 크로스페이드
			var nightA: float = 1.0 - smoothstep(0.15, 0.5, _trans)
			var dawnA: float = clampf(1.0 - absf(_trans - 0.55) / 0.30, 0.0, 1.0)
			var mornA: float = smoothstep(0.6, 1.0, _trans)
			if nightA > 0.0: _draw_vgradient(ci, vp, _NIGHT, nightA)
			if dawnA > 0.0:  _draw_vgradient(ci, vp, _DAWN, dawnA)
			if mornA > 0.0:  _draw_vgradient(ci, vp, _MORNING, mornA)


## 색감 위 — 빛(반딧불, 번개 섬광).
func _paint_light(ci: CanvasItem, vp: Vector2, gy: float) -> void:
	match _mode:
		"fireflies":
			_draw_light_particles(ci, gy, 1.0)
		"lightning":
			if _flash > 0.0:
				ci.draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, _flash * 0.5), true)


## 지면 입자(비·눈·낙엽·먼지) + 빗방울 스플래시. (반딧불 제외)
func _draw_ground_particles(ci: CanvasItem, gy: float, gA: float) -> void:
	for d in _p:
		match d.k:
			"rain":
				var near: float = clampf((gy + float(d.land) - float(d.y)) / 40.0, 0.2, 1.0)
				var l: float = float(d.len) * near
				ci.draw_line(Vector2(d.x, d.y), Vector2(float(d.x) + 0.18 * l, float(d.y) - l), _a(RAIN_COL, gA), 2.0)
			"snow":
				var fade: float = clampf((gy + float(d.land) - float(d.y)) / 28.0, 0.0, 1.0)
				ci.draw_circle(Vector2(d.x, d.y), float(d.r), _a(SNOW_COL, (0.4 + 0.6 * fade) * gA))
			"leaf":
				var fade2: float = clampf((gy + float(d.land) - float(d.y)) / 30.0, 0.0, 1.0)
				_draw_leaf(ci, Vector2(d.x, d.y), float(d.r), float(d.rot), _a(d.col, (0.5 + 0.5 * fade2) * gA))
			"mote":
				var tw: float = 0.45 + 0.35 * sin(_t * 1.2 + float(d.ph))
				ci.draw_circle(Vector2(d.x, d.y), float(d.r) * 2.6, _a(d.col, 0.10 * tw * gA))
				ci.draw_circle(Vector2(d.x, d.y), float(d.r), _a(d.col, 0.85 * tw * gA))
	for s in _splash:
		var a: float = 1.0 - float(s.t) / 0.26
		var rad: float = 3.0 + float(s.t) * 60.0
		ci.draw_arc(Vector2(s.x, s.y), rad, PI, TAU, 10, _a(RAIN_COL, 0.5 * a * gA), 2.0)


## 빛 입자(반딧불).
func _draw_light_particles(ci: CanvasItem, _gy: float, gA: float) -> void:
	for d in _p:
		if d.k != "fly":
			continue
		var bl: float = 0.15 + 0.85 * pow(maxf(0.0, sin(_t * float(d.bs) + float(d.ph))), 2.0)
		var pos := Vector2(d.x, d.y)
		_soft_disc(ci, pos, float(d.r) * 5.0, Color(0.85, 1.0, 0.4), 0.16 * bl * gA)   # 큰 글로우(블러)
		_soft_disc(ci, pos, float(d.r) * 2.2, Color(1.0, 1.0, 0.6), 0.85 * bl * gA)    # 밝은 심(블러, 외곽선 없음)


## 잎 — 잎자루+주맥+측맥+톱니. 외곽·잎맥 모두 같은 갈색·같은 두께 스트로크.
func _draw_leaf(ci: CanvasItem, c: Vector2, r: float, rot: float, col: Color) -> void:
	var dir := Vector2(cos(rot), sin(rot))
	var perp := Vector2(-dir.y, dir.x)
	var steps := 16
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		pts.append(c + dir * lerp(-r, r, t) + perp * _leaf_w(t) * r)
	for i in range(steps + 1):
		var t2 := float(steps - i) / steps
		pts.append(c + dir * lerp(-r, r, t2) - perp * _leaf_w(t2) * r)
	ci.draw_colored_polygon(pts, col)
	var ink := Color(LEAF_INK.r, LEAF_INK.g, LEAF_INK.b, col.a)
	var lw: float = maxf(1.0, r * 0.08)            # 외곽·잎맥·잎자루·측맥 공통 두께
	for i in range(pts.size()):                    # 외곽: 잎맥과 똑같이 draw_line으로(렌더 차이 제거)
		ci.draw_line(pts[i], pts[(i + 1) % pts.size()], ink, lw)
	ci.draw_line(c - dir * r, c - dir * r * 1.4, ink, lw)        # 잎자루
	ci.draw_line(c - dir * r * 0.92, c + dir * r * 0.92, ink, lw)  # 주맥
	for sv in [-0.45, -0.1, 0.28]:                  # 측맥 3쌍
		var s: float = float(sv)
		var bse: Vector2 = c + dir * (r * s)
		var tip: Vector2 = dir * r * 0.34
		var hw: float = _leaf_w((s + 1.0) * 0.5) * r * 0.75
		ci.draw_line(bse, bse + tip + perp * hw, ink, lw)
		ci.draw_line(bse, bse + tip - perp * hw, ink, lw)


func _leaf_w(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var body: float = pow(sin(t * PI), 0.7)
	body *= (0.72 + 0.28 * (1.0 - t))
	var teeth: float = 1.0 + 0.09 * sin(t * PI * 9.0)
	return body * 0.52 * teeth


## 쾌청 태양 — 강하게 번진 후광 + 퓨어화이트 불투명 코어 + 화면 중~하단 렌즈 플레어.
func _draw_sun(ci: CanvasItem, vp: Vector2, a: float) -> void:
	var sun := Vector2(vp.x * 0.86, vp.y * 0.15)
	var px := 0.0
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl is Node2D:
		px = clampf((pl as Node2D).global_position.x / maxf(vp.x, 1.0), 0.0, 1.0) - 0.5
	# 플레어 축: 태양(우상단) → 화면을 가로질러 좌하단으로
	var center := Vector2(vp.x * 0.44 + px * 70.0, vp.y * 0.66)
	_soft_disc(ci, sun, vp.x * 0.40, Color(1, 1, 1), 0.14 * a)            # 거대 후광(블러)
	var rtot: float = Layout.SKILL_BTN_R / 0.30                          # 스킬슬롯(38px) 솔리드 코어 → 블러
	_soft_disc(ci, sun, rtot, Color(1, 1, 1), a, _sun)                   # 코어: 중심 불투명 화이트 + 가장자리 블러
	for i in range(12):                                                  # 스타버스트 광선
		var ang := TAU * float(i) / 12.0 + 0.05 * sin(_t * 0.3)
		var Ln: float = (vp.x * 0.55 if i % 3 == 0 else vp.x * 0.24) * (0.9 + 0.1 * sin(_t * 0.7 + i))
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x) * 5.0
		ci.draw_colored_polygon(PackedVector2Array([sun + perp, sun - perp, sun + dir * Ln]), Color(1, 1, 1, 0.08 * a))
	_draw_flare(ci, sun, center - sun, a)                                # 렌즈 플레어 고스트 체인


## 렌즈 플레어 고스트 — 태양→반대편 축을 따라 컬러풀한 원/링이 줄지어. (첨부 레퍼런스 톤)
func _draw_flare(ci: CanvasItem, sun: Vector2, v: Vector2, a: float) -> void:
	var gpos := [0.30, 0.45, 0.60, 0.74, 0.86, 1.00, 1.16, 1.34, 1.55, 1.80]   # 축 위 위치(0=태양,1=중심)
	var grad := [30.0, 16.0, 46.0, 12.0,  9.0, 34.0, 64.0, 20.0, 30.0, 80.0]   # 반경
	var galp := [0.45, 0.55, 0.34, 0.60, 0.75, 0.40, 0.26, 0.50, 0.45, 0.22]   # 알파
	var gring := [false, false, true, false, false, true, true, false, false, true]  # 빈 링 여부
	var gcol := [
		Color(1.0, 0.84, 0.30), Color(0.55, 1.0, 0.40), Color(0.40, 0.92, 0.55), Color(1.0, 1.0, 0.85),
		Color(1.0, 0.34, 0.34), Color(0.45, 0.80, 1.0), Color(0.40, 0.65, 1.0), Color(0.75, 0.45, 1.0),
		Color(1.0, 0.55, 0.85), Color(0.55, 0.45, 0.95),
	]
	for i in range(gpos.size()):
		var pos: Vector2 = sun + v * float(gpos[i])
		var rad: float = float(grad[i])
		var col: Color = gcol[i]
		var al: float = float(galp[i]) * a
		if gring[i]:
			_soft_disc(ci, pos, rad, col, al * 0.35)                                 # 옅은 채움
			ci.draw_arc(pos, rad, 0.0, TAU, 56, Color(col.r, col.g, col.b, al), 3.0, true)  # 컬러 링
		else:
			_soft_disc(ci, pos, rad, col, al)


## 노을 태양 — 따뜻한 화이트 솔리드 코어(스킬슬롯 크기) + 블러 후광. z49(근경 아래).
func _draw_warm_sun(ci: CanvasItem, vp: Vector2) -> void:
	var sun := Vector2(vp.x * 0.86, vp.y * 0.15)
	_soft_disc(ci, sun, 240.0, Color(1.0, 0.82, 0.5), 0.18)              # 따뜻한 후광
	var rtot: float = Layout.SKILL_BTN_R / 0.30
	_soft_disc(ci, sun, rtot, Color(1.0, 0.95, 0.8), 0.95, _sun)         # 또렷한 코어 + 블러 가장자리


## 가우시안풍 원반 — 알파가 매끄럽게 0이 되는 라디얼 텍스처(진짜 블러). 딱딱한 외곽 없음. tex 생략 시 _glow.
func _soft_disc(ci: CanvasItem, c: Vector2, rmax: float, rgb: Color, peak: float, tex: Texture2D = null) -> void:
	var t: Texture2D = tex if tex != null else _glow
	if t == null:
		return
	var sz: float = rmax * 2.0
	ci.draw_texture_rect(t, Rect2(c - Vector2(rmax, rmax), Vector2(sz, sz)), false, Color(rgb.r, rgb.g, rgb.b, peak))


## 글로우 텍스처 — 중심 알파1 → 가장자리 알파0(가우시안풍 falloff, 평지대 없음).
func _make_glow() -> GradientTexture2D:
	return _radial([0.0, 0.25, 0.55, 1.0], [1.0, 0.55, 0.16, 0.0])


## 태양 코어 텍스처 — 중심부 알파1 평지대(0~0.30) 유지 후 0으로 falloff = 솔리드 코어 + 블러 가장자리.
func _make_sun() -> GradientTexture2D:
	return _radial([0.0, 0.30, 0.62, 1.0], [1.0, 1.0, 0.30, 0.0])


func _radial(offsets: Array, alphas: Array) -> GradientTexture2D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in offsets.size():
		offs.append(float(offsets[i]))
		cols.append(Color(1, 1, 1, float(alphas[i])))
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## 세로 그라데이션 — 인접 쿼드가 색 공유 → 가로 줄(이음새) 없음. mul=전체 알파 배율(전환 페이드용).
func _draw_vgradient(ci: CanvasItem, vp: Vector2, stops: Array, mul: float = 1.0) -> void:
	for i in range(stops.size() - 1):
		var p0: float = float(stops[i][0]);     var s0: Color = stops[i][1]
		var p1: float = float(stops[i + 1][0]); var s1: Color = stops[i + 1][1]
		var c0 := Color(s0.r, s0.g, s0.b, s0.a * mul)
		var c1 := Color(s1.r, s1.g, s1.b, s1.a * mul)
		var y0: float = vp.y * p0
		var y1: float = vp.y * p1
		var pts := PackedVector2Array([Vector2(0, y0), Vector2(vp.x, y0), Vector2(vp.x, y1), Vector2(0, y1)])
		var cols := PackedColorArray([c0, c0, c1, c1])
		ci.draw_polygon(pts, cols)


func _a(base: Color, alpha: float) -> Color:
	return Color(base.r, base.g, base.b, base.a * alpha)
