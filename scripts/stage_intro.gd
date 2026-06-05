extends Node2D
## 스테이지 이벤트(인게임 연출). 두 종류:
##   · 인트로: 웨이브 전, NPC가 화면 우측에서 "걸어서" 치즈와 대칭 위치까지 와서 대화(HUD 숨김).
##   · 팝업(튜토리얼/도발): 트리거(예: 첫 처치) 시 게임 일시정지 + 화면 Dim + 대화창.
##   대화 중에는 게임이 멈춰 조작이 실제로 막힌다(트리 paused). 본 노드/UI는 PROCESS_MODE_ALWAYS.
##   v1: 1-1에서 "회색쥐" 스프라이트를 펑거스 대역으로 사용.

const MFRAMES := preload("res://assets/sprites/enemies/mouse/mouse_frames.tres")
const FUNGUS := preload("res://assets/sprites/fungus/fungus_frames.tres")
const FONT := preload("res://assets/fonts/SBAggro-Medium.ttf")

# design.md 색 토큰
const INK := Color("241F1B")
const PAPER := Color("F3E3BE")
const PAPER_DEEP := Color("E4CB95")
const CHEESE := Color("F2B33D")
const CHEESE_DEEP := Color("D4912A")

const SPRITE_FOOT := 81.875   # enemy 기준: 발(원점)→스프라이트 중심 오프셋
const WALK_SPEED := 230.0     # NPC 걷는 속도(px/s) ─ 급하지 않게

## 스테이지별 이벤트 데이터
const EVENTS := {
	"1-1": {
		"name": "펑거스",
		"intro": [                                          # ① 전투 시작 전 (?→펑거스 정체 공개)
			{"text": "흐흐… 드디어 돌아왔다, 나의 안식처여……", "name": "?", "anim": "idle"},
			{"text": "…뭐야? 웬 고양이가 길을 막고 서 있지? 비켜라, 여긴 내 집이다!", "name": "?", "anim": "fear"},
			{"text": "너… 그때 날 걷어찬 그 고양이?! 이 펑거스, 그 발길질을 잊을 줄 알았더냐!", "anim": "angry"},
			{"text": "좋다, 오늘 집도 복수도 한꺼번에 되찾아주마. 가라, 나의 정예들이여─!", "anim": "angry"},
		],
		"first_kill": [                                     # ② 첫 몹 처치(1회) ─ 당황
			{"text": "뭐…?! 어떻게 싸울 줄 아는 거지?! 한낱 길바닥 출신인 주제에…!", "anim": "fear"},
		],
		"on_wave": {                                        # ③ 웨이브 시작 팝업 ─ 비웃음
			2: [{"text": "제법이군. 허나 이 몸은 위대한 책략가! 부대는 얼마든지 있다 ─ 가라, 제2진!", "anim": "laugh"}],
		},
		"outro": [                                          # ④ 전 웨이브 클리어 후 ─ 분노
			{"text": "이…이럴 수가! 오늘의 수치, 이 펑거스가 절대 잊지 않겠다!", "anim": "angry"},
			{"text": "이번이 마지막이라 생각 마라! 이 몸은 반드시 다시 돌아온다, 치즈으으─!", "anim": "angry"},
		],
	},
	"1-3": {
		"name": "펑거스",
		"intro": [                                          # ① 전투 시작 전(흐림+비) ─ 비웃음
			{"text": "또 만났군, 치즈. 허나 이 몸을 우습게 보지 마라!", "anim": "laugh"},
			{"text": "이 위대한 펑거스가… 새로운 비밀 병기를 준비했거든!", "anim": "laugh"},
			{"text": "멀찍이서 던져주마. 네놈이 손도 못 대게 말이야 ─ 가라, 나의 정예들이여!", "anim": "laugh"},
		],
		"on_wave": {
			2: [{"text": "후하하─! 등장이다, 나의 투척 부대! 멀리서 깔끔하게 처리해주마!", "anim": "laugh"}],   # ② 투척쥐 첫 등장
			3: [   # ③ 웨이브3 시작 + 비 그침→해, 당황
				{"text": "아닛─! 나의 비장의 카드, 투척쥐를 물리치다니…!", "anim": "fear"},
				{"text": "게다가 이 타이밍에 비는 왜 그치는 거야?! 그것도… 희망차게?!", "anim": "fear"},
			],
		},
		"outro": [                                          # ④ 전 웨이브 클리어 후
			{"text": "흥… 이번엔 제법 진땀 좀 뺐겠다, 치즈?", "anim": "laugh"},
			{"text": "두고 봐라! 다음엔 투척쥐를 잔뜩, 아주 잔뜩 데려올 테니까! 끄으윽─!", "anim": "angry"},
		],
		"reward": "보안관",                                  # ⑤ 클리어 후 보안관 획득
		"reward_text": "[전투 준비 > 직업]에서 장착·교체할 수 있어요.",
	},
	# 케이스 0 ─ 새 적 등장 스테이지 펑거스 약올리기(인트로만, 해금 없음)
	"1-5": {    # 박쥐 첫 등장(첫 공중 적). 펄 해금(케이스 A)은 클리어 후 인스씬(game.gd)으로 별개 ─ 시간상 분리 공존.
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
			{"text": "회색 따위는 잊어라. 어둠에 절은 나의 정예 ─ 검은 부대다. 더 단단하고, 더 사납지.", "anim": "laugh"},
		],
	},
	"1-12": {   # 거미(둔화)
		"name": "펑거스",
		"intro": [
			{"text": "오늘은 특별한 손님을 모셨지 ─ 거미님 되시겠다.", "anim": "laugh"},
			{"text": "끈적한 거미줄에 발이 쩍 붙으면, 굼떠진 네놈을 실컷 두들겨주마!", "anim": "laugh"},
		],
	},
	"1-14": {   # 벌(독)
		"name": "펑거스",
		"intro": [
			{"text": "윙윙─ 들리나? 이번엔 나의 벌 부대다.", "anim": "laugh"},
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
var _typing := false   # 대사 타이핑 중(탭=스킵→전체표시), 끝나면 탭=다음
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
	if GameState.sandbox or GameState.cheats.get("skip_events", false) or not EVENTS.has(key):
		queue_free()      # 샌드박스 / DEV 이벤트스킵(전투만) / 이벤트 없는 스테이지 → 인트로·아웃트로·팝업 전부 생략
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
	queue_redraw()   # 펑거스 발밑 그림자 갱신(이동 추종)


## 펑거스 NPC 발밑 그림자 ─ 캐릭터·적과 동일 톤(검정 30% 납작 타원). NPC가 있을 때만.
func _draw() -> void:
	if _npc == null or not is_instance_valid(_npc):
		return
	var sc: float = _npc.scale.x                        # height 280 스케일
	var rx := 95.0 * sc                                 # 발 반폭(프레임 ~190px/2) × 스케일
	var gy := Layout.ground_y() - rx * Layout.SHADOW_LIFT_FRAC   # 접지점 보정 lift
	draw_set_transform(Vector2(_npc.position.x, gy), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, rx, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── 인트로(웨이브 전, NPC 도보 등장) ─────────────────────
func _run_intro() -> void:
	_busy = true
	# ★ hold은 await보다 먼저 ─ 한 프레임이라도 spawner._process가 돌아 "전투 시작!" 큐가
	#   인트로 대화 전에 새어나가는 것을 방지(battle_starting은 hold 중엔 안 뜸).
	if _spawner != null and _spawner.has_method("hold_intro"):
		_spawner.hold_intro()
	# 펑거스 등장 = 보스 BGM(stage_intro NPC는 전부 펑거스). 기본 "boss", 필요시 intro_music로 개별 지정/해제("").
	#   전투 시작 큐(battle_starting)에서 game.gd가 clear_override → battle 복귀.
	var im: String = _data.get("intro_music", "boss")
	if im != "":
		Music.set_override(im)
	await get_tree().process_frame                    # 플레이어/뷰포트 준비
	if _hud != null:
		_hud.visible = false
	await _await_cat_landed()                          # 점프 중이면 착지까지 기다린 뒤 정지
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
	await _await_cat_landed()                          # 점프 중이면 착지 대기(공중 대화 방지)
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


## ③ 웨이브 시작 팝업(on_wave[N]) ─ current는 1부터.
func _on_wave_popup(current: int, _total: int) -> void:
	if _busy:
		return
	var ow: Dictionary = _data.get("on_wave", {})
	if ow.has(current):
		await _run_popup(ow[current])


# ── ④ 클리어 후 퇴장(+⑤ 보상) ─ game.gd가 클리어 패널 직전에 await ─────
func has_outro() -> bool:
	return _data.has("outro")


func play_outro() -> void:
	if not _data.has("outro"):
		return
	_busy = true
	if _hud != null:
		_hud.visible = false
	await _await_cat_landed()                          # 점프 중 클리어 → 착지까지 기다린 뒤 퇴장 이벤트
	# 펑거스 등장 = 보스 BGM(클리어 후 퇴장 대화 동안). 퇴장 끝에 clear_override → battle 복귀.
	var om: String = _data.get("outro_music", "boss")
	if om != "":
		Music.set_override(om)
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
	#   전투처럼 뒷걸음질(back, 우향)로 밀리게 backstep=true.
	if pl != null and cat_x > cat_target + 6.0 and pl.has_method("event_walk_to"):
		pl.event_walk_to(cat_target, true)
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
	Music.clear_override()                             # 펑거스 퇴장 → 보스 BGM 해제(클리어 화면은 battle)
	get_tree().paused = false
	_busy = false


## 이벤트 일시정지 전, 치즈가 점프 중이면 착지까지 대기(공중에서 대화/정지 방지).
##   아직 트리가 안 멈춘 상태라 물리가 돌아 자연히 떨어져 착지한다. 안전상한 둠.
func _await_cat_landed() -> void:
	var pl := get_parent().get_node_or_null("Player")
	if pl == null or not pl.has_method("is_airborne"):
		return
	var guard := 0
	while pl.is_airborne() and guard < 180:        # ~3초(60fps) 안전상한
		await get_tree().process_frame
		guard += 1


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
	_tap.pressed.connect(_on_tap)
	_ui.add_child(_tap)

	# 공용 대화창(DialoguePanel) ─ 게임 내 모든 대화창과 동일 스타일. 펑거스 초상화 전달.
	var d := DialoguePanel.build(_ui, vp, FUNGUS.get_frame_texture("idle", 0))
	_face = d["face"]
	_name_lbl = d["name_lbl"]
	_text_lbl = d["text_lbl"]
	_choices = d["choices"]
	_hint_lbl = d["hint_lbl"]


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
		await _type_text(String(beats[i].get("text", "")), _voice_id())   # 한 글자씩 + 재잘 보이스
		if beats[i].has("choices"):
			await _wait_choice()
		else:
			await _wait_advance()


## stage_intro NPC는 전부 펑거스 → "fungus" 보이스(beat에 "voice" 있으면 우선).
func _voice_id() -> String:
	return String(_data.get("voice", "fungus"))


## 대사를 한 글자씩 표시 + 글자마다 재잘 블립. 탭하면 즉시 전체 표시(스킵).
func _type_text(text: String, profile_id: String) -> void:
	_typing = true
	VoiceBlip.reset(profile_id)
	_text_lbl.text = text
	_text_lbl.visible_characters = 0
	var n := text.length()
	var dt := VoiceBlip.char_sec(profile_id)
	var i := 0
	while i < n and _typing:
		_text_lbl.visible_characters = i + 1
		VoiceBlip.blip(profile_id, text[i], i, n)
		i += 1
		await get_tree().create_timer(dt, true).timeout   # process_always=true → 일시정지(이벤트) 중에도 진행
	_text_lbl.visible_characters = -1   # 전체 표시(스킵/완료)
	_typing = false


## 탭: 타이핑 중이면 스킵(전체표시), 아니면 다음으로.
func _on_tap() -> void:
	if _typing:
		_typing = false
	else:
		_advance = true


func _show_beat(beat: Dictionary) -> void:
	_name_lbl.text = String(beat.get("name", _data.get("name", "?")))
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
