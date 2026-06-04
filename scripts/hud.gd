extends CanvasLayer
## 전투 HUD — 상단 정보바 + 일시정지/클리어/게임오버 패널
##   좌: ♥ 체력 + 숫자 / 우: 웨이브·남은 적 + 일시정지[II]

## 전투결과 [확인]을 눌렀고, 그 스테이지가 "전투 씬 내 컷씬"이면 발신(game.gd가 받아 처리).
signal inscene_event_requested

# 전투 씬 안에서(씬전환 없이) 컷씬 재생(케이스 A: 1-3 보안관·1-5 펄·1-7 맥스·1-13 비둘기·1-16 치와와)
const INSCENE_EVENT_STAGES := [3, 5, 7, 13, 16]
# 컷씬 없이 [확인]→홈+코치마크(케이스 D+: 1-9 스킬 판매)
const HOME_EVENT_STAGES := [9]

# 웹 export에서 테마 기본폰트가 한글을 못 그려서, 폰트를 직접 preload해 명시 지정
const UI_FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")

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
var _inscene_event: bool = false   # 그 이벤트가 "전투 씬 내 컷씬"인지
var _home_event: bool = false      # 컷씬 없이 홈+코치마크(D+)
var coin_label: Label   # 상단 코인 표시(💰)
var _time_label: Label  # 별점용 전투 경과시간(상단 중앙, 작게)


## 전투 경과시간 표시(game._process가 매 프레임 호출). 라벨은 첫 호출 때 생성.
func set_battle_time(t: float) -> void:
	if _time_label == null:
		_time_label = Label.new()
		_time_label.add_theme_font_override("font", UI_FONT)
		_time_label.add_theme_font_size_override("font_size", 20)
		_time_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_time_label.add_theme_color_override("font_outline_color", Color("241f1b"))
		_time_label.add_theme_constant_override("outline_size", 4)
		_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var vp := get_viewport().get_visible_rect().size
		_time_label.size = Vector2(140, 26)
		_time_label.position = Vector2(vp.x * 0.5 - 70, 58)   # 스테이지 표기 아래, 가운데
		add_child(_time_label)
	_time_label.text = "%.1f초" % t


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	# 일시정지 = 빈티지 아이콘 뱃지(나노바나나, 자체 크림 원형이라 버튼 배경은 투명)
	pause_button.text = ""
	pause_button.icon = preload("res://assets/ui/icons/icon_pause.png")
	pause_button.expand_icon = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		pause_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
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


## 상단 코인 표시 — 동전 이모지 대신 금색 "코인 N"으로(숫자는 항상 렌더)
func _build_coin_label() -> void:
	coin_label = Label.new()
	coin_label.add_theme_font_override("font", UI_FONT)
	coin_label.add_theme_font_size_override("font_size", 26)
	coin_label.add_theme_color_override("font_color", Design.CHEESE)
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
	Design.style_button(btn, "cta", Design.FS_TITLE)   # 빨강 CTA(design.md)


func _style_ghost(btn: Button) -> void:
	Design.style_button(btn, "paper", Design.FS_TITLE)   # 보조 = 크림


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
		enemy_label.text = "웨이브 %d/%d   남은 침입자 %d" % [_wave_cur, _wave_total, alive]


## 스포너가 새 웨이브 시작 시 호출
func set_wave(current: int, total: int) -> void:
	_wave_cur = current
	_wave_total = total


func show_clear(bonus: int = 0, star_info: Dictionary = {}) -> void:
	Sfx.play("clear")
	var msg := "스테이지 클리어!"
	# ★ 별점 — 딴 별 + 클리어 시간(맨 위 강조)
	if not star_info.is_empty():
		var s := int(star_info.get("stars", 1))
		msg += "\n%s   (★%d/3)   %.1f초" % ["★".repeat(s) + "·".repeat(3 - s), s, float(star_info.get("time", 0.0))]
	if bonus > 0:
		msg += "\n첫 클리어 보너스 +%d 코인" % bonus
	# 별 차등 보석 / 구간 올스타 보석
	if not star_info.is_empty():
		var fg := String(star_info.get("first_gem", ""))
		if fg != "" and GameState.MATERIALS.has(fg):
			msg += "\n[별 보상] %s ×1 획득!" % String(GameState.MATERIALS[fg]["name"])
		for a in star_info.get("allstar", []):
			var gid := String(a["gem"])
			if GameState.MATERIALS.has(gid):
				msg += "\n[구간 올스타] %s ×1 획득!" % String(GameState.MATERIALS[gid]["name"])
	var loot := GameState.run_loot_summary()
	if loot != "":
		msg += "\n전리품: " + loot           # #2: 이번 판 얻은 전리품 표시
	else:
		msg += "\n전리품: 없음"
	msg += "\n보유 코인 %s" % _commafy(GameState.coins)
	var stg := GameState.stage_minor
	var ev := GameState.clear_event_for(stg)
	# 알림형(D/D+): 드랍 정산 결과창 하단에 해금 알림 한 줄(드랍과 사건 분리 — 가이드 §1-B).
	#   인스씬 컷씬(A)·보스(C)는 사건을 컷씬/별도 씬이 알리므로 결과창엔 안 얹음.
	var show_notice := ev != "" and not (stg in INSCENE_EVENT_STAGES) and not (stg in [10, 20])
	if show_notice:
		msg += "\n\n✨ " + ev
	clear_title.text = msg
	# 라우팅: 인스씬 컷씬(A) / 홈+코치마크(D+) / 별도 알림씬(보스 등) / 일반(D·없음)
	if stg in INSCENE_EVENT_STAGES:
		_event_pending = true; _inscene_event = true; _home_event = false
		clear_next.text = "확인 ▶"; clear_restart.visible = false
	elif stg in HOME_EVENT_STAGES:
		_event_pending = true; _inscene_event = false; _home_event = true
		clear_next.text = "확인 ▶"; clear_restart.visible = false
	elif ev != "" and (stg in [10, 20]):     # 보스(C) — 추후 컷씬, 현재 별도 알림 씬
		_event_pending = true; _inscene_event = false; _home_event = false
		_event_text = ev; clear_next.text = "확인 ▶"; clear_restart.visible = false
	else:                                    # D(알림만) 또는 이벤트 없음 — 일반 진행
		_event_pending = false; _inscene_event = false; _home_event = false
		clear_next.text = "다음 ▶"; clear_restart.visible = true
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


## [다음 ▶ / 확인 ▶] — 이벤트 스테이지면 [확인]→이벤트 씬으로 랜딩, 아니면 다음 스테이지
func _on_clear_next() -> void:
	# 전투 씬 내 컷씬(보안관 등): 씬전환·언포즈 없이 결과창만 닫고 game.gd에 위임
	if _inscene_event:
		_inscene_event = false
		_event_pending = false
		clear_panel.visible = false
		inscene_event_requested.emit()
		return
	get_tree().paused = false
	# D+(1-9 등): 컷씬 없이 홈으로 → 홈에서 코치마크.
	if _home_event:
		_home_event = false
		_event_pending = false
		GameState.advance_stage()
		if GameState.mode != "dev" and GameState.AUTOSAVE:
			GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/home.tscn")
		return
	if _event_pending:
		_event_pending = false
		GameState.pending_event_stage = GameState.stage_minor   # 방금 깬 스테이지(이벤트 씬이 읽음)
		GameState.advance_stage()
		if GameState.mode != "dev" and GameState.AUTOSAVE:
			GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/event.tscn")   # 이벤트 씬 랜딩
		return
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
