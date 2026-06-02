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
@onready var clear_title: Label = $ClearPanel/Center/Box/Title
@onready var clear_next: Button = $ClearPanel/Center/Box/Next
@onready var clear_restart: Button = $ClearPanel/Center/Box/Restart
@onready var gameover_panel: ColorRect = $GameOverPanel
@onready var gameover_restart: Button = $GameOverPanel/Center/Box/Restart

var _wave_cur: int = 0
var _wave_total: int = 0
var _event_pending: bool = false   # 클리어 이벤트 [확인] 대기 중
var _event_text: String = ""
var coin_label: Label   # 상단 코인 표시(💰)


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	to_select_button.pressed.connect(_on_to_select_pressed)
	clear_next.pressed.connect(_on_clear_next)
	clear_restart.text = "홈으로"                  # 클리어 패널: 재시작 버튼을 홈으로 전환
	clear_restart.pressed.connect(_on_clear_home)
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
	_build_coin_label()


## 상단 코인 표시 — DoHyeon에 동전 이모지가 없어 금색 "코인 N"으로(숫자는 항상 렌더)
func _build_coin_label() -> void:
	coin_label = Label.new()
	coin_label.add_theme_font_override("font", UI_FONT)
	coin_label.add_theme_font_size_override("font_size", 26)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	coin_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	coin_label.add_theme_constant_override("outline_size", 4)
	coin_label.position = Vector2(44, 62)   # HP바 아래 좌상단
	add_child(coin_label)


## 숫자 천 단위 콤마 (1240 → 1,240)
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
	if coin_label:
		coin_label.text = "코인 " + _commafy(GameState.coins)

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


func show_clear(bonus: int = 0) -> void:
	var msg := "스테이지 클리어!"
	if bonus > 0:
		msg += "\n첫 클리어 보너스 +%d 코인" % bonus
	var loot := GameState.run_loot_summary()
	if loot != "":
		msg += "\n전리품: " + loot           # #2: 이번 판 얻은 전리품 표시
	else:
		msg += "\n전리품: 없음"
	msg += "\n보유 코인 %s" % _commafy(GameState.coins)
	clear_title.text = msg
	# #4: 해금 이벤트 스테이지면 [확인] 강제 후 진행 (로드맵 2-B)
	var ev := GameState.clear_event_for(GameState.stage_minor)
	if ev != "":
		_event_pending = true
		_event_text = ev
		clear_next.text = "확인 ▶"
		clear_restart.visible = false
	else:
		_event_pending = false
		clear_next.text = "다음 ▶"
		clear_restart.visible = true
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
	if GameState.mode == "dev":
		get_tree().change_scene_to_file("res://scenes/dev_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/home.tscn")   # 전투 포기 → 홈


## [다음 ▶ / 확인 ▶] — 이벤트 스테이지면 첫 탭은 이벤트 실행(placeholder), 그 뒤 진행 열림
func _on_clear_next() -> void:
	if _event_pending:
		_event_pending = false
		clear_title.text += "\n\n● " + _event_text   # 이벤트 placeholder 안내
		clear_next.text = "다음 ▶"
		clear_restart.visible = true
		return
	get_tree().paused = false
	GameState.advance_stage()
	if GameState.mode != "dev" and GameState.AUTOSAVE:
		GameState.save_game()                                      # (출시 빌드) 진행 저장
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## [홈으로] — 클리어 후 허브로 (개발자 모드는 개발자 메뉴로)
func _on_clear_home() -> void:
	get_tree().paused = false
	GameState.advance_stage()
	if GameState.mode != "dev" and GameState.AUTOSAVE:
		GameState.save_game()
	if GameState.mode == "dev":
		get_tree().change_scene_to_file("res://scenes/dev_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/home.tscn")


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
