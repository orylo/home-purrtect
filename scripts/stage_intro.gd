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

const SPRITE_FOOT := 81.875   # enemy_mouse 기준: 발(원점)→스프라이트 중심 오프셋
const WALK_SPEED := 230.0     # NPC 걷는 속도(px/s) — 급하지 않게

## 스테이지별 이벤트 데이터
const EVENTS := {
	"1-1": {
		"npc": "gray",
		"name": "펑거스",
		"intro": [
			{"text": "크크… 너, 잘 만났다!!"},
			{"text": "내 졸병들이 널 가만두지 않을 거다."},
			{"text": "그 집엔… 내가 다시 들어갈 거야.", "choices": ["덤벼 봐!", "무슨 소리야?"]},
		],
		"first_kill": [
			{"text": "아닛! 내 졸병을 쓰러뜨리다니… 제법인걸?"},
			{"text": "하지만 이건 어떨까!? 끝없이 보내주마!"},
		],
	},
}

var _data: Dictionary = {}
var _spawner: Node = null
var _hud: CanvasLayer = null
var _npc: AnimatedSprite2D = null
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
	_build_ui(0.55)                                    # 화면 Dim
	await _play_beats(beats)
	_close_ui()
	if _hud != null:
		_hud.visible = true
	get_tree().paused = false
	_busy = false


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
	_name_lbl.text = String(_data.get("name", "?"))
	_text_lbl.text = String(beat.get("text", ""))
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
