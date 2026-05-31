extends CharacterBody2D
## 치즈(주인공) — 좌우 이동 + 점프(회피) + 원거리 자동사격 + 몸으로 밀기
##
## ★핵심 규칙:
##   · 치즈는 절대 좌우 반전 안 함 — 언제나 오른쪽을 본다.
##     오른쪽 이동=walk / 왼쪽 이동=back(뒷걸음질) / 정지=idle / 공중=jump / 사격=shoot
##   · 적은 통과 못 함(살아있는 관문). 점프해도 적 위로 못 넘어감(적은 키 큰 투명벽).
##   · "몸으로 밀기": 오른쪽으로 가며 적과 부딪히면, 속도 규칙에 따라 적을 민다.
##       - 적이 정지 중이면 누구나 밀기 가능
##       - 적이 전진 중이면 치즈 이동속도 > 적 이동속도일 때만
##       - 미는 속도 = (치즈 이동속도 − 적 이동속도)
##   · 데미지는 "접촉"이 아니라 "적의 공격"에서만 받는다(넉백 없음, 피격 플래시만).

## --- 이동 ---
@export var base_speed: float = 300.0
@export var move_multiplier: float = 1.0      # 직업 이동속도 배율 (맨몸 치즈 = 1.0)
@export var left_margin: float = 40.0
@export var right_margin: float = 70.0

## --- 점프(회피) ---
@export var jump_force: float = 700.0
@export var gravity: float = 1800.0

## --- 체력 ---
@export var max_health: float = 100.0         # 맨몸 치즈 체력(시스템밸런스 §4.1)

## --- 공격(공격 버튼으로 발동, 근접/원거리 자동 전환) ---
@export var bullet_scene: PackedScene
@export var ranged_damage: float = 8.0        # 맨몸 치즈 원거리공격력(돌) 8
@export var near_damage: float = 12.0         # 맨몸 치즈 근거리공격력(할퀴기) 12
@export var attack_interval: float = 1.0      # 공격속도 1.0/s → 누르고 있으면 1초에 1번
@export var melee_range: float = 130.0        # 이 안이면 근접, 밖이면 원거리
@export var muzzle_offset: Vector2 = Vector2(70, -112)  # 총구 위치(치즈 기준)

signal died   # HP가 0이 되면 발생(게임오버 연출은 game.gd가 처리)

var health: float
var on_ground: bool = true
var _dead: bool = false

var _fire_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _hurt_flash_timer: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle_fx: Node = $MuzzleFlash


func _ready() -> void:
	position.y = Layout.ground_y()   # 어떤 기기에서도 바닥에 서도록
	health = max_health
	anim.flip_h = false  # 절대 좌우 반전 안 함 — 치즈는 항상 오른쪽을 본다
	add_to_group("player")


func _physics_process(delta: float) -> void:
	_fire_timer -= delta
	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer -= delta
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta

	var direction := Input.get_axis("move_left", "move_right")
	if direction == 0.0:
		direction = Touch.move_axis   # 키보드 입력 없으면 가상 조이스틱 사용
	if absf(direction) < 0.2:
		direction = 0.0               # 조이스틱 미세 떨림 무시(데드존)

	# 좌우 이동
	velocity.x = direction * base_speed * move_multiplier

	# 점프(회피) — 키보드 또는 조이스틱 탭
	var want_jump := Input.is_action_just_pressed("jump")
	if Touch.consume_jump():
		want_jump = true
	if on_ground and want_jump:
		velocity.y = -jump_force
		on_ground = false
	if not on_ground:
		velocity.y += gravity * delta

	move_and_slide()

	# 오른쪽으로 갈 때, 부딪힌 적을 속도 규칙대로 민다
	if direction > 0.0:
		_push_blocking_enemies()

	# 바닥 라인 착지 (화면 아래에 동적으로 맞춰진 바닥)
	var gy := Layout.ground_y()
	if position.y >= gy:
		position.y = gy
		velocity.y = 0.0
		on_ground = true

	# 화면 안에서만 (왼쪽 끝 ~ 오른쪽 끝)
	var screen_width := get_viewport_rect().size.x
	position.x = clampf(position.x, left_margin, screen_width - right_margin)

	# 공격(공격 버튼/키를 누르고 있으면 연사, 거리에 따라 근접/원거리)
	_handle_attack()

	# 피격 시 흰 번쩍(몹과 통일)
	anim.modulate = Color(1.9, 1.9, 1.9) if _hurt_flash_timer > 0.0 else Color(1, 1, 1)

	_update_animation(direction)


## 몸으로 밀기 — move_and_slide에서 부딪힌 적을 속도 규칙대로 민다.
func _push_blocking_enemies() -> void:
	var my_speed := base_speed * move_multiplier
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other == null or not other.is_in_group("enemies"):
			continue
		if not other.has_method("receive_push"):
			continue
		var enemy_speed := 0.0
		if other.has_method("get_advance_speed"):
			enemy_speed = other.get_advance_speed()
		# 적 정지 중(speed 0)이면 누구나 / 전진 중이면 내가 더 빠를 때만
		if enemy_speed <= 0.0 or my_speed > enemy_speed:
			other.receive_push(my_speed - enemy_speed)


## --- 공격 (공격 버튼/키를 누르고 있는 동안 attack_interval마다 발동) ---
func _handle_attack() -> void:
	var attacking := Touch.attack_held or Input.is_action_pressed("attack")
	if not attacking or _fire_timer > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_fire_timer = attack_interval
	_shoot_anim_timer = 0.35   # 공격 모션 잠깐 표시(근접 모션은 추후 제작)
	var dist := global_position.distance_to(target.global_position)
	if dist <= melee_range:
		_melee_attack()        # 가까우면 근접
	else:
		_fire_at(target)       # 멀면 원거리


## 근접 공격 — 사정거리 안 적들에게 할퀴기 데미지
func _melee_attack() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if global_position.distance_to((e as Node2D).global_position) <= melee_range:
			if e.has_method("take_damage"):
				e.take_damage(near_damage)


func _fire_at(target: Node2D) -> void:
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	var muzzle := global_position + muzzle_offset
	var dir := (target.global_position - muzzle).normalized()
	if bullet.has_method("setup"):
		bullet.setup(dir, ranged_damage)
	bullet.global_position = muzzle
	get_parent().add_child(bullet)
	if is_instance_valid(muzzle_fx):
		muzzle_fx.flash()   # 총구 화염


func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var d := global_position.distance_to((e as Node2D).global_position)
		if d < best:
			best = d
			nearest = e
	return nearest


## 적의 공격에서 호출 — 데미지를 받는다(넉백 없음).
func take_damage(amount: float) -> void:
	if _dead:
		return
	health -= amount
	_hurt_flash_timer = 0.15
	if health <= 0.0:
		health = 0.0
		_dead = true
		died.emit()   # 게임오버 — game.gd가 연출 처리


func _update_animation(direction: float) -> void:
	# 우선순위: 사격(쏘는 순간 잠깐) > 점프 > 걷기/뒷걸음 > 정지
	# → 걷거나 점프 중에 쏴도 "탕!(사격 포즈)"가 잠깐 보인다.
	var next := "idle"
	if _shoot_anim_timer > 0.0:
		next = "shoot"
	elif not on_ground:
		next = "jump"
	elif direction > 0.0:
		next = "walk"
	elif direction < 0.0:
		next = "back"

	if anim.animation != next:
		anim.play(next)
