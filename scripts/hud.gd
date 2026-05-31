extends CanvasLayer
## 전투 HUD — 상단 정보바 (기획서 §7-B)
##   좌: ♥ 체력 게이지 + 숫자 / 우: 남은 적 수 + 일시정지 버튼[II]
##   일시정지 누르면 게임이 멈추고 패널 표시 → 계속하기로 재개.
##
## ※ 스킬·소모품·동료 버튼(하단)과 웨이브 N/M는 해당 시스템이 생기면 추가.

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_value: Label = $HPBar/HPValue
@onready var enemy_label: Label = $EnemyLabel
@onready var pause_button: Button = $PauseButton
@onready var pause_panel: ColorRect = $PausePanel
@onready var resume_button: Button = $PausePanel/Center/Box/ResumeButton


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	pause_panel.visible = false


func _process(_delta: float) -> void:
	# 치즈 체력 표시
	var player := get_tree().get_first_node_in_group("player")
	if player:
		hp_bar.max_value = player.max_health
		hp_bar.value = player.health
		hp_value.text = "%d / %d" % [int(round(player.health)), int(round(player.max_health))]

	# 남은 적 수(살아있는 것만)
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		alive += 1
	enemy_label.text = "남은 적: %d" % alive


func _on_pause_pressed() -> void:
	get_tree().paused = true
	pause_panel.visible = true


func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_panel.visible = false
