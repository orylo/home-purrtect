extends Node2D
## 적 스포너 — 오른쪽 끝에서 적을 주기적으로 등장시킨다.
##
## ※ 이번 단계는 간단히 "정해진 수만큼 일정 간격으로 쥐 등장"까지.
##   제대로 된 웨이브 시스템(수량↑→종류 혼합→정예)은 Phase 4에서.

@export var enemy_scene: PackedScene      # 등장시킬 적(쥐 씬)
@export var spawn_interval: float = 2.5    # 등장 간격(초)
@export var max_count: int = 6             # 총 몇 마리 등장시킬지
@export var spawn_margin: float = 60.0     # 오른쪽 끝에서 이만큼 안쪽에서 등장
@export var ground_y: float = 620.0        # 바닥 높이(치즈와 같은 라인)

var _timer: float = 1.0   # 시작 후 첫 등장까지 약간의 여유
var _spawned: int = 0


func _process(delta: float) -> void:
	if enemy_scene == null or _spawned >= max_count:
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_spawn_one()


func _spawn_one() -> void:
	var enemy := enemy_scene.instantiate()
	var screen_width := get_viewport_rect().size.x
	enemy.position = Vector2(screen_width - spawn_margin, ground_y)
	get_parent().add_child(enemy)
	_spawned += 1
