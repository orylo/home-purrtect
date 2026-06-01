extends Control
## 맥스의 상점 (로드맵 4단계) — 코인을 쓰는 곳.
##   첫 조각: [레벨업 구매] (선택 직업 Lv↑, 코인 차감, 세이브).
##   소모품·전리품 매입·직업 제작은 다음 조각에서 연결(자리 안내만).
## 진입: 홈 [맥스 상점]. 나가기: [← 홈].

const FONT := preload("res://assets/fonts/DoHyeon-Regular.ttf")
const BG := preload("res://assets/backgrounds/stage1_wall.jpg")
const ORANGE := Color(0.9882, 0.3137, 0.0)
const DARK := Color(0.12, 0.12, 0.16)
const GOLD := Color(1.0, 0.82, 0.2)

var _coin_lbl: Label
var _job_lbl: Label
var _lv_lbl: Label
var _buy_btn: Button
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	GameState.mode = GameState.mode if GameState.mode == "dev" else "player"
	_build()
	_refresh()


func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	# 배경(어둡게 깐 저택)
	var bg := TextureRect.new()
	bg.texture = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.5, 0.5, 0.55)
	add_child(bg)

	# 상단: 제목 + 코인
	var title := _text("맥스의 상점", 40, Color(1, 1, 1))
	title.position = Vector2(40, 24)
	add_child(title)
	_coin_lbl = _text("", 30, GOLD)
	_coin_lbl.position = Vector2(vp.x - 320, 30)
	_coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_lbl.size = Vector2(280, 40)
	add_child(_coin_lbl)

	# 레벨업 카드(가운데)
	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.14, 0.92)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.25)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(vp.x * 0.5 - 380, vp.y * 0.30)
	card.size = Vector2(760, 300)
	add_child(card)

	var head := _text("직업 레벨업", 32, ORANGE)
	head.position = Vector2(36, 24)
	card.add_child(head)
	_job_lbl = _text("", 30, Color(1, 1, 1))
	_job_lbl.position = Vector2(36, 84)
	card.add_child(_job_lbl)
	_lv_lbl = _text("", 26, Color(0.85, 0.85, 0.9))
	_lv_lbl.position = Vector2(36, 134)
	card.add_child(_lv_lbl)

	_buy_btn = Button.new()
	_buy_btn.position = Vector2(36, 198)
	_buy_btn.custom_minimum_size = Vector2(688, 72)
	_buy_btn.size = Vector2(688, 72)
	_style_btn(_buy_btn, ORANGE, 32)
	_buy_btn.pressed.connect(_on_buy_levelup)
	card.add_child(_buy_btn)

	# 다음 조각 안내(자리만)
	var soon := _text("소모품 구매 · 전리품 매입 · 직업 제작 — 다음 조각에서", 24, Color(1, 1, 1, 0.7))
	soon.position = Vector2(vp.x * 0.5 - 380, vp.y * 0.30 + 320)
	add_child(soon)

	# 하단: 홈
	_solid_btn("← 홈", Vector2(40, vp.y - 112), Vector2(200, 80), DARK, 30,
			func(): get_tree().change_scene_to_file("res://scenes/home.tscn"))

	# 토스트
	_toast = _text("", 30, Color(1, 1, 1))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(vp.x, 50)
	_toast.position = Vector2(0, vp.y * 0.16)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.visible = false
	add_child(_toast)


## 코인·직업·레벨·버튼 상태 갱신
func _refresh() -> void:
	var job: String = GameState.selected_job
	_coin_lbl.text = "코인 " + _commafy(GameState.coins)
	var lv := int(GameState.job_level.get(job, 1))
	_job_lbl.text = "%s   ·   %s" % [GameState.job_title(job), GameState.rank_label(job)]
	var cost := GameState.levelup_cost(job)
	if cost <= 0:
		_lv_lbl.text = "Lv %d — 최고 레벨 (전투력 배율 ×%.1f)" % [lv, GameState.level_mult(job)]
		_buy_btn.text = "최고 레벨 도달"
		_buy_btn.disabled = true
	else:
		var next_mult: float = GameState.LV_MULT[clampi(lv, 0, 4)]
		_lv_lbl.text = "Lv %d → Lv %d   (전투력 배율 ×%.1f → ×%.1f)" % [
				lv, lv + 1, GameState.level_mult(job), next_mult]
		_buy_btn.text = "레벨업  —  %s 코인" % _commafy(cost)
		_buy_btn.disabled = not GameState.can_levelup(job)


func _on_buy_levelup() -> void:
	var job: String = GameState.selected_job
	if not GameState.can_levelup(job):
		_toast_msg("코인이 부족해요 (%s 필요)" % _commafy(GameState.levelup_cost(job)))
		return
	if GameState.do_levelup(job):
		_toast_msg("레벨업! %s" % GameState.job_title(job))
		_refresh()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.visible = false


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


func _style_btn(b: Button, bg: Color, fs: int) -> void:
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(16)
	var sbd := StyleBoxFlat.new()
	sbd.bg_color = Color(0.4, 0.4, 0.42)   # 비활성(코인 부족/최고레벨)
	sbd.set_corner_radius_all(16)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("disabled", sbd)


func _solid_btn(label: String, pos: Vector2, sz: Vector2, bg: Color, fs: int, fn: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	_style_btn(b, bg, fs)
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
