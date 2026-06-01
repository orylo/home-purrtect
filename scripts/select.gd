extends Control
## 전투 준비 화면 (로드맵 3단계) — 홈에서 진입해 출격 세팅.
##   상단 탭: [직업] [스킬] [동료] [소모품]  (지금은 직업만 진짜, 나머지 "준비중")
##   직업 탭: 보유(해금) 직업 카드 택1 → 선택만 하고 화면 유지(카드 강조 + 미리보기 재생)
##   하단: [← 홈] / [출격 ▶]  — 출격하면 선택한 직업으로 바로 전투
## 직업 해금 타임라인(§6-A: 맨몸 항상 / 보안관 1-3 / 메이드·음악가 1-7)을 읽어 잠금 표시.

const JOBS := {
	"base": "맨몸",
	"sheriff": "보안관",
	"maid": "메이드",
	"jazz": "음악가",
}
const IDLE_FPS := 9.0   # 카드 미리보기 idle 재생 속도
const ORANGE := Color(0.9882, 0.3137, 0.0)
const DARK := Color(0.12, 0.12, 0.16)
# 탭별 안내(준비중 단계)
const TABS := [
	{"id": "job", "name": "직업"},
	{"id": "skill", "name": "스킬"},
	{"id": "ally", "name": "동료"},
	{"id": "item", "name": "소모품"},
]
const TAB_TODO := {
	"skill": "스킬 장착 — 준비중 (로드맵 5단계)",
	"ally": "동료(치와와·비둘기) — 준비중 (로드맵 6단계)",
	"item": "소모품(회복·폭탄·츄르) — 준비중 (로드맵 4단계)",
}

var _sf := {}        # job -> SpriteFrames
var _preview := {}   # job -> TextureRect
var _btns := {}      # job -> Button (선택 강조 재적용용)
var _hover := ""     # 마우스 호버 중인 직업(데스크톱)
var _selected := ""  # 현재 선택된 직업
var _tab := "job"    # 현재 탭
var _t := 0.0
var _frame := 0
var _test_unlocked := false   # 0키 치트로 전 직업 해금했는지
var _head_font: Font
var _pill_normal: StyleBoxFlat
var _pill_selected: StyleBoxFlat
var _pill_disabled: StyleBoxFlat
var _tab_btns := {}           # tab id -> Button
var _placeholder: Label       # 스킬·동료 탭 안내
var _hint: Label              # 직업 탭 하단 선택 안내
var _item_slots: Control      # 소모품 탭 슬롯 자리(3칸, 4단계서 작동)


## 알약 스타일 박스 — bw>0이면 테두리
func _make_pill(c: Color, bw: float = 0.0, bc: Color = Color(1, 1, 1, 1)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(100)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	if bw > 0.0:
		sb.set_border_width_all(int(bw))
		sb.border_color = bc
	return sb


func _ready() -> void:
	$Build.text = GameState.BUILD + " ver."
	_head_font = load("res://assets/fonts/DoHyeon-Regular.ttf")
	_pill_normal = _make_pill(ORANGE)
	_pill_selected = _make_pill(ORANGE, 5.0, Color(1, 1, 1, 1))   # 선택 = 흰 굵은 테두리
	_pill_disabled = _make_pill(Color(0.80, 0.52, 0.40))         # 잠김(흐린 오렌지)

	$Center/Box/Title.text = "전투 준비"

	# 직업 카드 구성
	for job in JOBS:
		var box: Control = $Center/Box/Row.get_node(job)
		var preview: TextureRect = box.get_node("Preview")
		var sf: SpriteFrames = load("res://assets/sprites/cheese/%s/cheese_%s.tres" % [job, job])
		_sf[job] = sf
		_preview[job] = preview
		if sf and sf.has_animation("idle"):
			preview.texture = sf.get_frame_texture("idle", 0)

		var btn: Button = box.get_node("Btn")
		var rank: Label = box.get_node("Rank")
		var unlocked: bool = GameState.is_job_unlocked(job)
		btn.disabled = not unlocked
		box.modulate = Color(1, 1, 1, 1.0) if unlocked else Color(1, 1, 1, 0.35)
		btn.text = GameState.job_title(job) + ("" if unlocked else " (잠김)")
		if unlocked:
			_set_rank_label(rank, job)         # 해금: 등급 라벨
		else:
			_set_lock_label(rank, job)         # 잠김: 해금 조건 안내
		_btns[job] = btn
		_style_job_btn(job)
		btn.pressed.connect(_select.bind(job))
		if unlocked:
			btn.mouse_entered.connect(_on_hover.bind(job))
			btn.mouse_exited.connect(_on_unhover.bind(job))

	_build_tabbar()
	_build_bottom_bar()
	_build_placeholder()
	_build_item_slots()

	# 기본 선택 = 이전에 고른 직업(없거나 잠겼으면 맨몸)
	var start_job: String = GameState.selected_job
	if not JOBS.has(start_job) or not GameState.is_job_unlocked(start_job):
		start_job = "base"
	_select(start_job)
	_set_tab("job")


## 상단 탭바 (직업/스킬/동료/소모품)
func _build_tabbar() -> void:
	var vp := get_viewport_rect().size
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	bar.position = Vector2(vp.x * 0.5 - 320, 28)
	bar.size = Vector2(640, 60)
	add_child(bar)
	for t in TABS:
		var b := Button.new()
		b.text = t["name"]
		b.custom_minimum_size = Vector2(150, 56)
		b.add_theme_font_override("font", _head_font)
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", Color(1, 1, 1))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
		b.pressed.connect(_set_tab.bind(t["id"]))
		bar.add_child(b)
		_tab_btns[t["id"]] = b


## 하단 [← 홈] / [출격 ▶]
func _build_bottom_bar() -> void:
	var vp := get_viewport_rect().size
	_solid_btn("← 홈", Vector2(40, vp.y - 112), Vector2(180, 80), DARK, 30, _on_home)
	_solid_btn("출격 ▶", Vector2(vp.x - 300, vp.y - 112), Vector2(260, 80), ORANGE, 36, _on_launch)


## 비-직업 탭 안내 라벨(가운데, 기본 숨김)
func _build_placeholder() -> void:
	var vp := get_viewport_rect().size
	_placeholder = Label.new()
	_placeholder.add_theme_font_override("font", _head_font)
	_placeholder.add_theme_font_size_override("font_size", 40)
	_placeholder.add_theme_color_override("font_color", Color(0.0275, 0.0235, 0.0275, 0.8))
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.size = Vector2(vp.x, 120)
	_placeholder.position = Vector2(0, vp.y * 0.5 - 60)
	_placeholder.visible = false
	add_child(_placeholder)
	# 직업 탭 하단 선택 안내
	_hint = Label.new()
	_hint.add_theme_font_override("font", _head_font)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(0.0275, 0.0235, 0.0275, 0.55))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(vp.x, 36)
	_hint.position = Vector2(0, vp.y - 168)
	add_child(_hint)


## 소모품 탭 슬롯 자리(3칸) — 4단계서 실제 장착·사용 연결
func _build_item_slots() -> void:
	var vp := get_viewport_rect().size
	_item_slots = Control.new()
	_item_slots.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_slots.visible = false
	add_child(_item_slots)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.position = Vector2(vp.x * 0.5 - 260, vp.y * 0.42 - 80)
	_item_slots.add_child(row)
	for i in range(3):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(150, 150)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.78, 0.78, 0.77, 1)
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.0275, 0.0235, 0.0275, 0.35)
		slot.add_theme_stylebox_override("panel", sb)
		var plus := Label.new()
		plus.text = "+"
		plus.add_theme_font_override("font", _head_font)
		plus.add_theme_font_size_override("font_size", 60)
		plus.add_theme_color_override("font_color", Color(0.0275, 0.0235, 0.0275, 0.4))
		plus.set_anchors_preset(Control.PRESET_FULL_RECT)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(plus)
		row.add_child(slot)
	var cap := Label.new()
	cap.text = "소모품 슬롯 — 준비중 (로드맵 4단계: 상점·실제효과)"
	cap.add_theme_font_override("font", _head_font)
	cap.add_theme_font_size_override("font_size", 26)
	cap.add_theme_color_override("font_color", Color(0.0275, 0.0235, 0.0275, 0.7))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(vp.x, 36)
	cap.position = Vector2(0, vp.y * 0.42 + 110)
	_item_slots.add_child(cap)


## 탭 전환
func _set_tab(tab: String) -> void:
	_tab = tab
	for id in _tab_btns:
		var b: Button = _tab_btns[id]
		var on: bool = (id == tab)
		var sb := StyleBoxFlat.new()
		sb.bg_color = ORANGE if on else Color(0.7, 0.7, 0.7, 0.5)
		sb.set_corner_radius_all(14)
		if on:
			sb.set_border_width_all(3)
			sb.border_color = Color(1, 1, 1, 0.9)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
	var is_job := (tab == "job")
	var is_item := (tab == "item")
	$Center.visible = is_job
	_hint.visible = is_job
	_item_slots.visible = is_item
	_placeholder.visible = not is_job and not is_item   # 스킬·동료만 텍스트 안내
	if _placeholder.visible:
		_placeholder.text = TAB_TODO.get(tab, "준비중")


## [테스트 치트] 숫자 0 → 잠긴 직업까지 전부 선택 가능
func _input(event: InputEvent) -> void:
	if not GameState.is_dev() or _test_unlocked:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_0 or event.keycode == KEY_KP_0):
		_test_unlocked = true
		GameState.unlocked_jobs = ["base", "sheriff", "maid", "jazz"]
		for job in JOBS:
			var box: Control = $Center/Box/Row.get_node(job)
			var btn: Button = box.get_node("Btn")
			var was_locked := btn.disabled
			btn.disabled = false
			box.modulate = Color(1, 1, 1, 1.0)
			btn.text = GameState.job_title(job)
			_style_job_btn(job)
			if was_locked:
				btn.mouse_entered.connect(_on_hover.bind(job))
				btn.mouse_exited.connect(_on_unhover.bind(job))
		$Center/Box/Title.text = "전투 준비  [테스트: 전 직업 해금]"


func _process(delta: float) -> void:
	# 호버 중이면 그 카드, 아니면 선택된 카드의 idle을 재생(터치 환경 대응)
	var anim := _hover if _hover != "" else _selected
	if anim == "" or _tab != "job":
		return
	var sf: SpriteFrames = _sf.get(anim)
	if sf == null:
		return
	var n := sf.get_frame_count("idle")
	if n <= 1:
		return
	_t += delta
	if _t >= 1.0 / IDLE_FPS:
		_t -= 1.0 / IDLE_FPS
		_frame = (_frame + 1) % n
		_preview[anim].texture = sf.get_frame_texture("idle", _frame)


func _on_hover(job: String) -> void:
	_hover = job
	_frame = 0
	_t = 0.0


func _on_unhover(job: String) -> void:
	if _hover == job:
		_hover = ""
		_frame = 0


## 직업 카드 선택(강조 + 즉시 GameState 반영, 화면 유지)
func _select(job: String) -> void:
	if not GameState.is_job_unlocked(job):
		return
	_selected = job
	GameState.selected_job = job
	for j in _btns:
		_style_job_btn(j)
	if _hint:
		_hint.text = "선택: %s  —  [출격]으로 이 직업으로 전투" % GameState.job_title(job)


## 카드 버튼 스타일: 선택=흰테두리 / 잠김=흐림 / 그 외=일반
func _style_job_btn(job: String) -> void:
	var btn: Button = _btns.get(job)
	if btn == null:
		return
	var sb: StyleBoxFlat
	if not GameState.is_job_unlocked(job):
		sb = _pill_disabled
	elif job == _selected:
		sb = _pill_selected
	else:
		sb = _pill_normal
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1))
	if _head_font:
		btn.add_theme_font_override("font", _head_font)
	btn.add_theme_font_size_override("font_size", 36)


## 등급 라벨(맨몸은 숨김)
func _set_rank_label(rank: Label, job: String) -> void:
	var txt := GameState.rank_label(job)
	if txt == "":
		rank.visible = false
	else:
		rank.visible = true
		rank.text = txt
		rank.add_theme_font_override("font", _head_font)
		rank.add_theme_color_override("font_color", GameState.rank_color(job))


## 잠긴 직업 해금 조건 안내(§6-A 타임라인)
func _set_lock_label(rank: Label, job: String) -> void:
	var hint := {
		"sheriff": "1-3 클리어 시 지급",
		"maid": "1-7 상점에서 제작",
		"jazz": "1-7 상점에서 제작",
	}.get(job, "")
	rank.visible = hint != ""
	rank.text = hint
	rank.add_theme_font_override("font", _head_font)
	rank.add_theme_color_override("font_color", Color(0.0275, 0.0235, 0.0275, 0.6))


## 단색 알약 버튼(하단바용)
func _solid_btn(label: String, pos: Vector2, sz: Vector2, bg: Color, fs: int, fn: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.add_theme_font_override("font", _head_font)
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


func _on_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _on_launch() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
