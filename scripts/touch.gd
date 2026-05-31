extends Node
## 터치 입력 공용 모듈 (오토로드 싱글톤 "Touch")
## 가상 조이스틱/버튼이 여기에 값을 쓰고, 플레이어가 읽어간다.

var move_axis: float = 0.0       # 좌우 이동(-1 왼쪽 ~ +1 오른쪽), 조이스틱이 갱신
var attack_held: bool = false    # 공격 버튼을 누르고 있는 중인지(연사용)
var _jump_queued: bool = false


## 점프 요청(조이스틱 탭 등에서 호출)
func request_jump() -> void:
	_jump_queued = true


## 점프 요청을 한 번 가져간다(있으면 true, 가져가면 비워짐)
func consume_jump() -> bool:
	if _jump_queued:
		_jump_queued = false
		return true
	return false
