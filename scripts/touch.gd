extends Node
## 터치 입력 공용 모듈 (오토로드 싱글톤 "Touch")
## 가상 조이스틱/버튼이 여기에 값을 쓰고, 플레이어가 읽어간다.

var move_axis: float = 0.0       # 좌우 이동(-1 왼쪽 ~ +1 오른쪽), 조이스틱이 갱신
var melee_held: bool = false     # 근접 공격 버튼을 누르고 있는 중
var ranged_held: bool = false    # 원거리 공격 버튼을 누르고 있는 중
var crouch_held: bool = false    # 조이스틱을 아래로 당겨 앉기(회피) 중인지
var _jump_queued: bool = false

## UI 차단 영역(디버그 오버레이 등) — 이 컨트롤들 위 터치는 조이스틱/점프로 새지 않게.
var _block_controls: Array = []


## 차단할 Control 등록(보이는 동안만 차단). 디버그 오버레이가 _ready에서 등록.
func register_block(c: Control) -> void:
	if c != null and not _block_controls.has(c):
		_block_controls.append(c)


## 화면좌표 pos가 차단 컨트롤(보임) 위인가? 무효 노드는 자동 정리.
func is_blocked(pos: Vector2) -> bool:
	var blocked := false
	for i in range(_block_controls.size() - 1, -1, -1):
		var c = _block_controls[i]
		if not is_instance_valid(c):
			_block_controls.remove_at(i)
			continue
		if c.visible and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			blocked = true
	return blocked


## 점프 요청(조이스틱 탭 등에서 호출)
func request_jump() -> void:
	_jump_queued = true


## 점프 요청을 한 번 가져간다(있으면 true, 가져가면 비워짐)
func consume_jump() -> bool:
	if _jump_queued:
		_jump_queued = false
		return true
	return false
