extends Control
## 공격 버튼 입력 — 우하단 코너 1/4 원 영역.
## 누르고 있는 동안 Touch.attack_held = true (연사). 그림은 bottom_hud가 그린다.

var _active: bool = false
var _touch_index: int = -99   # 멀티터치 구분(어느 손가락이 공격인지)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle(event.pressed, event.position, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle(event.pressed, event.position, -1)


func _handle(pressed: bool, pos: Vector2, index: int) -> void:
	if pressed:
		if not _active and _in_zone(pos):
			_active = true
			_touch_index = index
			Touch.attack_held = true
	else:
		if _active and index == _touch_index:
			_active = false
			_touch_index = -99
			Touch.attack_held = false


func _in_zone(pos: Vector2) -> bool:
	var corner := Vector2(size.x, size.y)
	return pos.distance_to(corner) <= Layout.ATTACK_BUTTON_RADIUS
