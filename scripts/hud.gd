extends CanvasLayer
## 전투 HUD — 상단 정보바 + 일시정지/클리어/게임오버 패널
##   좌: ♥ 체력 + 숫자 / 우: 웨이브·남은 적 + 일시정지[II]

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_value: Label = $HPBar/HPValue
@onready var enemy_label: Label = $EnemyLabel
@onready var pause_button: Button = $PauseButton
@onready var pause_panel: ColorRect = $PausePanel
@onready var resume_button: Button = $PausePanel/Center/Box/ResumeButton
@onready var to_select_button: Button = $PausePanel/Center/Box/ToSelectButton
@onready var clear_panel: ColorRect = $ClearPanel
@onready var clear_restart: Button = $ClearPanel/Center/Box/Restart
@onready var gameover_panel: ColorRect = $GameOverPanel
@onready var gameover_restart: Button = $GameOverPanel/Center/Box/Restart

var _wave_cur: int = 0
var _wave_total: int = 0


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	to_select_button.pressed.connect(_on_to_select_pressed)
	clear_restart.pressed.connect(_on_restart)
	gameover_restart.pressed.connect(_on_restart)
	pause_panel.visible = false
	clear_panel.visible = false
	gameover_panel.visible = false


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


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
