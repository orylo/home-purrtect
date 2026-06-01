extends CanvasLayer
## 전투 HUD — 상단 정보바 + 일시정지/클리어/게임오버 패널
##   좌: ♥ 체력 + 숫자 / 우: 웨이브·남은 적 + 일시정지[II]

# 웹 export에서 테마 기본폰트가 한글을 못 그려서, 폰트를 직접 preload해 명시 지정
const UI_FONT := preload("res://assets/fonts/DoHyeon-Regular.ttf")

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_value: Label = $HPBar/HPValue
@onready var enemy_label: Label = $EnemyLabel
@onready var pause_button: Button = $PauseButton
@onready var pause_panel: ColorRect = $PausePanel
@onready var resume_button: Button = $PausePanel/Center/Box/ResumeButton
@onready var to_select_button: Button = $PausePanel/Center/Box/ToSelectButton
@onready var stage_label: Label = $StageLabel
@onready var clear_panel: ColorRect = $ClearPanel
@onready var clear_next: Button = $ClearPanel/Center/Box/Next
@onready var clear_restart: Button = $ClearPanel/Center/Box/Restart
@onready var gameover_panel: ColorRect = $GameOverPanel
@onready var gameover_restart: Button = $GameOverPanel/Center/Box/Restart

var _wave_cur: int = 0
var _wave_total: int = 0


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	to_select_button.pressed.connect(_on_to_select_pressed)
	clear_next.pressed.connect(_on_clear_next)
	clear_restart.pressed.connect(_on_restart)
	gameover_restart.pressed.connect(_on_restart)
	stage_label.text = GameState.stage_label()   # 상단 스테이지 표시(1-1, 1-2…)
	pause_panel.visible = false
	clear_panel.visible = false
	gameover_panel.visible = false
	# Caldera 규정 버튼: 주요 액션=Digital Orange 알약 / 보조=고스트(흰 테두리)
	_style_primary(resume_button)
	_style_ghost(to_select_button)
	_style_primary(clear_next)
	_style_ghost(clear_restart)
	_style_primary(gameover_restart)


## 알약(pill) 스타일 박스 — bw>0이면 테두리(고스트)
func _pill(bg: Color, bw: float, bc: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(100)
	sb.content_margin_left = 32.0
	sb.content_margin_right = 32.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	if bw > 0.0:
		sb.set_border_width_all(int(bw))
		sb.border_color = bc
	return sb


func _style_primary(btn: Button) -> void:
	btn.add_theme_font_override("font", UI_FONT)
	var o := Color(0.9882, 0.3137, 0.0)
	var oh := Color(0.86, 0.27, 0.0)
	btn.add_theme_stylebox_override("normal", _pill(o, 0.0, o))
	btn.add_theme_stylebox_override("hover", _pill(oh, 0.0, oh))
	btn.add_theme_stylebox_override("pressed", _pill(oh, 0.0, oh))
	btn.add_theme_stylebox_override("focus", _pill(o, 0.0, o))
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))


func _style_ghost(btn: Button) -> void:
	btn.add_theme_font_override("font", UI_FONT)
	btn.add_theme_stylebox_override("normal", _pill(Color(1, 1, 1, 0.0), 2.5, Color(1, 1, 1, 0.9)))
	btn.add_theme_stylebox_override("hover", _pill(Color(1, 1, 1, 0.14), 2.5, Color(1, 1, 1, 1)))
	btn.add_theme_stylebox_override("pressed", _pill(Color(1, 1, 1, 0.2), 2.5, Color(1, 1, 1, 1)))
	btn.add_theme_stylebox_override("focus", _pill(Color(1, 1, 1, 0.0), 2.5, Color(1, 1, 1, 0.9)))
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))


func _process(_delta: float) -> void:
	# 치즈 체력
	var player := get_tree().get_first_node_in_group("player")
	if player:
		hp_bar.max_value = player.max_health
		hp_bar.value = player.health
		hp_value.text = "%d / %d" % [int(round(player.health)), int(round(player.max_health))]

	# 웨이브 + 남은 적
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		alive += 1
	if _wave_total == 0:
		enemy_label.text = "준비 중..."
	else:
		enemy_label.text = "웨이브 %d/%d   남은 적 %d" % [_wave_cur, _wave_total, alive]


## 스포너가 새 웨이브 시작 시 호출
func set_wave(current: int, total: int) -> void:
	_wave_cur = current
	_wave_total = total


func show_clear() -> void:
	clear_panel.visible = true


func show_gameover() -> void:
	gameover_panel.visible = true


func _on_pause_pressed() -> void:
	get_tree().paused = true
	pause_panel.visible = true


func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_panel.visible = false


func _on_to_select_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/select.tscn")


## 클리어 → 다음 스테이지(직업 해금) → 직업 선택 화면
func _on_clear_next() -> void:
	get_tree().paused = false
	if GameState.mode == "dev":
		get_tree().change_scene_to_file("res://scenes/dev_menu.tscn")   # 개발자: 메뉴 복귀
	else:
		GameState.advance_stage()
		if GameState.AUTOSAVE:
			GameState.save_game()                                      # (출시 빌드) 진행 저장
		get_tree().change_scene_to_file("res://scenes/select.tscn")


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
