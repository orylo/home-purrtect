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

## 웨이브 구성: 현재 스테이지(GameState.stage_minor)의 §6-B 데이터를 Enemies에서 로드.
## 각 웨이브 = [[적id, 수], ...]
var _waves: Array = []
var _queue: Array = []         # 이번 웨이브에 남은 적 id 목록(섞어서 순서대로 등장)

var _state: String = "delay"   # delay → spawning → cleared
var _hold: bool = false         # 인트로 이벤트 중 대기
var _wave_index: int = -1
var _to_spawn: int = 0
var _spawn_timer: float = 0.0
var _delay_timer: float = 0.0


func _ready() -> void:
	if GameState.sandbox:
		_state = "idle"     # 테스트 스테이지: 자동 웨이브 없음(디버그 패널로 직접 스폰)
		return
	_waves = Enemies.waves_for(GameState.stage_minor)
	_delay_timer = start_delay
	_state = "delay"


## 인트로 이벤트 동안 웨이브 진행을 멈춰둔다(StageIntro가 제어).
func hold_intro() -> void:
	_hold = true

func release_intro() -> void:
	_hold = false


func _process(delta: float) -> void:
	if _hold:
		return
	match _state:
		"delay":
			_delay_timer -= delta
			if _delay_timer <= 0.0:
				_start_next_wave()
		"spawning":
			if _to_spawn > 0:
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					_spawn_timer = _wave_interval() * randf_range(0.8, 1.2)
					_spawn_one()
					_to_spawn -= 1
			elif _alive_count() == 0:
				if _wave_index + 1 < _waves.size():
					_state = "delay"
					_delay_timer = inter_wave_delay
				else:
					_state = "cleared"
					stage_cleared.emit()


## 후반 웨이브일수록 등장 간격 짧게(점증)
func _wave_interval() -> float:
	return clampf(1.8 - 0.18 * _wave_index, 0.9, 1.8)


func _start_next_wave() -> void:
	_wave_index += 1
	var mult: float = GameState.cheats.get("enemy_count_mult", 1.0)   # 치트: 적 수 배율
	_queue.clear()
	for entry in _waves[_wave_index]:        # entry = [id, count]
		var id := String(entry[0])
		var c := int(ceil(int(entry[1]) * mult))
		for i in c:
			_queue.append(id)
	_queue.shuffle()                          # 종류 섞어서 등장
	_to_spawn = _queue.size()
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
	if enemy_scene == null or _queue.is_empty():
		return
	var id: String = _queue.pop_back()
	var enemy := enemy_scene.instantiate()
	enemy.def = Enemies.def_of(id)            # 종류별 스탯·외형·행동 주입(_ready에서 적용)
	var screen_width := get_viewport_rect().size.x
	enemy.position = Vector2(screen_width + spawn_offscreen, Layout.ground_y())
	get_parent().add_child(enemy)
