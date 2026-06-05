extends Control
## 전투 중 동료 호출 (로드맵 6단계, §5.5-B) ─ 하단 동료칸(터치/클릭) + 키 4.
##   장착 동료(GameState.equipped_companion) 호출, 쿨타임. placeholder 효과(색 플래시 + 실제 효과).
##   비둘기 = 전방 광역 둔화+딜(공중·지상) / 치와와 = 지상 적 전부 오른쪽으로 밀기.

var _cd := 0.0
var _cd_max := 0.0
var _was_key := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta
	var k := Input.is_key_pressed(KEY_4)
	if k and not _was_key:
		_try()
	_was_key = k


func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
	else:
		return
	var c: Vector2 = Layout.bottom_row(size)["companion"]
	if pos.distance_to(c) <= Layout.ACT_R:
		_try()


func cd_left() -> float:
	return _cd


func _try() -> void:
	if _cd > 0.0:
		return
	var id: String = GameState.equipped_companion
	if id == "" or not GameState.COMPANIONS.has(id):
		return
	_summon(id)
	var cd := float(GameState.COMPANIONS[id]["cd"])
	_cd = cd
	_cd_max = cd


func _summon(id: String) -> void:
	var c: Dictionary = GameState.COMPANIONS[id]
	var dmg := float(c.get("dmg", 0.0))
	match String(c["kind"]):
		"dove_bomb":
			for e in _alive(false):
				e.take_damage(dmg, 0.0, 0.0, false)
				if e.has_method("apply_slow"):
					e.apply_slow(float(c["slow_dur"]), 1.0 - float(c["slow_pct"]))
			_flash(Color(0.7, 0.85, 1.0))
			_dove_actor()
		"dog_charge":
			for e in _alive(true):   # 지상만(공중 제외)
				e.take_damage(dmg, 760.0, 0.0, false)   # 강한 우측 넉백 = 밀어내기
			_flash(Color(0.95, 0.8, 0.5))
			_dog_actor()
	Fx.request_shake(6.0)


## placeholder: 비둘기가 좌→우로 날며 똥 떨굼
func _dove_actor() -> void:
	var vp := get_viewport_rect().size
	var gy := Layout.ground_y()
	var bird := ColorRect.new()
	bird.color = Color(0.8, 0.85, 0.95); bird.size = Vector2(44, 26)
	bird.position = Vector2(vp.x * 0.18, gy - 360)
	add_child(bird)
	create_tween().tween_property(bird, "position:x", vp.x * 0.82, 0.8).finished.connect(bird.queue_free)
	for i in range(4):
		var d := ColorRect.new()
		d.color = Color(0.5, 0.4, 0.25); d.size = Vector2(13, 13)
		d.position = Vector2(vp.x * (0.30 + 0.12 * i), gy - 340)
		add_child(d)
		create_tween().tween_property(d, "position:y", gy - 50, 0.5).finished.connect(d.queue_free)


## placeholder: 치와와가 좌→우로 질주
func _dog_actor() -> void:
	var vp := get_viewport_rect().size
	var gy := Layout.ground_y()
	var dog := ColorRect.new()
	dog.color = Color(0.86, 0.7, 0.5); dog.size = Vector2(72, 48)
	dog.position = Vector2(-90, gy - 48)
	add_child(dog)
	create_tween().tween_property(dog, "position:x", vp.x + 90, 0.55).finished.connect(dog.queue_free)


## 살아있는 적 (ground_only=true면 공중 제외)
func _alive(ground_only: bool) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if ground_only and e.has_method("is_air") and e.is_air():
			continue
		out.append(e)
	return out


func _flash(col: Color) -> void:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.26)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.35)
	tw.tween_callback(r.queue_free)
