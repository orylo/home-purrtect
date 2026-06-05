extends Control
## 프롤로그 컷씬 — 입양과 운명의 교차 (브리프 §6-B + 세계관 기둥1 "빗속 상실")
##   탭/클릭/스페이스로 다음 장면. [건너뛰기]로 종료. 임시 비주얼(도형·빗줄기·기호) — 그림은 나중에 교체.
##   음악: 슬픔(prologue_sad) → 온기(prologue_warm). 자체 재생(Music 오토로드는 이 씬에서 무음).
##   끝나면 GameState.prologue_seen=true 저장 후 시작화면으로.

const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const SAD := preload("res://assets/music/prologue_sad.wav")
const WARM := preload("res://assets/music/prologue_warm.wav")

# 장면 데이터 (순서대로)
const BEATS := [
	{"bg": Color(0.10, 0.12, 0.18), "rain": 2.0, "music": "sad",
		"cap": "비 오는 거리, 종이박스 속 —\n어린 치즈는 혼자가 아니었다.", "vis": "two_cats"},
	{"bg": Color(0.06, 0.07, 0.11), "rain": 3.2, "music": "sad",
		"cap": "어느 거센 비 오는 밤,\n재난이 둘을 갈라놓았다…", "vis": "loss"},
	{"bg": Color(0.16, 0.16, 0.21), "rain": 1.6, "music": "warm",
		"cap": "검은 우산 하나가 다가와,\n젖은 길냥이에게 손을 내밀었다.", "vis": "umbrella"},
	{"bg": Color(0.34, 0.22, 0.13), "rain": 0.0, "music": "warm",
		"cap": "따뜻한 저택. 그때 벽 구멍에서\n쥐 한 마리와 눈이 마주쳤다 — 뻥!", "vis": "house", "fx": "light_bulb"},
	{"bg": Color(0.34, 0.22, 0.13), "rain": 0.0, "music": "warm",
		"speaker": "골드 영감", "line": "허허! 쥐를 잡는 솜씨가 제법이야.\n너, 마음에 든다.", "vis": "oldman"},
	{"bg": Color(0.34, 0.22, 0.13), "rain": 0.0, "music": "warm",
		"speaker": "골드 영감", "line": "세계일주를 다녀오마. 길게 걸릴 게야.\n이 집에 쥐새끼 한 마리라도 들이는 날엔 — 넌 그날로 길바닥이야.", "vis": "oldman"},
]

var _i := -1
var _bg := Color(0.10, 0.12, 0.18)
var _bg_target := Color(0.10, 0.12, 0.18)
var _rain_amt := 0.0
var _vis := ""
var _drops: Array = []                  # [{x,y,len,spd}]
var _music: AudioStreamPlayer
var _cur_music := ""

var _cap: Label
var _dlg: Control          # 공용 DialoguePanel 박스(인게임 이벤트 대화창과 동일)
var _dlg_name: Label
var _dlg_line: Label
var _hint: Label
var _typing := false       # 골드 대사 타이핑 중 여부(탭=즉시완성)
var _type_gen := 0         # 타이핑 세대(장면 전환 시 +1 → 이전 코루틴 중단)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 배경 클릭은 통과 → _unhandled_input이 받음(버튼은 별도로 받음)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -12.0
	add_child(_music)
	# 빗방울 풀
	var vp := get_viewport().get_visible_rect().size
	for i in 90:
		_drops.append({
			"x": randf() * (vp.x + 200.0) - 100.0,
			"y": randf() * vp.y,
			"len": randf_range(14.0, 30.0),
			"spd": randf_range(700.0, 1100.0),
		})
	_build_ui()
	_goto(0)
	set_process(true)


# 모두 앵커 기반(화면 크기 바뀌어도 자동 정렬). 배경 클릭은 통과시켜 _unhandled_input이 받게 함.
func _build_ui() -> void:
	# 자막(상단 가로 전체, 가운데 정렬)
	_cap = _mklabel(36, Color(0.97, 0.95, 0.90))
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_cap.offset_left = 60; _cap.offset_right = -60
	_cap.offset_top = 60; _cap.offset_bottom = 250
	_cap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_cap.add_theme_constant_override("outline_size", 8)
	add_child(_cap)
	# 영감 대화창 — 공용 DialoguePanel(인게임 이벤트 펑거스 대화창과 동일 프레임·스타일로 통일).
	#   골드 영감은 초상화 에셋이 없어 portrait 생략(본문 왼쪽부터). 진행 힌트는 기존 _hint 하나로 통일.
	var vp := get_viewport().get_visible_rect().size
	var dlg := DialoguePanel.build(self, vp)
	_dlg = dlg["box"]
	_dlg_name = dlg["name_lbl"]
	_dlg_line = dlg["text_lbl"]
	(dlg["hint_lbl"] as Label).visible = false
	_dlg.visible = false
	# 건너뛰기(우상단) — 누르면 전체 건너뜀(_finish). 버튼은 클릭을 받아야 하므로 mouse_filter 기본(STOP).
	var skip := Design.button("건너뛰기", "secondary", Design.FS_BODY)
	skip.custom_minimum_size = Vector2(150, 52)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -174; skip.offset_right = -24
	skip.offset_top = 24; skip.offset_bottom = 76
	skip.pressed.connect(_finish)
	add_child(skip)
	# 진행 힌트(우하단)
	_hint = _mklabel(22, Color(1, 1, 1, 0.75))
	_hint.text = "탭하여 계속 ▶"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -260; _hint.offset_right = -24
	_hint.offset_top = -52; _hint.offset_bottom = -12
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("outline_size", 5)
	add_child(_hint)


func _mklabel(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


func _goto(idx: int) -> void:
	_type_gen += 1          # 이전 타이핑 코루틴 무효화
	_typing = false
	if idx >= BEATS.size():
		_finish()
		return
	_i = idx
	var b: Dictionary = BEATS[idx]
	_bg_target = b.get("bg", _bg_target)
	_rain_amt = float(b.get("rain", 0.0))
	_vis = String(b.get("vis", ""))
	# 자막 / 대화창
	if b.has("cap"):
		_cap.text = String(b["cap"])
		_cap.visible = true
	else:
		_cap.visible = false
	if b.has("speaker"):
		_dlg_name.text = String(b["speaker"])
		_dlg.visible = true
		_type_gold(String(b.get("line", "")), _type_gen)   # 골드 목소리로 한 글자씩(비동기)
	else:
		_dlg.visible = false
	# 음악 큐
	_set_music(String(b.get("music", "")))
	# 만화 기호 이펙트
	if b.has("fx"):
		var vp := get_viewport().get_visible_rect().size
		Fx.burst(String(b["fx"]), Vector2(vp.x * 0.5 + 120, vp.y * 0.5 - 40), 0.7, 80)
	queue_redraw()


# 골드 영감 대사를 한 글자씩 + 골드 보이스 블립. gen 불일치/장면전환 시 즉시 중단.
func _type_gold(text: String, gen: int) -> void:
	_typing = true
	VoiceBlip.reset("gold")
	_dlg_line.text = text
	_dlg_line.visible_characters = 0
	var n := text.length()
	var dt := VoiceBlip.char_sec("gold")
	var k := 0
	while k < n and _typing and gen == _type_gen:
		_dlg_line.visible_characters = k + 1
		VoiceBlip.blip("gold", text[k], k, n)
		k += 1
		await get_tree().create_timer(dt).timeout
	if gen == _type_gen:
		_dlg_line.visible_characters = -1   # 전체 표시
		_typing = false


func _set_music(cue: String) -> void:
	if cue == "" or cue == _cur_music:
		return
	_cur_music = cue
	_music.stream = SAD if cue == "sad" else WARM
	_music.play()


func _process(delta: float) -> void:
	_bg = _bg.lerp(_bg_target, clampf(delta * 2.5, 0.0, 1.0))
	if _rain_amt > 0.0:
		var vp := get_viewport().get_visible_rect().size
		for d in _drops:
			d.y += d.spd * delta * (0.6 + _rain_amt * 0.2)
			d.x -= d.spd * delta * 0.18
			if d.y > vp.y + 30.0:
				d.y = -30.0
				d.x = randf() * (vp.x + 200.0) - 100.0
	queue_redraw()


# 배경(빈 곳) 탭/스페이스 = 다음 장면. 건너뛰기 버튼 클릭은 여기 안 옴(버튼이 먼저 소비 → _finish).
func _unhandled_input(event: InputEvent) -> void:
	var adv := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		adv = true
	elif event is InputEventScreenTouch and event.pressed:
		adv = true
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		adv = true
	if adv:
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false            # 타이핑 중 탭 = 즉시 전체표시(다음 X)
			_dlg_line.visible_characters = -1
		else:
			_goto(_i + 1)


func _finish() -> void:
	GameState.prologue_seen = true
	GameState.save_game()
	# 새 게임 진입(prologue_return="home")이면 홈으로, 다시보기면 시작화면으로.
	var dest := "res://scenes/home.tscn" if GameState.prologue_return == "home" else "res://scenes/start.tscn"
	GameState.prologue_return = "start"   # 소비 후 기본값 복귀(다음 다시보기 대비)
	get_tree().change_scene_to_file(dest)


# ───────── 임시 비주얼(도형) ─────────
func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), _bg, true)
	var gy := vp.y * 0.78   # 바닥선
	match _vis:
		"two_cats":
			_draw_box(Vector2(vp.x * 0.5, gy), 360.0)
			_draw_cat(Vector2(vp.x * 0.5 - 70, gy - 8), 1.0, Design.CHEESE)        # 치즈
			_draw_cat(Vector2(vp.x * 0.5 + 70, gy - 8), 0.95, Color(0.7, 0.7, 0.72)) # 닮은 친구
		"loss":
			_draw_cat(Vector2(vp.x * 0.42, gy - 8), 1.0, Design.CHEESE)            # 홀로 남은 치즈
			# 사라진 친구 = 흐릿한 잔상 + 물살 줄
			_draw_cat(Vector2(vp.x * 0.66, gy - 30), 0.9, Color(0.7, 0.7, 0.72, 0.18))
			for k in range(5):
				var yy := gy - 10 + k * 10
				draw_line(Vector2(vp.x * 0.56, yy), Vector2(vp.x * 0.80, yy - 6),
						Color(0.55, 0.6, 0.75, 0.5), 3.0)
		"umbrella":
			# 검은 우산(반원) + 손잡이 + 코트 실루엣 + 작은 치즈
			var uc := Vector2(vp.x * 0.56, gy - 250)
			draw_arc(uc, 150.0, PI, TAU, 32, Color(0.05, 0.05, 0.08), 0.0)
			draw_colored_polygon(_half_disk(uc, 150.0), Color(0.06, 0.06, 0.09))
			draw_line(uc, uc + Vector2(0, 250), Color(0.05, 0.05, 0.08), 6.0)
			draw_rect(Rect2(uc.x - 55, gy - 230, 110, 230), Color(0.08, 0.08, 0.11), true) # 코트
			_draw_cat(Vector2(vp.x * 0.40, gy - 8), 0.85, Design.CHEESE)
		"house":
			# 따뜻한 창문(빛) + 벽 구멍 + 쥐 + 치즈
			draw_rect(Rect2(vp.x * 0.62, gy - 320, 240, 200), Color(0.96, 0.82, 0.45, 0.85), true)
			draw_rect(Rect2(vp.x * 0.62, gy - 320, 240, 200), Color(0.25, 0.16, 0.09), false, 8.0)
			draw_circle(Vector2(vp.x * 0.30, gy - 6), 46.0, Color(0.03, 0.02, 0.02))   # 벽 구멍
			_draw_cat(Vector2(vp.x * 0.50, gy - 8), 1.0, Design.CHEESE)
			# 쥐(작은 회색 덩이 + 꼬리)
			draw_circle(Vector2(vp.x * 0.30, gy - 14), 22.0, Color(0.55, 0.5, 0.5))
			draw_line(Vector2(vp.x * 0.30 + 18, gy - 8), Vector2(vp.x * 0.30 + 60, gy + 2),
					Color(0.55, 0.5, 0.5), 4.0)
		"oldman":
			# 뒷모습 실루엣(코트 + 모자) — 얼굴 안 보임
			var cx := vp.x * 0.62
			draw_rect(Rect2(cx - 90, gy - 300, 180, 300), Color(0.10, 0.10, 0.13), true)  # 코트
			draw_circle(Vector2(cx, gy - 320), 56.0, Color(0.12, 0.12, 0.15))             # 머리
			draw_rect(Rect2(cx - 78, gy - 372, 156, 34), Color(0.08, 0.08, 0.10), true)   # 모자챙
			draw_rect(Rect2(cx - 46, gy - 410, 92, 44), Color(0.08, 0.08, 0.10), true)    # 모자
			_draw_cat(Vector2(vp.x * 0.32, gy - 8), 0.95, Design.CHEESE)
	# 비
	if _rain_amt > 0.0:
		var col := Color(0.7, 0.78, 0.95, clampf(0.12 + _rain_amt * 0.12, 0.1, 0.5))
		for d in _drops:
			draw_line(Vector2(d.x, d.y), Vector2(d.x - d.len * 0.3, d.y + d.len), col, 2.0)


func _draw_box(center: Vector2, w: float) -> void:
	var h := w * 0.42
	draw_rect(Rect2(center.x - w * 0.5, center.y - h, w, h), Color(0.30, 0.22, 0.14), true)
	draw_rect(Rect2(center.x - w * 0.5, center.y - h, w, h), Color(0.18, 0.12, 0.07), false, 5.0)


func _draw_cat(foot: Vector2, s: float, col: Color) -> void:
	# 발 기준, 위로 그림 (몸 타원 + 머리 원 + 귀 삼각 + 꼬리)
	var body := foot + Vector2(0, -42 * s)
	draw_circle(body, 40 * s, col)
	var head := foot + Vector2(0, -96 * s)
	draw_circle(head, 30 * s, col)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-26 * s, -10 * s), head + Vector2(-8 * s, -38 * s), head + Vector2(0, -14 * s)]), col)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(26 * s, -10 * s), head + Vector2(8 * s, -38 * s), head + Vector2(0, -14 * s)]), col)
	draw_line(body + Vector2(34 * s, 0), body + Vector2(64 * s, -28 * s), col, 7 * s)
	# 눈 두 점
	draw_circle(head + Vector2(-10 * s, -2 * s), 3.5 * s, Color(0.05, 0.04, 0.04))
	draw_circle(head + Vector2(10 * s, -2 * s), 3.5 * s, Color(0.05, 0.04, 0.04))


func _half_disk(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(17):
		var a := PI + PI * (float(k) / 16.0)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
