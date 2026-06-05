extends Control
## 전투 중 소모품 사용 (로드맵 4단계) - 하단 아이템칸 1~3 (터치/클릭) + 키 1·2·3.
##   슬롯에 배치된 소모품(GameState.item_slots)을 보유(inventory)>0일 때 사용.
##   효과: 낡은 붕대=회복30 / 말린 멸치=공격버프 8s / 폭죽=광역60.
##   그림은 bottom_hud가 그림. 좌표는 Layout.bottom_row 공유. (attack_button 패턴)

const DEBOUNCE := 0.35   # 한 번 탭이 두 번 먹는 것 방지(쿨다운 아님 - 재고로 제한)

var _cd := [0.0, 0.0, 0.0]
var used = Callable()   # (선택) 사용 알림 콜백


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	for i in range(3):
		if _cd[i] > 0.0:
			_cd[i] -= delta
		if Input.is_action_just_pressed("item_%d" % (i + 1)):
			_use(i)


func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
	else:
		return
	var items: Array = Layout.bottom_row(size)["items"]
	for i in items.size():
		if _in_sq(pos, items[i]):
			_use(i)
			break


func _in_sq(pos: Vector2, center: Vector2) -> bool:
	var h := Layout.ITEM_SQ * 0.5
	return absf(pos.x - center.x) <= h and absf(pos.y - center.y) <= h


func _use(slot: int) -> void:
	if slot < 0 or slot >= 3 or _cd[slot] > 0.0:
		return
	var id: String = GameState.item_slots[slot]
	if id == "" or int(GameState.inventory.get(id, 0)) <= 0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	match id:
		"bandage":     player.heal(30.0)
		"anchovy":     player.apply_atk_buff(8.0)
		"firecracker": player.aoe_damage(60.0)
		_:             return
	GameState.inventory[id] = int(GameState.inventory[id]) - 1
	_cd[slot] = DEBOUNCE
