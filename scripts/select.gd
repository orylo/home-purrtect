extends Control
## 시작 직업 선택 화면 (테스트용) — 4직업 중 하나 고르면 게임 시작.
## 버튼에 마우스를 올리면(호버) 그 직업의 idle 애니메이션이 미리보기에서 재생된다.

const JOBS := {
	"base": "맨몸",
	"sheriff": "보안관",
	"maid": "메이드",
	"jazz": "음악가",
}
const IDLE_FPS := 9.0   # 호버 시 idle 재생 속도
# 버전은 GameState.BUILD 로 통일(시작 화면과 공유)

var _sf := {}        # job -> SpriteFrames
var _preview := {}   # job -> TextureRect
var _hover := ""     # 현재 호버 중인 직업
var _t := 0.0
var _frame := 0
var _test_unlocked := false   # 0키 치트로 전 직업 해금했는지
var _pill_normal: StyleBoxFlat
var _pill_hover: StyleBoxFlat
var _pill_disabled: StyleBoxFlat
var _head_font: Font


## 직업 선택 버튼용 오렌지 알약 스타일(메인 컬러 CTA)
func _make_pill(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(100)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	return sb


## 직업 버튼 = 주요 액션 → Digital Orange + 흰 글씨 + 크게(Black 40)
func _style_primary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _pill_normal)
	btn.add_theme_stylebox_override("hover", _pill_hover)
	btn.add_theme_stylebox_override("pressed", _pill_hover)
	btn.add_theme_stylebox_override("focus", _pill_normal)
	btn.add_theme_stylebox_override("disabled", _pill_disabled)   # 잠긴 직업도 오렌지(흐리게)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1))
	if _head_font:
		btn.add_theme_font_override("font", _head_font)
	btn.add_theme_font_size_override("font_size", 40)


func _ready() -> void:
	$Build.text = GameState.BUILD + " ver."
	_head_font = load("res://assets/fonts/Pretendard-Black.ttf")
	_pill_normal = _make_pill(Color(0.9882, 0.3137, 0.0))   # Digital Orange
	_pill_hover = _make_pill(Color(0.86, 0.27, 0.0))
	_pill_disabled = _make_pill(Color(0.80, 0.52, 0.40))    # 잠김(흐린 오렌지)
	# 스테이지 표시 + 해금 안내
	var title: Label = $Center/Box/Title
	if GameState.jobs_unlocked:
		title.text = "스테이지 %s — 직업 선택" % GameState.stage_label()
	else:
		title.text = "스테이지 %s — 길냥이로 시작!\n(클리어하면 직업 해금)" % GameState.stage_label()

	for job in JOBS:
		var box: Control = $Center/Box/Row.get_node(job)
		var preview: TextureRect = box.get_node("Preview")
		var sf: SpriteFrames = load("res://assets/sprites/cheese/%s/cheese_%s.tres" % [job, job])
		_sf[job] = sf
		_preview[job] = preview
		if sf and sf.has_animation("idle"):
			preview.texture = sf.get_frame_texture("idle", 0)   # 기본은 idle 첫 프레임

		var btn: Button = box.get_node("Btn")
		btn.text = GameState.job_title(job)   # Lv별 호칭(예: 견습 보안관)
		# 등급 라벨(직업명 아래, 색으로). 맨몸은 없음.
		var rank: Label = box.get_node("Rank")
		_set_rank_label(rank, job)
		# 1-1은 맨몸만, 1-2부터 전 직업 해금. 잠긴 직업은 반투명 + 비활성.
		var unlocked: bool = (job == "base") or GameState.jobs_unlocked
		btn.disabled = not unlocked
		box.modulate = Color(1, 1, 1, 1.0) if unlocked else Color(1, 1, 1, 0.35)
		if not unlocked:
			btn.text = GameState.job_title(job) + " (잠김)"
		_style_primary(btn)   # 모든 직업 버튼 = 오렌지 메인 CTA로 통일
		btn.pressed.connect(_pick.bind(job))
		if unlocked:
			btn.mouse_entered.connect(_on_hover.bind(job))
			btn.mouse_exited.connect(_on_unhover.bind(job))


## [테스트 치트] 숫자 0 키 → 잠긴 직업까지 전부 선택 가능
func _input(event: InputEvent) -> void:
	if _test_unlocked:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_0 or event.keycode == KEY_KP_0):
		_test_unlocked = true
		for job in JOBS:
			var was_unlocked: bool = (job == "base") or GameState.jobs_unlocked
			var box: Control = $Center/Box/Row.get_node(job)
			var btn: Button = box.get_node("Btn")
			btn.disabled = false
			box.modulate = Color(1, 1, 1, 1.0)
			btn.text = GameState.job_title(job)
			_style_primary(btn)   # 치트 해금된 직업도 메인 컬러로
			if not was_unlocked:   # 원래 잠겨있던 직업만 호버 연결(중복 방지)
				btn.mouse_entered.connect(_on_hover.bind(job))
				btn.mouse_exited.connect(_on_unhover.bind(job))
		$Center/Box/Title.text = "스테이지 %s — [테스트] 전 직업 해금" % GameState.stage_label()


func _process(delta: float) -> void:
	if _hover == "":
		return
	var sf: SpriteFrames = _sf.get(_hover)
	if sf == null:
		return
	var n := sf.get_frame_count("idle")
	if n <= 1:
		return
	_t += delta
	if _t >= 1.0 / IDLE_FPS:
		_t -= 1.0 / IDLE_FPS
		_frame = (_frame + 1) % n
		_preview[_hover].texture = sf.get_frame_texture("idle", _frame)


func _on_hover(job: String) -> void:
	_hover = job
	_frame = 0
	_t = 0.0


func _on_unhover(job: String) -> void:
	if _hover == job:
		_hover = ""
		var sf: SpriteFrames = _sf.get(job)
		if sf and sf.has_animation("idle"):
			_preview[job].texture = sf.get_frame_texture("idle", 0)   # 첫 프레임으로 복귀


## 등급 라벨 텍스트 + 색 적용 (맨몸은 숨김)
func _set_rank_label(rank: Label, job: String) -> void:
	var txt := GameState.rank_label(job)
	if txt == "":
		rank.visible = false
	else:
		rank.visible = true
		rank.text = "「" + txt + "」"
		rank.add_theme_color_override("font_color", GameState.rank_color(job))


func _pick(job: String) -> void:
	GameState.selected_job = job
	get_tree().change_scene_to_file("res://scenes/main.tscn")
