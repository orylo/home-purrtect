extends Control
## 홈 화면 (메인 허브) — 로드맵 2단계.
##   상단: 코인 / 스테이지 / 설정(준비중)
##   중앙: 저택 배경 + 치즈(대기) + 펄(1-5 후)·맥스(1-7 후) 진입점(준비중)
##   하단: [전투 준비](좌) / [맵]·[출격 ▶](우)
## 작동: [출격]→전투 / [전투 준비]→직업선택. 나머지는 "준비중"(각 시스템 단계에서 연결).

const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const BG := preload("res://assets/backgrounds/stage1_wall.jpg")
const ORANGE := Color(0.9882, 0.3137, 0.0)
const DARK := Color(0.12, 0.12, 0.16)

var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	GameState.mode = "player"   # 홈은 플레이어 모드 허브
	_build()


func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	# 배경(저택)
	var bg := TextureRect.new()
	bg.texture = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	# 치즈(대기) — 선택 직업 idle
	var frames := load(GameState.job_frames_path())
	if frames:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = frames
		if (frames as SpriteFrames).has_animation("idle"):
			spr.play("idle")
		spr.position = Vector2(vp.x * 0.52, vp.y * 0.78)
		add_child(spr)

	# 상단 바
	var coin := _text("코인 " + _commafy(GameState.coins), 30, Color(1.0, 0.82, 0.2))
	coin.position = Vector2(40, 26)
	add_child(coin)
	var stage := _text("1막   ·   " + GameState.stage_label(), 30, Color(1, 1, 1))
	stage.position = Vector2(vp.x * 0.5 - 110, 26)
	add_child(stage)
	_btn("가방", Vector2(vp.x - 296, 24), Vector2(120, 46), Color(0.25, 0.3, 0.4), 22, _show_bag)
	_btn("설정", Vector2(vp.x - 150, 24), Vector2(116, 46), DARK, 22,
			func(): _toast_msg("설정 — 준비중"))

	# NPC 진입점(해금 후 등장) — 지금은 자리만(준비중)
	# 펄 — 미연시풍 대화 화면(축복·호감도). ※기획상 1-5 해금이나 테스트 위해 상시 노출.
	_btn("펄", Vector2(vp.x * 0.20, vp.y * 0.40), Vector2(120, 60), Color(0.5, 0.35, 0.55), 24,
			func(): get_tree().change_scene_to_file("res://scenes/pearl.tscn"))
	# 맥스 상점 — NPC 인사(맥스) → 상점. ※기획상 1-7 해금이나 테스트 위해 상시 노출.
	_btn("맥스 상점", Vector2(vp.x * 0.13, vp.y * 0.62), Vector2(190, 60), Color(0.25, 0.3, 0.4), 24,
			func(): get_tree().change_scene_to_file("res://scenes/maxtalk.tscn"))

	# 하단 좌: 전투 준비
	_btn("전투 준비", Vector2(40, vp.y - 112), Vector2(230, 80), DARK, 30,
			func(): get_tree().change_scene_to_file("res://scenes/select.tscn"))

	# 하단 우: 맵(준비중) + 출격
	_btn("맵", Vector2(vp.x - 400, vp.y - 112), Vector2(120, 80), DARK, 28,
			func(): _toast_msg("스테이지 맵(파밍) — 준비중"))
	_btn("출격 ▶", Vector2(vp.x - 260, vp.y - 112), Vector2(220, 80), ORANGE, 34,
			func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

	# 토스트
	_toast = _text("", 30, Color(1, 1, 1))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(vp.x, 50)
	_toast.position = Vector2(0, vp.y * 0.5)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.visible = false
	add_child(_toast)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.visible = false


## 가방(인벤토리) 오버레이 — 전리품·소모품·스킬 보유 현황(읽기 전용)
func _show_bag() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var panel := Panel.new()
	panel.size = Vector2(minf(840, vp.x - 80), vp.y - 120)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, 60)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14, 0.98); sb.set_corner_radius_all(20)
	sb.set_border_width_all(3); sb.border_color = Color(1, 1, 1, 0.25)
	panel.add_theme_stylebox_override("panel", sb)
	ov.add_child(panel)
	var sc := ScrollContainer.new()
	sc.position = Vector2(28, 24); sc.size = panel.size - Vector2(56, 110)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(sc.size.x, 0)
	sc.add_child(vb)
	vb.add_child(_text("가방 — 보유 현황", 32, Color(1.0, 0.82, 0.2)))
	# 전리품
	vb.add_child(_text("◆ 전리품", 24, ORANGE))
	var any_mat := false
	for id in GameState.MAT_ORDER:
		var n: int = GameState.mat_count(id)
		if n > 0:
			any_mat = true
			vb.add_child(_text("  %s  ×%d" % [String(GameState.MATERIALS[id]["name"]), n], 22, Color(1, 1, 1)))
	if not any_mat:
		vb.add_child(_text("  (없음 — 전투에서 적 처치 시 드랍)", 20, Color(1, 1, 1, 0.6)))
	# 소모품
	vb.add_child(_text("◆ 소모품", 24, ORANGE))
	var any_item := false
	for id in ["bandage", "anchovy", "firecracker"]:
		var n: int = int(GameState.inventory.get(id, 0))
		if n > 0:
			any_item = true
			vb.add_child(_text("  %s  ×%d" % [String(GameState.CONSUMABLES[id]["name"]), n], 22, Color(1, 1, 1)))
	if not any_item:
		vb.add_child(_text("  (없음 — 맥스 상점에서 구매)", 20, Color(1, 1, 1, 0.6)))
	# 스킬
	vb.add_child(_text("◆ 보유 스킬", 24, ORANGE))
	if GameState.owned_skills.is_empty():
		vb.add_child(_text("  (없음 — 맥스 상점 [스킬]에서 구매)", 20, Color(1, 1, 1, 0.6)))
	else:
		var jk := {"sheriff": "보안관", "maid": "메이드", "jazz": "음악가"}
		for sid in GameState.owned_skills:
			var s: Dictionary = GameState.SKILLS[sid]
			vb.add_child(_text("  %s  (%s)" % [String(s["name"]), jk.get(s["job"], s["job"])], 22, Color(1, 1, 1)))
	# 닫기 버튼
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(180, 56)
	close.position = Vector2(panel.size.x * 0.5 - 90, panel.size.y - 74)
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 26)
	close.add_theme_color_override("font_color", Color(1, 1, 1))
	var cs := StyleBoxFlat.new(); cs.bg_color = ORANGE; cs.set_corner_radius_all(16)
	for st in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(st, cs)
	close.pressed.connect(ov.queue_free)
	panel.add_child(close)



func _toast_msg(msg: String) -> void:
	if _toast == null:
		return
	_toast.text = msg
	_toast.visible = true
	_toast_t = 1.6


# --- helpers ---
func _text(s: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _btn(label: String, pos: Vector2, sz: Vector2, bg: Color, fs: int, fn: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.5)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(fn)
	add_child(b)


func _commafy(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
