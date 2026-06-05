extends Node2D
## 스테이지 이벤트(인게임 연출). 두 종류:
##   · 인트로: 웨이브 전, NPC가 화면 우측에서 "걸어서" 치즈와 대칭 위치까지 와서 대화(HUD 숨김).
##   · 팝업(튜토리얼/도발): 트리거(예: 첫 처치) 시 게임 일시정지 + 화면 Dim + 대화창.
##   대화 중에는 게임이 멈춰 조작이 실제로 막힌다(트리 paused). 본 노드/UI는 PROCESS_MODE_ALWAYS.
##   v1: 1-1에서 "회색쥐" 스프라이트를 펑거스 대역으로 사용.

const MFRAMES := preload("res://assets/sprites/enemies/mouse/mouse_frames.tres")
const FUNGUS := preload("res://assets/sprites/fungus/fungus_frames.tres")
const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")

# design.md 색 토큰
const INK := Color("241F1B")
const PAPER := Color("F3E3BE")
const PAPER_DEEP := Color("E4CB95")
const CHEESE := Color("F2B33D")
const CHEESE_DEEP := Color("D4912A")

const SPRITE_FOOT := 81.875   # enemy 기준: 발(원점)→스프라이트 중심 오프셋
const WALK_SPEED := 230.0     # NPC 걷는 속도(px/s) — 급하지 않게

## 스테이지별 이벤트 데이터
const EVENTS := {
	"1-1": {
		"name": "펑거스",
		"intro": [                                          # ① 전투 시작 전 (?→펑거스 정체 공개)
			{"text": "흐흐… 드디어 돌아왔다, 나의 안식처여……", "name": "?", "anim": "idle"},
			{"text": "…뭐야? 웬 고양이가 길을 막고 서 있지? 비켜라, 여긴 내 집이다!", "name": "?", "anim": "fear"},
			{"text": "너… 그때 날 걷어찬 그 고양이?! 이 펑거스, 그 발길질을 잊을 줄 알았더냐!", "anim": "angry"},
			{"text": "좋다, 오늘 집도 복수도 한꺼번에 되찾아주마. 가라, 나의 정예들이여—!", "anim": "angry"},
		],
		"first_kill": [                                     # ② 첫 몹 처치(1회) — 당황
			{"text": "뭐…?! 어떻게 싸울 줄 아는 거지?! 한낱 길바닥 출신인 주제에…!", "anim": "fear"},
		],
		"on_wave": {                                        # ③ 웨이브 시작 팝업 — 비웃음
			2: [{"text": "제법이군. 허나 이 몸은 위대한 책략가! 부대는 얼마든지 있다 — 가라, 제2진!", "anim": "laugh"}],
		},
		"outro": [                                          # ④ 전 웨이브 클리어 후 — 분노
			{"text": "이…이럴 수가! 오늘의 수치, 이 펑거스가 절대 잊지 않겠다!", "anim": "angry"},
			{"text": "이번이 마지막이라 생각 마라! 이 몸은 반드시 다시 돌아온다, 치즈으으—!", "anim": "angry"},
		],
	},
	"1-3": {
		"name": "펑거스",
		"intro": [                                          # ① 전투 시작 전(흐림+비) — 비웃음
			{"text": "또 만났군, 치즈. 허나 이 몸을 우습게 보지 마라!", "anim": "laugh"},
			{"text": "이 위대한 펑거스가… 새로운 비밀 병기를 준비했거든!", "anim": "laugh"},
			{"text": "멀찍이서 던져주마. 네놈이 손도 못 대게 말이야 — 가라, 나의 정예들이여!", "anim": "laugh"},
		],
		"on_wave": {
			2: [{"text": "후하하—! 등장이다, 나의 투척 부대! 멀리서 깔끔하게 처리해주마!", "anim": "laugh"}],   # ② 투척쥐 첫 등장
			3: [   # ③ 웨이브3 시작 + 비 그침→해, 당황
				{"text": "아닛—! 나의 비장의 카드, 투척쥐를 물리치다니…!", "anim": "fear"},
				{"text": "게다가 이 타이밍에 비는 왜 그치는 거야?! 그것도… 희망차게?!", "anim": "fear"},
			],
		},
		"outro": [                                          # ④ 전 웨이브 클리어 후
			{"text": "흥… 이번엔 제법 진땀 좀 뺐겠다, 치즈?", "anim": "laugh"},
			{"text": "두고 봐라! 다음엔 투척쥐를 잔뜩, 아주 잔뜩 데려올 테니까! 끄으윽—!", "anim": "angry"},
		],
		"reward": "보안관",                                  # ⑤ 클리어 후 보안관 획득
		"reward_text": "[전투 준비 > 직업]에서 장착·교체할 수 있어요.",
	},
	# 케이스 0 — 새 적 등장 스테이지 펑거스 약올리기(인트로만, 해금 없음)
	"1-5": {    # 박쥐 첫 등장(첫 공중 적). 펄 해금(케이스 A)은 클리어 후 인스씬(game.gd)으로 별개 — 시간상 분리 공존.
		"name": "펑거스",
		"intro": [
			{"text": "오늘은 하늘이다! 가라, 나의 박쥐 떼!", "anim": "laugh"},
			{"text": "땅바닥만 노려보던 네놈, 머리 위는 어쩔 테냐? 후하하!", "anim": "laugh"},
		],
	},
	"1-11": {   # 흑화(검은쥐)
		"name": "펑거스",
		"intro": [
			{"text": "치즈… 네놈한테 당한 그 수모, 곱씹고 또 곱씹었다.", "anim": "angry"},
			{"text": "회색 따위는 잊어라. 어둠에 절은 나의 정예 — 검은 부대다. 더 단단하고, 더 사납지.", "anim": "laugh"},
		],
	},
	"1-12": {   # 거미(둔화)
		"name": "펑거스",
		"intro": [
			{"text": "오늘은 특별한 손님을 모셨지 — 거미님 되시겠다.", "anim": "laugh"},
			{"text": "끈적한 거미줄에 발이 쩍 붙으면, 굼떠진 네놈을 실컷 두들겨주마!", "anim": "laugh"},
		],
	},
	"1-14": {   # 벌(독)
		"name": "펑거스",
		"intro": [
			{"text": "윙윙— 들리나? 이번엔 나의 벌 부대다.", "anim": "laugh"},
			{"text": "한 방만 쏘여도 독이 짜릿하게 퍼지지. 긁어도 소용없다고, 후하하!", "anim": "laugh"},
		],
	},
}

var _data: Dictionary = {}
var _spawner: Node = null
var _hud: CanvasLayer = null
var _npc: AnimatedSprite2D = null
var _face: TextureRect = null
var _ui: CanvasLayer = null

# UI 노드
var _tap: Button = null
var _name_lbl: Label = null
var _text_lbl: Label = null
var _hint_lbl: Label = null
var _choices: HBoxContainer = null

var _advance := false
var _choice := -1
var _busy := false           # 대화 진행 중(중복 트리거 방지)
var _first_kill_done := false
# NPC 도보
var _walking := false
var _walk_target := 0.0
var _walk_speed := WALK_SPEED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 일시정지 중에도 동작
	var key := "%d-%d" % [GameState.stage_major, GameState.stage_minor]
	if GameState.sandbox or not EVENTS.has(key):
		queue_free()
		return
	_data = EVENTS[key]
	_spawner = get_parent().get_node_or_null("Spawner")
	_hud = get_parent().get_node_or_null("HUD")
	if _data.has("first_kill"):
		GameState.enemy_killed.connect(_on_enemy_killed)
	if _data.has("on_wave") and _spawner != null and _spawner.has_signal("wave_started"):
		_spawner.wave_started.connect(_on_wave_popup)
	if _data.has("intro"):
		_run_intro()


func _process(delta: float) -> void:
	if _walking and is_instance_valid(_npc):
		var dir := signf(_walk_target - _npc.position.x)
		_npc.flip_h = dir > 0.0                       # 오른쪽으로 가면 오른쪽 바라봄
		_npc.position.x += dir * _walk_speed * delta
		if absf(_npc.position.x - _walk_target) <= _walk_speed * delta:
			_npc.position.x = _walk_target
			_walking = false


# ── 인트로(웨이브 전, NPC 도보 등장) ─────────────────────
func _run_intro() -> void:
	_busy = true
	await get_tree().process_frame                    # 플레이어/뷰포트 준비
	if _spawner != null and _spawner.has_method("hold_intro"):
		_spawner.hold_intro()
	if _hud != null:
		_hud.visible = false
	get_tree().paused = true                           # 조작 실제 차단
	_set_cat_idle(true)
	_set_bg_alive(true)                                # 배경(비·드리프트)은 계속
	var vp := get_viewport().get_visible_rect().size
	var cat_x := 200.0
	var pl := get_parent().get_node_or_null("Player")
	if pl != null and pl is Node2D:
		cat_x = (pl as Node2D).global_position.x
	var target_x: float = vp.x - cat_x                 # 치즈와 대칭(우측에서 같은 거리)
	_spawn_npc(vp.x + 160.0)                            # 화면 우측 밖에서 등장
	await _walk_to(target_x)                            # 걸어 들어옴
	_build_ui(0.0)                                      # 인트로는 Dim 없음
	await _play_beats(_data["intro"])
	_close_ui()
	await _walk_to(vp.x + 200.0, "run", WALK_SPEED * 2.2)   # 우측으로 달려 퇴장
	if is_instance_valid(_npc):
		_npc.queue_free()
	if _hud != null:
		_hud.visible = true
	if _spawner != null and _spawner.has_method("release_intro"):
		_spawner.release_intro()                        # 웨이브 시작
	_set_cat_idle(false)
	_set_bg_alive(false)
	get_tree().paused = false
	_busy = false


# ── 팝업(일시정지 + Dim + 대화) ─────────────────────────
func _on_enemy_killed() -> void:
	if _first_kill_done or _busy or not _data.has("first_kill"):
		return
	_first_kill_done = true
	await _run_popup(_data["first_kill"])


func _run_popup(beats: Array) -> void:
	_busy = true
	if _hud != null:
		_hud.visible = false
	get_tree().paused = true
	_set_cat_idle(true)
	_set_bg_alive(true)
	_build_ui(0.55)                                    # 화면 Dim
	await _play_beats(beats)
	_close_ui()
	if _hud != null:
		_hud.visible = true
	_set_cat_idle(false)
	_set_bg_alive(false)
	get_tree().paused = false
	_busy = false


## ③ 웨이브 시작 팝업(on_wave[N]) — current는 1부터.
func _on_wave_popup(current: int, _total: int) -> void:
	if _busy:
		return
	var ow: Dictionary = _data.get("on_wave", {})
	if ow.has(current):
		await _run_popup(ow[current])


# ── ④ 클리어 후 퇴장(+⑤ 보상) — game.gd가 클리어 패널 직전에 await ─────
func has_outro() -> bool:
	return _data.has("outro")


func play_outro() -> void:
	if not _data.has("outro"):
		return
	_busy = true
	if _hud != null:
		_hud.visible = false
	get_tree().paused = true
	_set_cat_idle(true)
	_set_bg_alive(true)
	var vp := get_viewport().get_visible_rect().size
	# ── #4·#5: 인트로처럼 화면 우측 가까이 등장하되, 치즈를 통과/추월하지 않는다.
	#   치즈는 펑거스 왼쪽에 서고(겹침 금지), 치즈가 너무 우측이면 왼쪽으로 밀어 자리 확보.
	var gap := 240.0                                   # 펑거스↔치즈 대화 간격
	var npc_max := vp.x - 140.0                         # 펑거스가 화면 안에 보이는 우측 한계
	var near_right := vp.x - 200.0                      # 인트로 standing(우측 가까이) 재현
	var pl := get_parent().get_node_or_null("Player")
	var cat_x := 200.0
	if pl != null and pl is Node2D:
		cat_x = (pl as Node2D).global_position.x
	var npc_target: float = clampf(maxf(near_right, cat_x + gap), 0.0, npc_max)
	var cat_target: float = npc_target - gap
	_spawn_npc(vp.x + 160.0)                            # 우측 밖에서 등장
	# 치즈가 펑거스 자리를 침범(너무 우측)하면 왼쪽으로 밀어 비켜줌(펑거스 도보와 동시 진행)
	if pl != null and cat_x > cat_target + 6.0 and pl.has_method("event_walk_to"):
		pl.event_walk_to(cat_target)
	await _walk_to(npc_target)                          # 펑거스 우측 가까이 정지
	while pl != null and pl.has_method("is_event_walking") and pl.is_event_walking():
		await get_tree().process_frame                 # 치즈 밀기 완료까지 대기
	_build_ui(0.0)
	await _play_beats(_data["outro"])
	_close_ui()
	await _walk_to(vp.x + 220.0, "run", WALK_SPEED * 2.2)   # 분해서 달려 퇴장
	if is_instance_valid(_npc):
		_npc.queue_free()
	# (⑤ 보상 획득은 전투결과 팝업 [확인] 후 game.gd의 궤짝 컷씬에서 처리)
	if _hud != null:
		_hud.visible = true
	_set_cat_idle(false)
	_set_bg_alive(false)
	get_tree().paused = false
	_busy = false


## 이벤트 동안 치즈를 제자리 idle 사이클로(트리 일시정지에도 동작). 끝나면 복귀.
func _set_cat_idle(on: bool) -> void:
	var pl := get_parent().get_node_or_null("Player")
	if pl != null and pl.has_method("set_event_idle"):
		pl.set_event_idle(on)


## 이벤트(트리 일시정지) 동안에도 배경 움직임(비·원경 드리프트·바람)은 계속 흐르게.
##   BG(CanvasLayer)·Weather·Foreground를 ALWAYS로, 끝나면 INHERIT 복귀.
func _set_bg_alive(on: bool) -> void:
	var mode := Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
	var par := get_parent()
	for nm in ["BG", "Weather", "Foreground"]:
		var n := par.get_node_or_null(nm)
		if n != null:
			n.process_mode = mode


# ── NPC ────────────────────────────────────────────────
func _spawn_npc(start_x: float) -> void:
	_npc = AnimatedSprite2D.new()
	_npc.sprite_frames = FUNGUS                        # 펑거스 실제 스프라이트
	var fh: float = float(FUNGUS.get_frame_texture("walk", 0).get_height())
	var sc: float = 280.0 / maxf(fh, 1.0)              # 화면 표시 높이 ~280px
	_npc.scale = Vector2(sc, sc)
	_npc.position = Vector2(start_x, Layout.ground_y() - fh * sc * 0.5)   # 발이 바닥선
	add_child(_npc)
	_npc.play("walk")


## anim: 이동 애니("walk"/"run"), speed: 이동 속도. 멈추면 idle.
func _walk_to(tx: float, anim: String = "walk", speed: float = WALK_SPEED) -> void:
	_walk_target = tx
	_walk_speed = speed
	_walking = true
	if is_instance_valid(_npc):
		_npc.play(anim)
	while _walking:
		await get_tree().process_frame
	if is_instance_valid(_npc):
		_npc.play("idle")                              # 멈춰서 말하기(idle)


# ── 대화 UI(코드 생성) ──────────────────────────────────
func _sb(bg: Color, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(4)
	s.border_color = INK
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s


func _build_ui(dim_alpha: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	_ui = CanvasLayer.new()
	_ui.layer = 60                                     # HUD보다 위
	add_child(_ui)
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	# Dim(맨 아래, 입력은 통과)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dim)

	# 전체화면 탭 = 다음(선택지 없을 때). 박스/라벨은 통과시켜 어디를 탭해도 넘어가게.
	_tap = Button.new()
	_tap.flat = true
	_tap.focus_mode = Control.FOCUS_NONE
	_tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tap.pressed.connect(func() -> void: _advance = true)
	_ui.add_child(_tap)

	var box_h := 236.0
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", _sb(PAPER, 12))
	box.position = Vector2(24, vp.y - box_h - 24)
	box.size = Vector2(vp.x - 48, box_h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(box)

	# 얼굴(초상화) — 박스 안에 클립
	var port_sz := box_h - 32.0
	var port := Panel.new()
	port.add_theme_stylebox_override("panel", _sb(PAPER_DEEP, 8))
	port.position = Vector2(16, 16)
	port.size = Vector2(port_sz, port_sz)
	port.clip_contents = true
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(port)
	var face := TextureRect.new()
	face.texture = FUNGUS.get_frame_texture("idle", 0)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 8; face.offset_top = 8; face.offset_right = -8; face.offset_bottom = -8
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port.add_child(face)
	_face = face

	var tx := 16.0 + port_sz + 24.0
	_name_lbl = _mk_label(30, CHEESE_DEEP, Vector2(tx, 18))
	box.add_child(_name_lbl)
	_text_lbl = _mk_label(24, INK, Vector2(tx, 62))
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.size = Vector2(box.size.x - tx - 24.0, 92)
	box.add_child(_text_lbl)
	_choices = HBoxContainer.new()
	_choices.add_theme_constant_override("separation", 16)
	_choices.position = Vector2(tx, 156)
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_choices)
	_hint_lbl = _mk_label(18, CHEESE_DEEP, Vector2(box.size.x - 176.0, box_h - 40.0))
	_hint_lbl.text = "▶ 탭하여 계속"
	box.add_child(_hint_lbl)


func _mk_label(fsize: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _play_beats(beats: Array) -> void:
	for i in beats.size():
		_show_beat(beats[i])
		if beats[i].has("choices"):
			await _wait_choice()
		else:
			await _wait_advance()


func _show_beat(beat: Dictionary) -> void:
	_name_lbl.text = String(beat.get("name", _data.get("name", "?")))
	_text_lbl.text = String(beat.get("text", ""))
	# 펑거스 표정(anim): NPC 스프라이트 + 초상화 얼굴 둘 다 반영
	var face_anim := String(beat.get("anim", ""))
	if face_anim != "" and FUNGUS.has_animation(face_anim):
		if is_instance_valid(_npc):
			_npc.play(face_anim)
		if is_instance_valid(_face):
			_face.texture = FUNGUS.get_frame_texture(face_anim, 0)
	for c in _choices.get_children():
		c.queue_free()
	_choice = -1
	_advance = false
	if beat.has("choices"):
		_tap.disabled = true
		_hint_lbl.visible = false
		_choices.visible = true
		var opts: Array = beat["choices"]
		for i in opts.size():
			var b := Button.new()
			b.text = String(opts[i])
			b.custom_minimum_size = Vector2(0, 56)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_override("font", FONT)
			b.add_theme_font_size_override("font_size", 22)
			b.add_theme_color_override("font_color", INK)
			b.add_theme_color_override("font_hover_color", INK)
			b.add_theme_color_override("font_pressed_color", INK)
			b.add_theme_stylebox_override("normal", _sb(PAPER_DEEP, 10))
			b.add_theme_stylebox_override("hover", _sb(CHEESE, 10))
			b.add_theme_stylebox_override("pressed", _sb(CHEESE_DEEP, 10))
			var idx := i
			b.pressed.connect(func() -> void: _choice = idx)
			_choices.add_child(b)
	else:
		_tap.disabled = false
		_hint_lbl.visible = true
		_choices.visible = false


func _close_ui() -> void:
	if is_instance_valid(_ui):
		_ui.queue_free()
		_ui = null


func _wait_advance() -> void:
	_advance = false
	while not _advance:
		await get_tree().process_frame


func _wait_choice() -> void:
	_choice = -1
	while _choice < 0:
		await get_tree().process_frame
