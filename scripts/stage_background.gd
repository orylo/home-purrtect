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
@export var near_texture: Texture2D
## 바닥선 정렬 확인용 디버그 선(빨강). 그림의 땅과 맞으면 끄면 됨.
@export var show_ground_line: bool = true
## 배경 추가 확대 배율(1.0 = 기본, 비율 유지 커버). 필요 시만 키움.
@export var bg_zoom: float = 1.0
## 배경을 아래로 내리는 양(px). 양수면 그림이 내려가 위쪽이 더 보인다.
@export var offset_y: float = 0.0
## 원경 안개(공기원근) — far 위에 부드러운 안개를 깔아 멀어 보이게 + 천천히 흐르게.
@export var fog_enabled: bool = true

const FOG_COL := Color(0.88, 0.92, 0.97)   # 안개 색(옅은 차가운 흰색)
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
## 새 배경은 폴더에 넣고 아래 배열에 경로만 추가하면 됨.
const THEMES := {
	"wall": {
		"far": [
			"res://assets/backgrounds/wall/far/far01.jpg", "res://assets/backgrounds/wall/far/far02.jpg",
			"res://assets/backgrounds/wall/far/far03.jpg", "res://assets/backgrounds/wall/far/far04.jpg",
			"res://assets/backgrounds/wall/far/far05.jpg", "res://assets/backgrounds/wall/far/far06.jpg",
			"res://assets/backgrounds/wall/far/far07.jpg", "res://assets/backgrounds/wall/far/far08.jpg",
			"res://assets/backgrounds/wall/far/far09.jpg", "res://assets/backgrounds/wall/far/far10.jpg",
			"res://assets/backgrounds/wall/far/far11.jpg", "res://assets/backgrounds/wall/far/far12.jpg",
		],
		"ground": ["res://assets/backgrounds/wall/ground/ground01.png"],  # 추후 더 추가
		"near": [],   # 근경 — 추후 추가(있으면 캐릭터 앞에 그려짐)
	},
}
## 특정 스테이지 배경 고정(보스 등). 키="막-스테이지". 지정되면 랜덤 대신 이걸 사용.
const FIXED := {
	# 예) "1-10": {"theme": "wall", "far": "res://...far05.jpg", "ground": "res://...ground01.png", "near": ""},
}


func _ready() -> void:
	# 화면 크기가 바뀌면(회전·창 크기) 다시 그림
	get_viewport().size_changed.connect(queue_redraw)
	_fog_tex = _make_fog_tex()
	add_to_group("stage_bg")     # 근경(Foreground) 노드가 near_texture를 읽어감
	_pick_backgrounds()


## 현재 스테이지에 맞는 배경 3종을 정한다(에디터에서 직접 지정했으면 그대로 둠).
func _pick_backgrounds() -> void:
	var key := "%d-%d" % [GameState.stage_major, GameState.stage_minor]
	if FIXED.has(key):                       # 보스 등 고정
		var fx: Dictionary = FIXED[key]
		far_texture = _load_tex(fx.get("far", ""))
		ground_texture = _load_tex(fx.get("ground", ""))
		near_texture = _load_tex(fx.get("near", ""))
		return
	var th: Dictionary = THEMES.get(_theme_for(GameState.stage_major, GameState.stage_minor), {})
	# 에디터에서 미리 지정한 슬롯은 존중, 비어있으면 풀에서 랜덤
	if far_texture == null:
		far_texture = _pick_from(th.get("far", []))
	if ground_texture == null:
		ground_texture = _pick_from(th.get("ground", []))
	if near_texture == null:
		near_texture = _pick_from(th.get("near", []))


## 막·스테이지 → 테마. (1막 = 담벼락. 추후 막별 분기)
func _theme_for(_major: int, _minor: int) -> String:
	return "wall"


func _pick_from(pool: Array) -> Texture2D:
	if pool.is_empty():
		return null
	return _load_tex(String(pool[randi() % pool.size()]))


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
		_draw_anchored(ground_texture, vis, false) # ground = 하단 고정(움직임 X)
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
		var y: float = float(fb["y0"]) * vis.y + sin(_t * float(fb["bob_s"]) + float(fb["ph"])) * float(fb["bob_a"]) * vis.y
		var col := FOG_COL
		col.a = float(fb["a"])
		draw_texture_rect(_fog_tex, Rect2(Vector2(x - r, y - r), Vector2(r * 2.0, r * 2.0)), false, col)


## 가운데가 진하고 가장자리로 부드럽게 사라지는 원형 안개 텍스처(1회 생성).
func _make_fog_tex() -> ImageTexture:
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d: float = Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)            # smoothstep — 가장자리 더 부드럽게
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## 원경(far) — 가운데 정렬(고정). 카메라 고정 단일화면이라 패럴럭스는 안 씀.
const FAR_ZOOM := 1.0          # 원경 추가 확대(1.0 = 커버 스케일 그대로)
func _draw_far(tex: Texture2D, vis: Vector2) -> void:
	var t := tex.get_size()
	var sc := maxf(vis.x / t.x, vis.y / t.y) * bg_zoom * FAR_ZOOM
	var w := t.x * sc
	var h := t.y * sc
	draw_texture_rect(tex, Rect2(Vector2((vis.x - w) * 0.5, (vis.y - h) * 0.5), Vector2(w, h)), false)


## 좌우폭을 화면 폭에 딱 맞춰(가로 기준 스케일) 그리되, top_anchor면 상단·아니면 하단(바닥)에 붙임.
##   → 가로는 정확히 화면 폭, 세로는 비율 유지(넘치면 크롭).
func _draw_anchored(tex: Texture2D, vis: Vector2, top_anchor: bool) -> void:
	var t := tex.get_size()
	var sc := (vis.x / t.x) * bg_zoom        # 가로 기준 → 좌우폭이 화면에 딱 맞음
	var w := t.x * sc
	var h := t.y * sc
	var x := (vis.x - w) * 0.5
	var y := 0.0 if top_anchor else (vis.y - h)
	draw_texture_rect(tex, Rect2(Vector2(x, y), Vector2(w, h)), false)
