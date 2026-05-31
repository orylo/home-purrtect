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
@export var melee_range: float = 170.0        # 이 안이면 근접, 밖이면 원거리
@export var melee_hit_delay: float = 0.25     # 근접: 공격 시작 후 이만큼 뒤에 딜(펀치 맞는 순간)
@export var muzzle_offset: Vector2 = Vector2(70, -112)  # 총구 위치(치즈 기준)

## --- 넉백/스턴 세기(평타는 약, 크리는 강) ---
const NORMAL_KNOCKBACK := 70.0    # 평타 살짝 움찔
const CRIT_KNOCKBACK := 460.0     # 메이드 강넉백
const CRIT_STUN := 0.7            # 음악가 스턴(초)

## 크리 스탯(직업에서 _ready에 채움)
var crit_chance: float = 0.05
var crit_type: String = "strike"
var crit_mult: float = 1.5

signal died   # HP가 0이 되면 발생(게임오버 연출은 game.gd가 처리)

var health: float
var on_ground: bool = true
var crouching: bool = false   # 앉기(회피) 중 — 위에서 오는 공격을 피함(추후 큰 적용)
var _dead: bool = false
var _anim_reversed: bool = false   # walk 역재생(뒷걸음질) 중인지

# 모션 재생 배속/타이밍 (끝까지 재생, idle은 입력 없을 때만)
const ATTACK_ANIM_SPEED := 1.4
const HIT_ANIM_SPEED := 2.4
const JUMP_PREP_TIME := 0.13     # 도약 전 준비(땅에서)
const JUMP_PREP_SPEED := 3.2     # 준비 빠르게
const JUMP_AIR_SPEED := 0.42     # 체공 느리게
const JUMP_LAND_TIME := 0.12     # 착지 마무리(빠르게)
const JUMP_LAND_SPEED := 2.2
const SIT_HOLD_FRAME := 7        # 앉기: 완전히 숙인 프레임(여기서 홀드)

var _fire_timer: float = 0.0
var _committed_anim: String = "" # 끝까지 재생할 1회성 모션(hit/shoot/melee)
var _melee_pending: float = -1.0 # 근접 딜 대기 타이머
var _jump_state: String = ""     # ""/prep/air/land
var _jump_prep_timer: float = 0.0
var _jump_land_timer: float = 0.0
var _sit_phase: String = ""      # ""/down/up
var _hurt_flash_timer: float = 0.0
var _move_was_active: bool = false   # 직전 프레임에 이동 입력이 있었는지(새로 미는 순간 감지용)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle_fx: Node = $MuzzleFlash


func _ready() -> void:
	position.y = Layout.ground_y()   # 어떤 기기에서도 바닥에 서도록
	# 선택 직업 스탯 적용(시스템밸런스 §4)
	var st: Dictionary = GameState.job_stats()
	max_health = st["hp"]
	ranged_damage = st["ranged"]
	near_damage = st["near"]
	attack_interval = 1.0 / float(st["atk_spd"])
	move_multiplier = st["move"]
	crit_chance = st["crit"]
	crit_type = st["crit_type"]
	crit_mult = st["crit_mult"]
	health = max_health
	anim.flip_h = false  # 절대 좌우 반전 안 함 — 치즈는 항상 오른쪽을 본다
	# 선택한 직업의 스프라이트로 교체
	var frames := load(GameState.job_frames_path())
	if frames:
		anim.sprite_frames = frames
		anim.play("idle")
	anim.animation_finished.connect(_on_anim_finished)
	add_to_group("player")


# 1회성 모션이 끝나면 해제 → 입력 없을 때만 idle로
func _on_anim_finished() -> void:
	var a := anim.animation
	if a == _committed_anim:
		_committed_anim = ""      # 공격/피격 모션 끝
	if a == "sit" and _sit_phase == "up":
		_sit_phase = ""           # 일어나기 끝


func _physics_process(delta: float) -> void:
	_fire_timer -= delta
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
	# 근접 딜: 모션 시작 후 약간 뒤(펀치 닿는 순간)에 실제 데미지
	if _melee_pending >= 0.0:
		_melee_pending -= delta
		if _melee_pending <= 0.0:
			_melee_pending = -1.0
			_melee_attack()

	var direction := Input.get_axis("move_left", "move_right")
	if direction == 0.0:
		direction = Touch.move_axis   # 키보드 입력 없으면 가상 조이스틱 사용
	if absf(direction) < 0.2:
		direction = 0.0               # 조이스틱 미세 떨림 무시(데드존)

	# --- 이동/공격 상호배타 ---
	# 공격(사격/근접) 중에 "새로" 이동을 시작하면(다시 미는 순간) 공격 모션을 취소하고 이동 우선.
	# (계속 누르고 있던 입력으로는 취소 안 됨 → 공격 누르면 멈춰 있는 상태가 유지)
	var move_active := direction != 0.0
	var move_just_started := move_active and not _move_was_active
	if move_just_started and (_committed_anim == "shoot" or _committed_anim == "melee"):
		_committed_anim = ""
		_melee_pending = -1.0   # 근접 딜 대기도 취소
	_move_was_active = move_active

	# --- 앉기 상태머신: 숙여서 홀드 → 떼면 일어남(스프라이트 끝까지) ---
	var want_crouch := on_ground and (Touch.crouch_held or Input.is_action_pressed("crouch"))
	if want_crouch and _sit_phase == "" and _jump_state == "" and _committed_anim == "":
		_sit_phase = "down"
	elif _sit_phase == "down" and not want_crouch:
		_sit_phase = "up"
	crouching = _sit_phase == "down"
	if _sit_phase != "":
		direction = 0.0   # 앉기/일어나기 중 이동 잠금

	# 사격/근접 모션 중에는 제자리에 멈춤(움직이면서 공격 불가)
	if on_ground and (_committed_anim == "shoot" or _committed_anim == "melee"):
		direction = 0.0

	velocity.x = direction * base_speed * move_multiplier

	# --- 점프 상태머신: 준비(땅) → 도약 → 체공(느리게) → 착지(빠르게) ---
	var want_jump := Input.is_action_just_pressed("jump")
	if Touch.consume_jump():
		want_jump = true
	if on_ground and _jump_state == "" and _sit_phase == "" and _committed_anim == "" and want_jump:
		_jump_state = "prep"
		_jump_prep_timer = JUMP_PREP_TIME
	if _jump_state == "prep":
		velocity.x = 0.0   # 준비 중엔 제자리(준비 동작이 땅에서 끝나고 도약)
		_jump_prep_timer -= delta
		if _jump_prep_timer <= 0.0:
			velocity.y = -jump_force
			on_ground = false
			_jump_state = "air"

	if not on_ground:
		velocity.y += gravity * delta

	move_and_slide()

	# 오른쪽으로 갈 때, 부딪힌 적을 속도 규칙대로 민다
	if direction > 0.0 and _jump_state != "prep":
		_push_blocking_enemies()

	# 바닥 라인 착지
	var gy := Layout.ground_y()
	if position.y >= gy:
		position.y = gy
		velocity.y = 0.0
		if not on_ground and _jump_state == "air":
			_jump_state = "land"
			_jump_land_timer = JUMP_LAND_TIME
		on_ground = true
	if _jump_state == "land":
		_jump_land_timer -= delta
		if _jump_land_timer <= 0.0:
			_jump_state = ""

	# 화면 안에서만 (왼쪽 끝 ~ 오른쪽 끝)
	var screen_width := get_viewport_rect().size.x
	position.x = clampf(position.x, left_margin, screen_width - right_margin)

	# 공격(누르는 동안 연사, 거리에 따라 근접/원거리)
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
	if _sit_phase != "":
		return   # 앉은 중엔 공격 안 함
	var attacking := Touch.attack_held or Input.is_action_pressed("attack")
	if not attacking or _fire_timer > 0.0:
		return
	var target := _nearest_enemy()
	_fire_timer = attack_interval
	if target != null and global_position.distance_to(target.global_position) <= melee_range:
		_committed_anim = "melee"        # 근접 모션(끝까지 재생)
		_melee_pending = melee_hit_delay # 딜은 모션 중간에(펀치 닿을 때)
	else:
		_committed_anim = "shoot"  # 사격 모션(끝까지 재생)
		_fire_straight()           # 멀거나 적 없으면 일직선 발사


## 크리 판정 — 기본 데미지를 받아 (데미지, 넉백, 스턴, 크리여부) 산출.
## 평타는 약하게(작은 넉백), 크리 터지면 직업 효과가 강하게.
func _roll_attack(base_dmg: float) -> Dictionary:
	var dmg := base_dmg
	var kb := NORMAL_KNOCKBACK
	var stun := 0.0
	var is_crit := randf() < crit_chance
	if is_crit:
		match crit_type:
			"strike":    dmg *= crit_mult       # 보안관/맨몸: 강타
			"knockback": kb = CRIT_KNOCKBACK    # 메이드: 강넉백
			"stun":      stun = CRIT_STUN        # 음악가: 스턴
	return {"dmg": dmg, "kb": kb, "stun": stun, "crit": is_crit}


## 근접 공격 — 사정거리 안 적들에게 데미지 + 직업 크리 효과
func _melee_attack() -> void:
	var hit := _roll_attack(near_damage)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if global_position.distance_to((e as Node2D).global_position) <= melee_range:
			if e.has_method("take_damage"):
				e.take_damage(hit["dmg"], hit["kb"], hit["stun"], hit["crit"])


## 일직선(오른쪽) 발사 — 적 위치로 각도 조준하지 않고 곧게 나간다.
func _fire_straight() -> void:
	if bullet_scene == null:
		return
	var hit := _roll_attack(ranged_damage)
	var bullet := bullet_scene.instantiate()
	var muzzle := global_position + muzzle_offset
	if bullet.has_method("setup"):
		bullet.setup(Vector2.RIGHT, hit["dmg"], hit["kb"], hit["stun"], hit["crit"])
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
	_committed_anim = "hit"   # 피격 모션(끝까지·빠르게), 진행 중 공격 취소
	_melee_pending = -1.0
	_sit_phase = ""           # 맞으면 앉기 해제
	if health <= 0.0:
		health = 0.0
		_dead = true
		died.emit()   # 게임오버 — game.gd가 연출 처리


func _update_animation(direction: float) -> void:
	# 우선순위: 1회성모션(피격/공격) > 앉기 > 점프 > 걷기 > 정지
	# idle은 "아무 입력/모션도 없을 때"만 나온다.
	var next := "idle"
	var reversed := false
	if _committed_anim != "":
		next = _committed_anim   # hit/shoot/melee — 끝까지 재생
	elif _sit_phase != "":
		next = "sit"
	elif _jump_state != "":
		next = "jump"
	elif direction > 0.0:
		next = "walk"
	elif direction < 0.0:
		next = "walk"
		reversed = true   # 뒷걸음질 = walk 역재생(전용 모션 없음)

	if anim.animation != next or _anim_reversed != reversed:
		_anim_reversed = reversed
		if reversed:
			anim.play_backwards(next)
		else:
			anim.play(next)

	# 모션별 재생 배속
	var ss := 1.0
	if next == "shoot" or next == "melee":
		ss = ATTACK_ANIM_SPEED
	elif next == "hit":
		ss = HIT_ANIM_SPEED
	elif next == "jump":
		match _jump_state:
			"prep": ss = JUMP_PREP_SPEED
			"air":  ss = JUMP_AIR_SPEED
			"land": ss = JUMP_LAND_SPEED
	anim.speed_scale = ss

	# 앉기: 누르고 있는 동안 완전히 숙인 프레임에서 정지(떼면 일어남 재생)
	if next == "sit" and _sit_phase == "down" and anim.frame >= SIT_HOLD_FRAME:
		anim.frame = SIT_HOLD_FRAME
		anim.speed_scale = 0.0
