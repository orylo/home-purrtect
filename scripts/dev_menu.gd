extends Control
## 개발자 테스트 메뉴 (DEV 전용) ─ 직업/등급/스테이지/난이도/치트 세팅 후 게임 진입.
## UI는 코드로 구성. 스킬·아이템은 빈 슬롯(시스템 생기면 연결).

const FONT := preload("res://assets/fonts/SBAggro-Medium.ttf")
const JOBS := [["base", "맨몸"], ["sheriff", "보안관"], ["maid", "메이드"], ["jazz", "음악가"]]
const INK := Color(0.0275, 0.0235, 0.0275)
const ORANGE := Color(0.9882, 0.3137, 0.0)

var _job := "base"
var _lv := 1
var _stage := 1
var _diff := 1.0
var _count_mult := 1.0
var _godmode := false
var _oneshot := false
var _grant_skills := false
var _grant_comps := false
var _lv_buttons: Array = []
var _title_lbl: Label   # 미리보기: 직업명(Lv별)
var _rank_lbl: Label    # 미리보기: 등급 라벨(색)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.886, 0.886, 0.875)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 세로로 긴 메뉴 → 스크롤 가능하게(작은 화면서 하단 [홈 화면]·[뒤로]가 잘려 안 보이던 문제 해결)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # 세로만
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	box.add_child(_title("개발자 모드", 48))

	# 미리보기: 직업명(크게) + 등급 라벨(아래 색으로) ─ 기획 §0 표기 구조
	_title_lbl = _title("", 36)
	_rank_lbl = _title("", 22)
	box.add_child(_title_lbl)
	box.add_child(_rank_lbl)

	# 직업
	var job_opt := OptionButton.new()
	_font(job_opt, 26)
	for j in JOBS:
		job_opt.add_item(j[1])
	job_opt.item_selected.connect(func(i):
		_job = JOBS[i][0]
		_refresh_preview())
	box.add_child(_row("직업", job_opt))

	# 등급 Lv (1~5 토글 버튼)
	var lv_box := HBoxContainer.new()
	for i in range(1, 6):
		var b := Button.new()
		b.text = "Lv%d" % i
		_font(b, 24)
		b.toggle_mode = true
		b.pressed.connect(_on_lv.bind(i))
		_lv_buttons.append(b)
		lv_box.add_child(b)
	_lv_buttons[0].button_pressed = true
	box.add_child(_row("등급", lv_box))

	# 스테이지 번호
	var stage_spin := SpinBox.new()
	stage_spin.min_value = 1
	stage_spin.max_value = 20
	stage_spin.value = 1
	_font(stage_spin, 24)
	stage_spin.value_changed.connect(func(v): _stage = int(v))
	box.add_child(_row("스테이지(1-N)", stage_spin))

	# 난이도 M
	var diff_lbl := _label("1.0", 22)
	var diff := HSlider.new()
	diff.min_value = 0.5
	diff.max_value = 3.0
	diff.step = 0.1
	diff.value = 1.0
	diff.custom_minimum_size = Vector2(220, 0)
	diff.value_changed.connect(func(v):
		_diff = v
		diff_lbl.text = "%.1f" % v)
	var diff_row := HBoxContainer.new()
	diff_row.add_child(diff)
	diff_row.add_child(diff_lbl)
	box.add_child(_row("난이도 M", diff_row))

	# 적 수 배율
	var cnt_lbl := _label("1.0", 22)
	var cnt := HSlider.new()
	cnt.min_value = 1.0
	cnt.max_value = 5.0
	cnt.step = 0.5
	cnt.value = 1.0
	cnt.custom_minimum_size = Vector2(220, 0)
	cnt.value_changed.connect(func(v):
		_count_mult = v
		cnt_lbl.text = "%.1f" % v)
	var cnt_row := HBoxContainer.new()
	cnt_row.add_child(cnt)
	cnt_row.add_child(cnt_lbl)
	box.add_child(_row("침입자 수 배율", cnt_row))

	# 치트
	var god := CheckBox.new()
	god.text = "무적"
	_font(god, 24)
	god.toggled.connect(func(p): _godmode = p)
	var one := CheckBox.new()
	one.text = "침입자 즉사"
	_font(one, 24)
	one.toggled.connect(func(p): _oneshot = p)
	var cheat_row := HBoxContainer.new()
	cheat_row.add_theme_constant_override("separation", 24)
	cheat_row.add_child(god)
	cheat_row.add_child(one)
	box.add_child(cheat_row)

	# 스킬 테스트 ─ 현재 직업 스킬 전부 지급+장착(맨몸이면 보안관으로 전환)
	var grant := CheckBox.new()
	grant.text = "스킬 지급+장착 (테스트)"
	_font(grant, 24)
	grant.toggled.connect(func(p): _grant_skills = p)
	box.add_child(grant)
	box.add_child(_dim("↑ 켜면 전투 중 스킬칸/키 1·2·3·4로 발동 가능", 16))
	var grantc := CheckBox.new()
	grantc.text = "동료 지급+장착 (테스트)"
	_font(grantc, 24)
	grantc.toggled.connect(func(p): _grant_comps = p)
	box.add_child(grantc)
	box.add_child(_dim("↑ 켜면 전투 중 동료칸/키 4로 호출 가능", 16))

	# 시작 / 뒤로
	var start_btn := Button.new()
	start_btn.text = "이 설정으로 시작"
	_font(start_btn, 30)
	Design.style_button(start_btn, "cta", 30)   # 빨강 CTA(design.md)
	start_btn.pressed.connect(_on_start)
	box.add_child(start_btn)

	# 테스트 스테이지(샌드박스) ─ 자동 웨이브 없이 직접 적 스폰해 상성 테스트
	var test_btn := Button.new()
	test_btn.text = "테스트 스테이지 (직접 스폰)"
	_font(test_btn, 24)
	test_btn.pressed.connect(_on_test)
	box.add_child(test_btn)

	box.add_child(_dim("↑ 침입자 안 나옴. 게임 중 🐞로 직접 스폰", 16))

	# 홈 화면(개발) ─ 전투 대신 홈으로. 홈의 DEV 도구로 코인·스테이지·전리품 조작.
	#   골드로 강조해 "전투(빨강 시작)와 별개의 목적지"임을 분명히(전엔 회색이라 못 보고 지나침).
	box.add_child(_title("─ 또는 ─", 18))
	var home_btn := Button.new()
	home_btn.text = "홈 화면으로 (개발 도구)"
	_font(home_btn, 28)
	Design.style_button(home_btn, "cheese", 28)
	home_btn.custom_minimum_size = Vector2(0, 60)
	home_btn.pressed.connect(_on_home)
	box.add_child(home_btn)

	var back_btn := Button.new()
	back_btn.text = "뒤로"
	_font(back_btn, 22)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/start.tscn"))
	box.add_child(back_btn)

	_refresh_preview()   # 초기 미리보기(길냥이)


func _on_lv(i: int) -> void:
	_lv = i
	for k in range(_lv_buttons.size()):
		_lv_buttons[k].button_pressed = (k == i - 1)
	_refresh_preview()


## 직업명(Lv별) + 등급 라벨(색) 미리보기 갱신 ─ 기획 §0 표기
func _refresh_preview() -> void:
	var names: Array = GameState.JOB_TITLES.get(_job, ["?"])
	_title_lbl.text = names[clampi(_lv - 1, 0, names.size() - 1)]
	if _job == "base":
		_rank_lbl.visible = false   # 맨몸(길냥이)은 등급 없음
	else:
		_rank_lbl.visible = true
		var idx := clampi(_lv - 1, 0, 4)
		_rank_lbl.text = GameState.RANK_LABELS[idx]   # 등급 라벨(색으로 구분)
		_rank_lbl.add_theme_color_override("font_color", GameState.rank_colors[idx])


func _on_start() -> void:
	_apply_settings()
	GameState.sandbox = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_test() -> void:
	_apply_settings()
	GameState.sandbox = true   # 자동 웨이브 없음 ─ 🐞로 직접 스폰
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_home() -> void:
	_apply_settings()          # mode=dev + 직업/스테이지 등 반영
	GameState.sandbox = false
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _apply_settings() -> void:
	GameState.mode = "dev"
	GameState.dev_set_job(_job, _lv)   # 직업+등급 즉시 장착(1~_lv 전부 보유 처리)
	GameState.stage_minor = _stage
	GameState.difficulty = _diff
	GameState.cheats = {"godmode": _godmode, "enemy_oneshot": _oneshot, "enemy_count_mult": _count_mult}
	if _grant_skills:
		GameState.dev_grant_skills()   # 현재 직업 스킬 전부 지급+장착(스킬 테스트)
	if _grant_comps:
		GameState.dev_grant_companions()   # 동료 둘 지급+장착(동료 테스트)


# --- helpers ---
## 글꼴·크기 + 글자색 INK 강제. (전역 테마는 밝은 톤이라 CheckBox/OptionButton/SpinBox 등
##  타입별 색을 안 정해두면 엔진 기본=흰색 → 밝은 바탕에 흰 글씨로 안 보임. 그걸 막는다.)
func _font(c: Control, fs: int) -> void:
	c.add_theme_font_override("font", FONT)
	c.add_theme_font_size_override("font_size", fs)
	c.add_theme_color_override("font_color", INK)
	c.add_theme_color_override("font_hover_color", INK)
	c.add_theme_color_override("font_pressed_color", INK)
	c.add_theme_color_override("font_focus_color", INK)

func _label(text: String, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", INK)
	return l

func _dim(text: String, fs: int) -> Label:
	var l := _label(text, fs)
	l.add_theme_color_override("font_color", Color(0.32, 0.30, 0.28))   # 밝은 바탕서 읽히는 진한 회갈
	return l

func _title(text: String, fs: int) -> Label:
	var l := _label(text, fs)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _row(label: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l := _label(label, 22)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	h.add_child(control)
	return h

func _pill(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(100)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	return sb
