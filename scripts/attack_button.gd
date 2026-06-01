extends Control
## 근접/원거리 공격 버튼 입력 — 우하단 두 원형 버튼(좌=근접, 우=원거리).
## 누르고 있는 동안 Touch.melee_held / Touch.ranged_held = true (연사).
## 그림은 bottom_hud가 그린다. 좌표는 Layout이 공유.

var _melee_idx: int = -99     # 근접 버튼을 누른 손가락 index
var _ranged_idx: int = -99    # 원거리 버튼을 누른 손가락 index


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle(event.pressed, event.position, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle(event.pressed, event.position, -1)


func _handle(pressed: bool, pos: Vector2, index: int) -> void:
	if pressed:
		var row := Layout.bottom_row(size)
		if _melee_idx == -99 and _in(pos, row["melee"]):
			_melee_idx = index
			Touch.melee_held = true
		elif _ranged_idx == -99 and _in(pos, row["ranged"]):
			_ranged_idx = index
			Touch.ranged_held = true
	else:
		if index == _melee_idx:
			_melee_idx = -99
			Touch.melee_held = false
		elif index == _ranged_idx:
			_ranged_idx = -99
			Touch.ranged_held = false


func _in(pos: Vector2, center: Vector2) -> bool:
	return pos.distance_to(center) <= Layout.ACT_R
