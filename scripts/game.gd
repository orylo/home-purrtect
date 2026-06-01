extends Node2D
## 게임 코디네이터 (Main) — 스포너/플레이어 신호를 받아 클리어·게임오버를 연출.

@onready var spawner: Node = $Spawner
@onready var player: Node = $Player
@onready var hud: Node = $HUD
@onready var bg: CanvasLayer = $BG


func _ready() -> void:
	randomize()   # 매 판 적의 리듬·등장이 달라지게
	spawner.wave_started.connect(hud.set_wave)
	spawner.stage_cleared.connect(_on_stage_cleared)
	player.died.connect(_on_player_died)


func _process(delta: float) -> void:
	# 화면 흔들림 — 월드(Main)와 배경(BG)을 같이 흔들고 HUD는 고정
	var off := Vector2.ZERO
	if Fx.shake > 0.0:
		Fx.shake = move_toward(Fx.shake, 0.0, 45.0 * delta)
		off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Fx.shake
	position = off
	bg.offset = off


func _on_stage_cleared() -> void:
	var bonus := GameState.award_stage_clear()   # 첫 클리어 보너스 코인(파밍은 0)
	get_tree().paused = true
	hud.show_clear(bonus)


func _on_player_died() -> void:
	get_tree().paused = true
	hud.show_gameover()
