extends CharacterBody2D
## 적 — 쥐 (1막 기본 지상 러셔)
##
## 오른쪽에서 등장해 왼쪽(집)으로 "걷고-멈추기"를 반복하며 전진한다.
## 치즈(살아있는 관문)에 막혀 통과하지 못하고, 키 큰 투명벽이라 점프로도 못 넘는다.
## 치즈에 닿아 있으면 attack_interval마다 공격(치즈에게 데미지).
## 치즈가 몸으로 밀면(receive_push) 오른쪽으로 밀린다. 쥐끼리도 부딪혀 줄을 선다.
## 탄환에 맞으면 hit 모션 → HP 0이면 ghost(유령) 연출 후 사라진다.

@export var move_speed: float = 120.0   # 걷는 단계 이동 속도(px/s) — 튜닝값
@export var walk_time: float = 1.5      # 걷는 시간(시스템밸런스 §1.1: 쥐 1.5s)
@export var stop_time: float = 1.0      # 멈추는 시간(쥐 1.0s)
@export var max_health: float = 20.0    # 쥐 HP (시스템밸런스 §3.1)
@export var damage: float = 5.0         # 치즈에게 주는 공격 데미지 (쥐 DMG 5)
@export var attack_interval: float = 1.0  # 공격 간격(쥐 1.0s)

const POP := preload("res://scenes/pop_effect.tscn")

var health: float
var dead: bool = false
var _phase_timer: float = 0.0
var _walking: bool = true
var _hit: bool = false
var _attack_timer: float = 0.0
var _push_vx: float = 0.0
var _flash: float = 0.0       # 피격 번쩍 타이머
var _flash_crit: bool = false # 크리 피격이면 금색 번쩍
var _knockback: float = 0.0   # 피격 시 오른쪽으로 밀림
var _stun_timer: float = 0.0  # 스턴(음악가 크리) 남은 시간
var _popups: Array = []       # 머리 위로 떠오르는 데미지 숫자들 {amount, t, crit}
const DMG_POP_DUR := 0.8      # 데미지 숫자 지속(상승+페이드) 시간

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	anim.flip_h = false  # 쥐는 그림 자체가 왼쪽을 봄(진행 방향) — 뒤집지 않음
	# 개체마다 속도·리듬을 살짝 다르게 + 시작 박자를 흩어 로봇처럼 안 보이게
	move_speed *= randf_range(0.85, 1.18)
	walk_time *= randf_range(0.8, 1.25)
	stop_time *= randf_range(0.75, 1.25)
	_walking = randf() > 0.3
	_phase_timer = randf_range(0.15, walk_time if _walking else stop_time)
	anim.play("walk")
	anim.animation_finished.connect(_on_anim_finished)


func _physics_process(delta: float) -> void:
	# 데미지 숫자 상승/소멸은 죽어도 계속(마지막 일격 표시)
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

	# 1) 걷고-멈추기 리듬 (스턴 중엔 멈춤)
	if not stunned:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_walking = not _walking
			_phase_timer = walk_time if _walking else stop_time

	# 2) 이동: 스턴이면 전진 정지. 밀림(넉백)은 그대로 적용.
	var base_vx := 0.0
	if not stunned:
		if _push_vx > 0.0:
			base_vx = _push_vx
		elif _walking and not _hit:
			base_vx = -move_speed
	_knockback = move_toward(_knockback, 0.0, 420.0 * delta)
	velocity.x = base_vx + _knockback
	velocity.y = 0.0
	move_and_slide()
	_push_vx = 0.0   # 매 프레임 리셋(치즈가 계속 밀면 다시 설정됨)

	# 3) 치즈에 닿아 있으면 공격 (스턴 중엔 못 함)
	_attack_timer -= delta
	if not stunned and _is_touching_player() and _attack_timer <= 0.0:
		_attack_timer = attack_interval
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("take_damage"):
			player.take_damage(damage)

	# 피격 번쩍(크리=금색) / 스턴(파랑) / 평소
	if _flash > 0.0:
		_flash -= delta
		anim.modulate = Color(2.0, 1.7, 0.4) if _flash_crit else Color(1.9, 1.9, 1.9)
	elif stunned:
		anim.modulate = Color(0.6, 0.75, 1.1)
	else:
		anim.modulate = Color(1, 1, 1)

	queue_redraw()   # 머리 위 HP 게이지 갱신


# 머리 위 HP 게이지 — 데미지를 입은 뒤부터 표시
func _draw() -> void:
	_draw_damage_popups()   # 데미지 숫자(죽어도 표시)
	if dead:
		return
	# 발밑 그림자 — 검정 30% 타원(항상 표시)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 52.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# HP 바 — 피해 입었을 때만
	if health < max_health:
		var w := 76.0
		var h := 9.0
		var x := -w * 0.5
		var y := -158.0   # 머리 위
		var ratio := clampf(health / max_health, 0.0, 1.0)
		draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.65))                       # 배경
		draw_rect(Rect2(x, y, w * ratio, h), Color(0.95, 0.25, 0.2, 1.0))        # 체력
		draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.6), false, 1.5)            # 테두리


## 데미지 숫자 — 머리 위(HP바 위)로 상승하며 점점 투명해짐. 크리는 금색.
func _draw_damage_popups() -> void:
	if _popups.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	for p in _popups:
		var f: float = clampf(p["t"] / DMG_POP_DUR, 0.0, 1.0)
		var y := -174.0 - 48.0 * f                    # HP바(-158) 위에서 더 상승
		var a := 1.0 - f                              # 점점 투명
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


## 치즈가 밀기 판단에 쓰는 "현재 전진 속도"(전진 중이면 양수, 멈췄으면 0)
func get_advance_speed() -> float:
	if _walking and not _hit and not dead:
		return move_speed
	return 0.0


## 치즈가 몸으로 밀 때 호출 — 이번 프레임 오른쪽으로 밀린다.
func receive_push(amount: float) -> void:
	if dead:
		return
	_push_vx = max(_push_vx, amount)


func is_dead() -> bool:
	return dead


## 탄환/근접에서 호출 — 데미지 + 넉백 + 스턴 + 크리(금색)
func take_damage(amount: float, knockback: float = 70.0, stun: float = 0.0, crit: bool = false) -> void:
	if dead:
		return
	# 닳은 HP 숫자를 머리 위로 띄움
	if amount >= 1.0:
		_popups.append({"amount": int(round(amount)), "t": 0.0, "crit": crit})
	health -= amount
	if health <= 0.0:
		_die()
	else:
		_hit = true
		_flash = 0.12
		_flash_crit = crit
		_knockback = maxf(_knockback, knockback)   # 오른쪽으로 밀림(크리=강넉백)
		if stun > 0.0:
			_stun_timer = stun
		Fx.request_shake(7.0 if crit else 3.0)
		anim.play("hit")


func _on_anim_finished() -> void:
	if dead:
		queue_free()              # ghost(유령) 애니가 끝나면 완전히 제거
	elif _hit and anim.animation == "hit":
		_hit = false
		anim.play("walk")


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	anim.modulate = Color(1, 1, 1)  # 번쩍 중 죽어도 유령은 정상 색
	$CollisionShape2D.set_deferred("disabled", true)  # 죽으면 충돌(벽) 끔
	$Hitbox.set_deferred("monitorable", false)         # 총알도 더는 안 맞게
	anim.play("ghost")
	queue_redraw()   # 머리 위 HP 게이지 제거
	# 처치 "펑!" + 화면 흔들림 + 히트스톱
	var pop := POP.instantiate()
	get_parent().add_child(pop)
	pop.global_position = global_position + Vector2(0, -45)
	Fx.request_shake(7.0)
	Fx.request_hitstop(0.05)
