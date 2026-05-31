extends Node2D
## 게임 코디네이터 (Main) — 스포너/플레이어 신호를 받아 클리어·게임오버를 연출.

@onready var spawner: Node = $Spawner
@onready var player: Node = $Player
@onready var hud: Node = $HUD


func _ready() -> void:
	spawner.wave_started.connect(hud.set_wave)
	spawner.stage_cleared.connect(_on_stage_cleared)
	player.died.connect(_on_player_died)


func _on_stage_cleared() -> void:
	get_tree().paused = true
	hud.show_clear()


func _on_player_died() -> void:
	get_tree().paused = true
	hud.show_gameover()
