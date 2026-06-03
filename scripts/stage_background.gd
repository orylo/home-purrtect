extends Node2D
## 스테이지 배경 — 1920x1080 이미지를 "커버"로 채우고 바닥에 정렬해 그린다.
##
## · stage_texture 에 1920x1080 배경 그림을 넣으면 그걸 사용.
## · 비어 있으면 임시 배경(하늘 + 땅 + 바닥선)을 그려 동작을 확인할 수 있다.
## · 바닥 라인은 Layout.ground_y()와 항상 일치 → 캐릭터 발이 그림의 땅에 딱 맞음.

@export var stage_texture: Texture2D
## 3레이어 배경(테마 풀에서 _ready가 랜덤 선택해 채움): far=원경(가운데) / ground=지면(하단) / near=근경(캐릭터 앞, Foreground 노드가 그림).
##   에디터에서 직접 지정하면 그 값이 우선(보스 등 고정 연출용).
@export var far_texture: Texture2D
@export var ground_texture: Texture2D
var near_pieces: Array = []                  # 이번 판 근경 조각 [{corner,tex,phase,spd}] — Foreground가 그림
## 바닥선 정렬 확인용 디버그 선(빨강). 그림의 땅과 맞으면 끄면 됨.
@export var show_ground_line: bool = true
## 배경 추가 확대 배율(1.0 = 기본, 비율 유지 커버). 필요 시만 키움.
@export var bg_zoom: float = 1.0
## 배경을 아래로 내리는 양(px). 양수면 그림이 내려가 위쪽이 더 보인다.
@export var offset_y: float = 0.0
## 원경 안개(공기원근) — far 위에 부드러운 안개를 깔아 멀어 보이게 + 천천히 흐르게.
@export var fog_enabled: bool = true

const FAR_LIFT_MIN := 100.0                 # 원경(+안개) 올림 범위(px). 매 판 이 사이 랜덤.
const FAR_LIFT_MAX := 200.0
var _far_lift := 150.0                       # 이번 판 실제 올림값(_ready에서 랜덤). 지면·근경은 항상 바닥 고정.
const FOG_COL := Color(0.97, 0.98, 1.0)    # 안개 색(거의 흰색 — 빈티지 망점)
# 안개 덩어리 정의(상대값): x0=초기 가로위상, y0=세로위치(화면비), r=반지름(화면높이비),
#   spd=드리프트 속도(px/s), bob_s/bob_a=세로 일렁임 속도/폭, a=불투명도, ph=위상
const FOG_BLOBS := [
	{"x0": 0.10, "y0": 0.17, "r": 0.40, "spd": 5.0,  "bob_s": 0.25, "bob_a": 0.015, "a": 0.48, "ph": 0.0},
	{"x0": 0.55, "y0": 0.22, "r": 0.50, "spd": 3.5,  "bob_s": 0.18, "bob_a": 0.012, "a": 0.46, "ph": 1.7},
	{"x0": 0.85, "y0": 0.13, "r": 0.34, "spd": 8.0,  "bob_s": 0.34, "bob_a": 0.016, "a": 0.52, "ph": 3.1},
	{"x0": 0.30, "y0": 0.25, "r": 0.32, "spd": 11.0, "bob_s": 0.40, "bob_a": 0.020, "a": 0.48, "ph": 4.6},
	{"x0": 0.70, "y0": 0.19, "r": 0.44, "spd": 6.5,  "bob_s": 0.22, "bob_a": 0.013, "a": 0.44, "ph": 2.2},
]
var _t := 0.0
var _fog_tex: ImageTexture

# ── 스테이지 배경 풀(테마별) ─────────────────────────────────
## 같은 막=같은 테마. 한 판마다 far/ground/near를 풀에서 랜덤으로 뽑는다.
## 새 배경: 해당 폴더에 규칙대로 넣고 아래 장수만 늘리면 자동 포함.
##   far: wall/far/far01..NN.jpg / ground: wall/ground/g01..NN.png / near: wall/near/<tl|tr|bl|br>/<코너>01..NN.png
const POOL_COUNT := {
	"wall": {"far": 12, "ground": 21, "near": 7},
}
## 특정 스테이지 지면 고정(보스 등). 키="막-스테이지". 다른 스테이지도 여기 추가하면 고정.
const FIXED_GROUND := {
	"1-3":  "res://assets/backgrounds/wall/ground/fixed/1-3.png",
	"1-10": "res://assets/backgrounds/wall/ground/fixed/1-10.png",
	"1-20": "res://assets/backgrounds/wall/ground/fixed/1-20.png",
}
const NEAR_CORNERS := ["tl", "tr", "bl", "br"]
## 지면 정렬 — 이미지에서 '서는 면'의 세로 비율. 이 선을 항상 ground_y(기기마다 계산)에 맞춘다.
const SURF_FRAC := 0.70                      # 기본값(대부분 담장+길 구도에 맞음)
const GROUND_SURF := {                       # 예외 개별 보정: "파일명.png" → 비율
	# 예) "g14.png": 0.66,
}
var _ground_surf := SURF_FRAC


func _ready() -> void:
	# 화면 크기가 바뀌면(회전·창 크기) 다시 그림
	get_viewport().size_changed.connect(queue_redraw)
	_fog_tex = _make_fog_tex()
	_far_lift = randf_range(FAR_LIFT_MIN, FAR_LIFT_MAX)   # 매 판 원경 올림 랜덤
	add_to_group("stage_bg")     # 근경(Foreground) 노드가 near_pieces를 읽어감
	_pick_backgrounds()


## 현재 스테이지 배경(far/ground/near)을 정한다. 에디터에서 far/ground를 직접 지정했으면 그대로 둠.
func _pick_backgrounds() -> void:
	var theme := _theme_for(GameState.stage_major, GameState.stage_minor)
	var cnt: Dictionary = POOL_COUNT.get(theme, {})
	var key := "%d-%d" % [GameState.stage_major, GameState.stage_minor]
	# 원경 = 랜덤
	if far_texture == null:
		far_texture = _pick_seq("res://assets/backgrounds/%s/far/far%%02d.jpg" % theme, int(cnt.get("far", 0)))
	# 지면 = 고정 스테이지면 고정, 아니면 랜덤
	if ground_texture == null:
		if FIXED_GROUND.has(key):
			ground_texture = _load_tex(FIXED_GROUND[key])
		else:
			ground_texture = _pick_seq("res://assets/backgrounds/%s/ground/g%%02d.png" % theme, int(cnt.get("ground", 0)))
	# 지면 정렬 비율(이미지별 예외 보정 or 기본)
	if ground_texture != null:
		_ground_surf = float(GROUND_SURF.get(ground_texture.resource_path.get_file(), SURF_FRAC))
	# 근경 = 0~2개, 서로 다른 코너에서(한 코너 중복 금지)
	near_pieces = _pick_near(theme, int(cnt.get("near", 0)))


## 근경 0~2조각: 서로 다른 코너 랜덤 선택 → 각 코너 풀에서 랜덤 조각.
func _pick_near(theme: String, per_corner: int) -> Array:
	var count := randi() % 3                      # 0, 1, 2
	if count == 0 or per_corner <= 0:
		return []
	var corners := NEAR_CORNERS.duplicate()
	corners.shuffle()
	var pieces: Array = []
	for i in range(min(count, corners.size())):
		var corner: String = corners[i]
		var tex := _pick_seq("res://assets/backgrounds/%s/near/%s/%s%%02d.png" % [theme, corner, corner], per_corner)
		if tex != null:
			pieces.append({"corner": corner, "tex": tex, "phase": randf() * TAU, "spd": randf_range(0.6, 1.0)})
	return pieces


## 막·스테이지 → 테마. (1막 = 담벼락. 추후 막별 분기)
func _theme_for(_major: int, _minor: int) -> String:
	return "wall"


## "...%02d.png" 형식 경로의 1~count 중 랜덤 1장 로드.
func _pick_seq(fmt: String, count: int) -> Texture2D:
	if count <= 0:
		return null
	return _load_tex(fmt % (randi() % count + 1))


func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	var t = load(path)
	return t if t is Texture2D else null


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var vis := get_viewport().get_visible_rect().size
	var s := Layout.cover_scale()

	if far_texture != null and ground_texture != null:
		# 2레이어: 원경(가운데·고정) 뒤 → 전경 바닥(하단 고정·좌우폭 화면맞춤) 앞.
		_draw_far(far_texture, vis)               # far = 가운데 정렬(고정)
		if fog_enabled:
			_draw_fog(vis)                        # 안개(공기원근) — far 위, ground 아래
		_draw_ground(ground_texture, vis)         # ground = 지면선을 ground_y에 정렬
	elif stage_texture != null:
		# 그림 원본 비율 그대로 화면을 "커버"(꽉 채움) + 가로 가운데 + 바닥 고정.
		# 가로/세로 비율 중 더 큰 쪽으로 맞춰 빈틈 없이 채우고, 넘치는 부분만 크롭.
		var tex := stage_texture.get_size()
		var sc := maxf(vis.x / tex.x, vis.y / tex.y) * bg_zoom
		var art_w := tex.x * sc
		var art_h := tex.y * sc
		var art_x := (vis.x - art_w) * 0.5         # 가로 가운데
		var art_y := vis.y - art_h + offset_y      # 바닥 고정 + offset_y만큼 아래로
		draw_texture_rect(stage_texture, Rect2(Vector2(art_x, art_y), Vector2(art_w, art_h)), false)
	else:
		# 임시 배경: 하늘 + 땅 + 바닥선 (실제 그림이 들어오면 위 분기로 교체됨)
		var gy := Layout.ground_y()
		draw_rect(Rect2(0.0, 0.0, vis.x, vis.y), Color(0.12, 0.14, 0.2, 1))            # 하늘(전체)
		draw_rect(Rect2(0.0, gy, vis.x, vis.y - gy), Color(0.32, 0.28, 0.24, 1))        # 땅
		draw_line(Vector2(0.0, gy), Vector2(vis.x, gy), Color(0.55, 0.48, 0.4, 1), 2.0) # 바닥선

	# 디버그: 게임 바닥선을 빨간 선으로 표시(정렬 확인용)
	if show_ground_line:
		var line_y := Layout.ground_y()
		draw_line(Vector2(0.0, line_y), Vector2(vis.x, line_y), Color(1, 0, 0, 0.7), 3.0)


## 안개(공기원근) — far 위에 부드러운 안개 덩어리를 천천히 흘려 멀어 보이게/살아있게.
func _draw_fog(vis: Vector2) -> void:
	if _fog_tex == null:
		return
	for fb in FOG_BLOBS:
		var r: float = float(fb["r"]) * vis.y
		var span: float = vis.x + r * 2.0
		var x: float = fmod(float(fb["x0"]) * vis.x + _t * float(fb["spd"]), span)
		if x < 0.0:
			x += span
		x -= r                                    # 화면 밖에서 들어와 반대편으로 나감(끊김 없이 순환)
		var y: float = float(fb["y0"]) * vis.y + sin(_t * float(fb["bob_s"]) + float(fb["ph"])) * float(fb["bob_a"]) * vis.y - _far_lift
		var col := FOG_COL
		col.a = float(fb["a"])
		draw_texture_rect(_fog_tex, Rect2(Vector2(x - r, y - r), Vector2(r * 2.0, r * 2.0)), false, col)


## 빈티지 망점(halftone) 안개 텍스처 — 흰 점이 가운데 모이고 가장자리로 사라짐.
## 고해상도(512)라 블롭으로 확대해 그려도 점이 작고 촘촘하게 유지됨. 세션당 1회만 생성(static 캐시).
const FOG_TEX_N := 512     # 텍스처 해상도(클수록 점이 작고 촘촘)
const FOG_CELL := 5.0      # 망점 간격(px, 텍스처 기준)
const FOG_DOT := 1.9       # 망점 반지름(px, 텍스처 기준)
static var _shared_fog: ImageTexture
func _make_fog_tex() -> ImageTexture:
	if _shared_fog != null:
		return _shared_fog
	var n := FOG_TEX_N
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	var dot2 := FOG_DOT * FOG_DOT
	for y in n:
		for x in n:
			var ex := x - c
			var ey := y - c
			var d: float = sqrt(ex * ex + ey * ey) / c
			var radial: float = clampf(1.0 - d, 0.0, 1.0)
			radial = radial * radial * (3.0 - 2.0 * radial)   # 가장자리 부드럽게(smoothstep)
			# 망점: 격자 셀 중심에서 FOG_DOT 안이면 점(흰색), 밖이면 투명(sqrt 없이 제곱비교)
			var dx: float = fmod(float(x), FOG_CELL) - FOG_CELL * 0.5
			var dy: float = fmod(float(y), FOG_CELL) - FOG_CELL * 0.5
			var dot: float = 1.0 if (dx * dx + dy * dy) <= dot2 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, radial * dot))
	_shared_fog = ImageTexture.create_from_image(img)
	return _shared_fog


## 원경(far) — 가운데 정렬(고정). 카메라 고정 단일화면이라 패럴럭스는 안 씀.
const FAR_ZOOM := 1.0          # 원경 추가 확대(1.0 = 커버 스케일 그대로)
func _draw_far(tex: Texture2D, vis: Vector2) -> void:
	var t := tex.get_size()
	var sc := maxf(vis.x / t.x, vis.y / t.y) * bg_zoom * FAR_ZOOM
	var w := t.x * sc
	var h := t.y * sc
	draw_texture_rect(tex, Rect2(Vector2((vis.x - w) * 0.5, (vis.y - h) * 0.5 - _far_lift), Vector2(w, h)), false)


## 지면(ground) — 이미지의 '서는 면(_ground_surf)'을 ground_y(기기마다 계산)에 정렬해 그린다.
##   기본은 좌우폭=화면폭(가로맞춤). 단 지면선~화면바닥을 못 채우면 그만큼 키워(빈틈 방지) — 그땐 좌우가 살짝 넘쳐 크롭.
func _draw_ground(tex: Texture2D, vis: Vector2) -> void:
	var t := tex.get_size()
	var gy := Layout.ground_y()
	var sc_w := (vis.x / t.x) * bg_zoom                       # 가로맞춤
	var below := (1.0 - _ground_surf) * t.y                   # 서는 면 아래(길) 원본 높이
	var sc_fill := ((vis.y - gy) / below) if below > 1.0 else sc_w   # 지면선~바닥을 채울 최소 배율
	var sc := maxf(sc_w, sc_fill)
	var w := t.x * sc
	var h := t.y * sc
	var art_y := gy - _ground_surf * h                       # 서는 면을 바닥선에 정렬
	draw_texture_rect(tex, Rect2(Vector2((vis.x - w) * 0.5, art_y), Vector2(w, h)), false)
