extends Node2D
## 스테이지 인트로 이벤트 — 웨이브 시작 전 인게임 연출(컷씬 아님).
##   · NPC가 화면 좌측에서 걸어 들어와 하단 대화창으로 말함(이름·얼굴·대사·선택지).
##   · 연출 동안 상/하단 HUD 숨김 + 스포너 hold. 끝나면 NPC 퇴장 → HUD 복귀 → 웨이브 시작.
##   v1: 1-1에서 "회색쥐" 스프라이트를 펑거스 대역으로 사용.
##   확장: INTRO에 "막-스테이지" 키로 {npc, name, beats:[{text, choices?}]} 추가.

const MFRAMES := preload("res://assets/sprites/enemies/mouse/mouse_frames.tres")
const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")

# design.md 색 토큰
const INK := Color("241F1B")
const PAPER := Color("F3E3BE")
const PAPER_DEEP := Color("E4CB95")
const CHEESE := Color("F2B33D")
const CHEESE_DEEP := Color("D4912A")

const SPRITE_FOOT := 81.875   # enemy_mouse.tscn 기준: 발(원점)→스프라이트 중심 오프셋

## 스테이지별 인트로 데이터
const INTRO := {
	"1-1": {
		"npc": "gray",
		"name": "펑거스",
		"beats": [
			{"text": "크크… 너, 잘 만났다!!"},
			{"text": "내 졸병들이 널 가만두지 않을 거다."},
			{"text": "그 집엔… 내가 다시 들어갈 거야.", "choices": ["덤벼 봐!", "무슨 소리야?"]},
		],
	},
}

var _spawner: Node = null
var _hud: CanvasLayer = null
var _npc: AnimatedSprite2D = null
var _ui: CanvasLayer = null
var _data: Dictionary = {}

# UI 노드
var _tap: Button = null
var _name_lbl: Label = null
var _text_lbl: Label = null
var _hint_lbl: Label = null
var _choices: HBoxContainer = null

var _advance := false
var _choice := -1


func _ready() -> void:
	var key := "%d-%d" % [GameState.stage_major, GameState.stage_minor]
	if GameState.sandbox or not INTRO.has(key):
		queue_free()
		return
	_data = INTRO[key]
	_spawner = get_parent().get_node_or_null("Spawner")
	_hud = get_parent().get_node_or_null("HUD")
	if _spawner != null and _spawner.has_method("hold_intro"):
		_spawner.hold_intro()
	if _hud != null:
		_hud.visible = false
	_run()


func _run() -> void:
	await get_tree().process_frame          # 뷰포트/레이아웃 준비
	_spawn_npc()
	await _walk_npc(get_viewport().get_visible_rect().size.x * 0.30, 1.3)   # 좌측에서 입장
	_build_ui()
	var beats: Array = _data.get("beats", [])
	for i in beats.size():
		var beat: Dictionary = beats[i]
		_show_beat(beat)
		if beat.has("choices"):
			await _wait_choice()
		else:
			await _wait_advance()
	_close_ui()
	await _walk_npc(-180.0, 1.0)             # 좌측으로 퇴장
	if is_instance_valid(_npc):
		_npc.queue_free()
	if _hud != null:
		_hud.visible = true
	if _spawner != null and _spawner.has_method("release_intro"):
		_spawner.release_intro()             # 이제 웨이브 시작
	queue_free()


# ── NPC ────────────────────────────────────────────────
func _spawn_npc() -> void:
	_npc = AnimatedSprite2D.new()
	_npc.sprite_frames = MFRAMES
	_npc.scale = Vector2(0.65, 0.65)
	_npc.flip_h = true                       # 좌→우(화면 안쪽) 바라봄
	_npc.position = Vector2(-160.0, Layout.ground_y() - SPRITE_FOOT)
	add_child(_npc)
	_npc.play("walk")


func _walk_npc(target_x: float, dur: float) -> void:
	if not is_instance_valid(_npc):
		return
	_npc.play("walk")
	var tw := create_tween()
	tw.tween_property(_npc, "position:x", target_x, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if is_instance_valid(_npc):
		_npc.pause()                         # 멈춰서 말하기(별도 idle 프레임 없음)


# ── 대화 UI(코드 생성) ──────────────────────────────────
func _sb(bg: Color, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(4)
	s.border_color = INK
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16.0
	s.content_margin_right = 16.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s


func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	_ui = CanvasLayer.new()
	_ui.layer = 60                            # HUD보다 위
	add_child(_ui)

	# 화면 탭 = 다음(선택지 없을 때만)
	_tap = Button.new()
	_tap.flat = true
	_tap.focus_mode = Control.FOCUS_NONE
	_tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tap.pressed.connect(func() -> void: _advance = true)
	_ui.add_child(_tap)

	var box_h := 232.0
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", _sb(PAPER, 12))
	box.position = Vector2(24, vp.y - box_h - 24)
	box.size = Vector2(vp.x - 48, box_h)
	_ui.add_child(box)

	# 얼굴(초상화)
	var port_sz := box_h - 32.0
	var port := Panel.new()
	port.add_theme_stylebox_override("panel", _sb(PAPER_DEEP, 8))
	port.position = Vector2(16, 16)
	port.size = Vector2(port_sz, port_sz)
	box.add_child(port)
	var face := TextureRect.new()
	face.texture = MFRAMES.get_frame_texture("walk", 0)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 10; face.offset_top = 10; face.offset_right = -10; face.offset_bottom = -10
	port.add_child(face)

	var tx := 16.0 + port_sz + 24.0
	# 이름
	_name_lbl = Label.new()
	_name_lbl.add_theme_font_override("font", FONT)
	_name_lbl.add_theme_font_size_override("font_size", 30)
	_name_lbl.add_theme_color_override("font_color", CHEESE_DEEP)
	_name_lbl.position = Vector2(tx, 18)
	box.add_child(_name_lbl)
	# 대사
	_text_lbl = Label.new()
	_text_lbl.add_theme_font_override("font", FONT)
	_text_lbl.add_theme_font_size_override("font_size", 24)
	_text_lbl.add_theme_color_override("font_color", INK)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.position = Vector2(tx, 62)
	_text_lbl.size = Vector2(box.size.x - tx - 24.0, 84)
	box.add_child(_text_lbl)
	# 선택지
	_choices = HBoxContainer.new()
	_choices.add_theme_constant_override("separation", 16)
	_choices.position = Vector2(tx, 150)
	box.add_child(_choices)
	# 계속 힌트
	_hint_lbl = Label.new()
	_hint_lbl.text = "▶ 탭하여 계속"
	_hint_lbl.add_theme_font_override("font", FONT)
	_hint_lbl.add_theme_font_size_override("font_size", 18)
	_hint_lbl.add_theme_color_override("font_color", CHEESE_DEEP)
	_hint_lbl.position = Vector2(box.size.x - 168.0, box_h - 38.0)
	box.add_child(_hint_lbl)


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
