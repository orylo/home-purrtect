extends Node2D
## 적 스포너 — 웨이브 기반 (Phase 4)
##
## 웨이브마다 정해진 수의 적을 일정 간격으로 등장시킨다.
## 한 웨이브의 적을 다 잡으면(전부 처치) 잠깐 쉬고 다음 웨이브.
## 마지막 웨이브까지 클리어하면 stage_cleared 신호 → 스테이지 클리어.

signal wave_started(current: int, total: int)
signal stage_cleared

@export var enemy_scene: PackedScene
@export var spawn_offscreen: float = 140.0   # 화면 밖 오른쪽 이만큼에서 등장
@export var inter_wave_delay: float = 2.0     # 웨이브 사이 쉬는 시간(초)
@export var start_delay: float = 1.5          # 첫 웨이브까지 대기(초)

## 웨이브 구성: 각 웨이브의 적 수와 등장 간격 (점점 많아짐 — 시스템밸런스 점증)
var _waves: Array = [
	{"count": 3, "interval": 2.0},
	{"count": 4, "interval": 1.6},
	{"count": 5, "interval": 1.3},
]

var _state: String = "delay"   # delay → spawning → cleared
var _wave_index: int = -1
var _to_spawn: int = 0
var _spawn_timer: float = 0.0
var _delay_timer: float = 0.0


func _ready() -> void:
	_delay_timer = start_delay
	_state = "delay"


func _process(delta: float) -> void:
	match _state:
		"delay":
			_delay_timer -= delta
			if _delay_timer <= 0.0:
				_start_next_wave()
		"spawning":
			if _to_spawn > 0:
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					# 등장 간격도 ±20% 흩어 단조롭지 않게
					_spawn_timer = float(_waves[_wave_index]["interval"]) * randf_range(0.8, 1.2)
					_spawn_one()
					_to_spawn -= 1
			elif _alive_count() == 0:
				# 이 웨이브의 적을 다 잡음
				if _wave_index + 1 < _waves.size():
					_state = "delay"
					_delay_timer = inter_wave_delay
				else:
					_state = "cleared"
					stage_cleared.emit()


func _start_next_wave() -> void:
	_wave_index += 1
	var base_count := int(_waves[_wave_index]["count"])
	_to_spawn = int(ceil(base_count * GameState.cheats.get("enemy_count_mult", 1.0)))   # 치트: 적 수 배율
	_spawn_timer = 0.0
	_state = "spawning"
	wave_started.emit(_wave_index + 1, _waves.size())


func _alive_count() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		n += 1
	return n


func _spawn_one() -> void:
	if enemy_scene == null:
		return
	var enemy := enemy_scene.instantiate()
	var screen_width := get_viewport_rect().size.x
	enemy.position = Vector2(screen_width + spawn_offscreen, Layout.ground_y())
	get_parent().add_child(enemy)
