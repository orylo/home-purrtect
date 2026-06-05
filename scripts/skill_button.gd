extends Control
## 전투 중 스킬 발동 (로드맵 5단계) - HUD 스킬칸 1~4 (터치/클릭) + 키 skill_1~4.
##   장착 슬롯(GameState.equipped_for(현재 직업))대로 발동, 슬롯별 쿨타임.
##   효과는 전부 placeholder(색 플래시 + 실제 게임플레이 효과). 그림은 bottom_hud가 그림.

var _cd := [0.0, 0.0, 0.0, 0.0]       # 슬롯별 남은 쿨타임
var _cd_max := [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	for i in range(4):
		if _cd[i] > 0.0:
			_cd[i] -= delta
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			_try(i)


func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
	else:
		return
	var skills: Array = Layout.bottom_row(size)["skills"]
	for i in skills.size():
		if pos.distance_to(skills[i]) <= Layout.SKILL_BTN_R:
			_try(i)
			break


## bottom_hud가 쿨다운 표시에 사용
func cd_left(i: int) -> float:
	return _cd[i] if i >= 0 and i < 4 else 0.0


func _try(slot: int) -> void:
	if slot < 0 or slot >= 4 or _cd[slot] > 0.0:
		return
	var eq: Array = GameState.equipped_for(GameState.selected_job)
	if slot >= eq.size():
		return
	var sid: String = eq[slot]
	if not GameState.SKILLS.has(sid):
		return
	_activate(sid)
	var cd := float(GameState.SKILLS[sid]["cd"])
	_cd[slot] = cd
	_cd_max[slot] = cd


func _activate(sid: String) -> void:
	var s: Dictionary = GameState.SKILLS[sid]
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var val := GameState.skill_value(sid)
	var kind := String(s["kind"])
	match kind:
		"guard":      player.apply_guard(float(s["dur"]), float(s["pct"]))
		"selfbuff":   player.apply_encore(float(s["dur"]))
		"platestorm": player.aoe_damage(val)
		"barrage":    _barrage(player, val, float(s.get("delay", 1.0)))
		_:
			for e in _alive(kind == "stagger"):
				match kind:
					"stagger":   e.take_damage(1.0, 140.0, float(s["dur"]), false)
					"knockback": e.take_damage(val, 320.0, 0.0, false)
					"slowfield":
						if e.has_method("apply_slow"):
							e.apply_slow(float(s["dur"]), 1.0 - float(s["pct"]))
					"aoe_slow":
						e.take_damage(val, 60.0, 0.0, false)
						if e.has_method("apply_slow"):
							e.apply_slow(float(s["slow_dur"]), 0.5)
					"stun":
						if e.has_method("apply_stun"):
							e.apply_stun(float(s["dur"]))
	_flash(_skill_color(sid))
	Fx.request_shake(6.0)


## 지원 요청: delay초 후 화면 전체 광역딜
func _barrage(player: Node, amount: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(player) and player.has_method("aoe_damage"):
		player.aoe_damage(amount)
		_flash(Color(0.3, 0.5, 1.0))
		Fx.request_shake(9.0)


## 살아있는 적(앞쪽만 옵션)
func _alive(front_only: bool) -> Array:
	var player := get_tree().get_first_node_in_group("player")
	var px: float = (player as Node2D).global_position.x if player else -99999.0
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if front_only and (e as Node2D).global_position.x < px:
			continue
		out.append(e)
	return out


## placeholder 화면 색 플래시
func _flash(c: Color) -> void:
	var r := ColorRect.new()
	r.color = Color(c.r, c.g, c.b, 0.28)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.35)
	tw.tween_callback(r.queue_free)


func _skill_color(sid: String) -> Color:
	match String(GameState.SKILLS[sid]["job"]):
		"sheriff": return Color(0.3, 0.5, 1.0)
		"maid":    return Color(0.3, 0.9, 0.7)
		"jazz":    return Color(0.85, 0.4, 1.0)
	return Color(1, 1, 1)
