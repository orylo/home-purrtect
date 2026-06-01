extends CharacterBody2D
## 적 (범용) — def(Enemies.ENEMY_DEFS)로 종류별 스탯·생김새·행동을 받는다.
##   회색쥐·검은쥐(맨몸)만 쥐 스프라이트(검은쥐=어둡게 리컬러), 나머지는 placeholder(색·크기·이름표).
##   kind: melee 근접 / lob 포물선투척 / shoot 직선발사 / dive 공중→근접
##   원거리(lob/shoot)는 사거리 안에서 멈춰 enemy_bullet 발사. 공중(air)은 띄우고 밀기 대상 아님.
## 스포너가 add_child 전에 enemy.def = Enemies.def_of(id) 로 채워준다.

@export var move_speed: float = 120.0
@export var walk_time: float = 1.5
@export var stop_time: float = 1.0
@export var max_health: float = 20.0
@export var damage: float = 5.0
@export var attack_interval: float = 1.0

const POP := preload("res://scenes/pop_effect.tscn")
const ENEMY_BULLET := preload("res://scenes/enemy_bullet.tscn")
const ENEMY_FONT := preload("res://assets/fonts/DoHyeon-Regular.ttf")
const DMG_POP_DUR := 0.8
const AIR_HEIGHT := 230.0   # 공중 적이 떠 있는 높이(px)

# def에서 채워지는 행동/외형
var def: Dictionary = {}
var _kind := "melee"
var _air := false
var _status := ""
var _use_sprite := true
var _color := Color(0.6, 0.6, 0.62)
var _bcolor := Color(0.7, 0.7, 0.7)
var _body_r := 44.0
var _atk_range := 0.0
var _armor := 0.0
var _ename := "회색쥐"
var _base_modulate := Color(1, 1, 1)

var health: float
var dead: bool = false
var _phase_timer: float = 0.0
var _walking: bool = true
var _hit: bool = false
var _attack_timer: float = 0.0
var _push_vx: float = 0.0
var _flash: float = 0.0
var _flash_crit: bool = false
var _knockback: float = 0.0
var _stun_timer: float = 0.0
var _lunge: float = 0.0        # 근접 찌르기 모션 타이머
var _popups: Array = []

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	if not def.is_empty():
		_apply_def()
	max_health *= GameState.difficulty
	damage *= GameState.difficulty
	health = max_health
	anim.flip_h = false
	move_speed *= randf_range(0.85, 1.18)
	walk_time *= randf_range(0.8, 1.25)
	stop_time *= randf_range(0.75, 1.25)
	_walking = randf() > 0.3
	_phase_timer = randf_range(0.15, walk_time if _walking else stop_time)
	if _use_sprite:
		anim.play("walk")
	else:
		anim.visible = false   # placeholder는 _draw로 그림
	anim.animation_finished.connect(_on_anim_finished)
	if _air:
		anim.position.y -= AIR_HEIGHT
		$Hitbox.position.y -= AIR_HEIGHT   # 공중 적은 그려진 위치에서 맞게


func _apply_def() -> void:
	max_health = float(def.get("hp", 20))
	damage = float(def.get("dmg", 5))
	attack_interval = float(def.get("atkint", 1.0))
	move_speed = 120.0 * float(def.get("spd", 1.0))
	_kind = def.get("kind", "melee")
	_air = def.get("air", false)
	_status = def.get("status", "")
	_use_sprite = def.get("sprite", true)
	_color = def.get("color", Color(0.6, 0.6, 0.62))
	_bcolor = def.get("bcolor", Color(0.7, 0.7, 0.7))
	_body_r = float(def.get("radius", 44))
	_atk_range = float(def.get("range", 0))
	_armor = float(def.get("armor", 0))
	_ename = def.get("name", "적")
	if _use_sprite and _color.v < 0.45:
		_base_modulate = _color   # 검은쥐 = 쥐 스프라이트 어둡게


func _physics_process(delta: float) -> void:
	if not _popups.is_empty():
		for p in _popups:
			p["t"] += delta
		while not _popups.is_empty() and _popups[0]["t"] >= DMG_POP_DUR:
			_popups.pop_front()
		queue_redraw()

	if dead:
		velocity = Vector2.ZERO
		_push_vx = 0.0
		return

	var stunned := _stun_timer > 0.0
	if stunned:
		_stun_timer -= delta
	if _lunge > 0.0:
		_lunge -= delta

	if not stunned:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_walking = not _walking
			_phase_timer = walk_time if _walking else stop_time

	var ranged := _kind == "lob" or _kind == "shoot"
	var dist := _dist_to_player()

	# 이동
	var base_vx := 0.0
	if not stunned:
		if _push_vx > 0.0:
			base_vx = _push_vx
		elif _walking and not _hit:
			if ranged and _atk_range > 0.0 and dist <= _atk_range:
				base_vx = 0.0      # 사거리 안 → 멈춰서 발사
			else:
				base_vx = -move_speed
	_knockback = move_toward(_knockback, 0.0, 420.0 * delta)
	velocity.x = base_vx + _knockback
	velocity.y = 0.0
	move_and_slide()
	_push_vx = 0.0

	# 공격
	_attack_timer -= delta
	if not stunned and _attack_timer <= 0.0:
		if ranged:
			if _atk_range > 0.0 and dist <= _atk_range:
				_attack_timer = attack_interval
				_fire_projectile()
		elif _is_touching_player():
			_attack_timer = attack_interval
			_lunge = 0.16
			var player := get_tree().get_first_node_in_group("player")
			if player and player.has_method("take_damage"):
				player.take_damage(damage)
				if _status != "" and player.has_method("apply_status"):
					player.apply_status(_status)

	# 스프라이트 적: 근접 찌르기 + 번쩍/스턴 색
	if _use_sprite:
		anim.position.x = -(_lunge / 0.16) * 16.0 if _lunge > 0.0 else 0.0
		if _flash > 0.0:
			_flash -= delta
			anim.modulate = Color(2.0, 1.7, 0.4) if _flash_crit else Color(1.9, 1.9, 1.9)
		elif stunned:
			anim.modulate = Color(0.6, 0.75, 1.1)
		else:
			anim.modulate = _base_modulate
	elif _flash > 0.0:
		_flash -= delta

	queue_redraw()


func _fire_projectile() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_lunge = 0.16
	var oy := -AIR_HEIGHT if _air else -90.0
	var origin := global_position + Vector2(-10, oy)
	var b := ENEMY_BULLET.instantiate()
	b.global_position = origin
	get_parent().add_child(b)
	var target := (player as Node2D).global_position + Vector2(0, -90)   # 치즈 몸통 겨냥
	if _kind == "lob":
		# 탄도 계산: 비행시간 t 동안 정확히 치즈에 도달하는 포물선(중력 g)
		var g := 1300.0
		var to := target - origin
		var t := clampf(absf(to.x) / 420.0, 0.55, 1.4)   # 거리 멀수록 길게(과하지 않게 clamp)
		var vx := to.x / t
		var vy := (to.y - 0.5 * g * t * t) / t
		b.setup(Vector2(vx, vy), damage, _status, _bcolor, g)
	else:
		var dir := (target - origin).normalized()
		b.setup(dir * 520.0, damage, _status, _bcolor, 0.0)                   # 직선


func _dist_to_player() -> float:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return 99999.0
	return absf(global_position.x - (p as Node2D).global_position.x)


func _draw() -> void:
	_draw_damage_popups()
	if dead:
		return
	# 발밑 그림자
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, _body_r, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# placeholder 몸 (스프라이트 안 쓰는 적)
	if not _use_sprite:
		var cy := -_body_r - 12.0 - (AIR_HEIGHT if _air else 0.0)
		var lunge_off := Vector2(-(_lunge / 0.16) * 18.0, 0.0)
		var bc := _color.lightened(0.6) if _flash > 0.0 else _color
		draw_set_transform(Vector2(0, cy) + lunge_off, 0.0, Vector2(1.0, 1.15))
		draw_circle(Vector2.ZERO, _body_r, bc)
		draw_arc(Vector2.ZERO, _body_r, 0.0, TAU, 24, Color(0, 0, 0, 0.45), 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 이름표
		var ty := cy - _body_r - 14.0
		draw_string_outline(ENEMY_FONT, Vector2(-60, ty), _ename, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, 4, Color(0, 0, 0, 0.7))
		draw_string(ENEMY_FONT, Vector2(-60, ty), _ename, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(1, 1, 1))

	# HP 바 (피해 입었을 때만)
	if health < max_health:
		var w := 76.0
		var hy := -158.0 - (AIR_HEIGHT if _air else 0.0)
		var ratio := clampf(health / max_health, 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, hy, w, 9.0), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(-w * 0.5, hy, w * ratio, 9.0), Color(0.95, 0.25, 0.2, 1.0))
		draw_rect(Rect2(-w * 0.5, hy, w, 9.0), Color(1, 1, 1, 0.6), false, 1.5)


func _draw_damage_popups() -> void:
	if _popups.is_empty():
		return
	var font: Font = ENEMY_FONT
	var base_y := -174.0 - (AIR_HEIGHT if _air else 0.0)
	for p in _popups:
		var f: float = clampf(p["t"] / DMG_POP_DUR, 0.0, 1.0)
		var y := base_y - 48.0 * f
		var a := 1.0 - f
		var col := Color(1.0, 0.82, 0.2, a) if p["crit"] else Color(1.0, 0.96, 0.96, a)
		var txt := str(p["amount"])
		var pos := Vector2(-40.0, y)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 26, 5, Color(0, 0, 0, a * 0.85))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 26, col)


func _is_touching_player() -> bool:
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other and other.is_in_group("player"):
			return true
	return false


func get_advance_speed() -> float:
	if _walking and not _hit and not dead:
		return move_speed
	return 0.0


func receive_push(amount: float) -> void:
	if dead or _air:    # 공중 적은 밀기 대상 아님
		return
	_push_vx = max(_push_vx, amount)


func is_dead() -> bool:
	return dead


func take_damage(amount: float, knockback: float = 70.0, stun: float = 0.0, crit: bool = false) -> void:
	if dead:
		return
	if GameState.cheats.get("enemy_oneshot", false):
		amount = 999999.0
	else:
		amount = maxf(amount - _armor, 1.0)   # 방어력만큼 감소(최소 1)
	if amount >= 1.0:
		_popups.append({"amount": int(round(amount)), "t": 0.0, "crit": crit})
	health -= amount
	if health <= 0.0:
		_die()
	else:
		_hit = true
		_flash = 0.12
		_flash_crit = crit
		_knockback = maxf(_knockback, knockback)
		if stun > 0.0:
			_stun_timer = stun
		Fx.request_shake(7.0 if crit else 3.0)
		if _use_sprite:
			anim.play("hit")


func _on_anim_finished() -> void:
	if dead:
		queue_free()
	elif _hit and anim.animation == "hit":
		_hit = false
		anim.play("walk")


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$Hitbox.set_deferred("monitorable", false)
	queue_redraw()
	var pop := POP.instantiate()
	get_parent().add_child(pop)
	pop.global_position = global_position + Vector2(0, -45 - (AIR_HEIGHT if _air else 0.0))
	Fx.request_shake(7.0)
	Fx.request_hitstop(0.05)
	if _use_sprite:
		anim.modulate = Color(1, 1, 1)
		anim.play("ghost")
	else:
		var t := get_tree().create_timer(0.05)
		t.timeout.connect(queue_free)
