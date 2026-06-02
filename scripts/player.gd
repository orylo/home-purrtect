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
@export var jump_force: float = 820.0   # 점프 정점이 공중 적 높이에 맞도록(정점 muzzle≈297px=공중 히트박스 중심)
@export var gravity: float = 1800.0

## --- 체력 ---
@export var max_health: float = 100.0         # 맨몸 치즈 체력(시스템밸런스 §4.1)

## --- 공격(공격 버튼으로 발동, 근접/원거리 자동 전환) ---
@export var bullet_scene: PackedScene
@export var ranged_damage: float = 8.0        # 맨몸 치즈 원거리공격력(돌) 8
@export var near_damage: float = 12.0         # 맨몸 치즈 근거리공격력(할퀴기) 12
@export var attack_interval: float = 1.0      # 공격속도 1.0/s → 누르고 있으면 1초에 1번
@export var melee_range: float = 340.0        # 이 안이면 근접, 밖이면 원거리(2배로 넓힘)
const MELEE_MAX_TARGETS := 3                  # 한 번에 때리는 최대 적 수(가까운 순)
@export var melee_hit_delay: float = 0.10     # 근접: 공격 시작 후 이만큼 뒤에 딜(빠른 모션에 맞춰 단축)
@export var muzzle_offset: Vector2 = Vector2(70, -112)  # 총구 위치(치즈 기준)

## --- 넉백/스턴 세기(평타는 약, 크리는 강) ---
const NORMAL_KNOCKBACK := 70.0    # 평타 살짝 움찔
const CRIT_KNOCKBACK := 460.0     # 메이드 강넉백
const CRIT_STUN := 0.7            # 음악가 스턴(초)

## 크리 스탯(직업에서 _ready에 채움)
var crit_chance: float = 0.05
var crit_type: String = "strike"
var crit_mult: float = 1.5

## 원거리 발사방식(직업에서 _ready에 채움)
var ranged_mode: String = "straight"   # straight 일자 / lob 포물선던지기
var ranged_limit_frac: float = 0.0      # 일자 사거리(화면폭 비율, 0=끝까지) — 음악가 0.5
var ranged_misfire: float = 0.0         # 불발 확률 — 보안관
var ranged_shape: String = "dot"        # 투사체 모양(dot/stone/plate/note)
var ranged_fire_delay: float = 0.0      # 공격 시작 후 발사까지 딜레이(모션 타이밍)

signal died   # HP가 0이 되면 발생(게임오버 연출은 game.gd가 처리)

var health: float
var on_ground: bool = true
var crouching: bool = false   # 앉기(회피) 중 — 위에서 오는 공격을 피함(추후 큰 적용)
var _dead: bool = false
var _anim_reversed: bool = false   # walk 역재생(뒷걸음질) 중인지

# 모션 재생 배속/타이밍 (끝까지 재생, idle은 입력 없을 때만)
const ATTACK_PREP_SPEED := 3.5     # 준비동작(발사/타격 전)은 빠르게 → 누르는 즉시 공격되는 느낌
const ATTACK_RECOVER_SPEED := 1.5  # 발사/타격 후 마무리는 자연스럽게 → 방정맞아 보이지 않게
const HIT_ANIM_SPEED := 2.4
const JUMP_PREP_TIME := 0.13     # 도약 전 준비(땅에서)
const JUMP_PREP_SPEED := 3.2     # 준비 빠르게
const JUMP_AIR_SPEED := 0.42     # 체공 느리게
const JUMP_LAND_TIME := 0.12     # 착지 마무리(빠르게)
const JUMP_LAND_SPEED := 2.2
const SIT_HOLD_FRAME := 7        # 앉기: 완전히 숙인 프레임(여기서 홀드)
const SIT_SPEED := 2.8           # 앉기/일어나기 재생 배속(회피 반응 빠르게)

## --- 원거리 튜닝값(플레이테스트로 조정) ---
# 음악가(음표): 고화력·단거리·저속 + 위아래 물결 (탄마다 랜덤)
const JAZZ_SPEED_MAX := 340.0   # 탄환 속도 최대(현재값)
const JAZZ_SPEED_MIN := 230.0   # 탄환 속도 최소(가끔 더 느리게)
const JAZZ_WAVE_AMP_MIN := 16.0 # 물결 진폭 최소(px)
const JAZZ_WAVE_AMP_MAX := 32.0 # 물결 진폭 최대(px)
const JAZZ_WAVE_LEN_MIN := 110.0 # 물결 주기 최소(px)
const JAZZ_WAVE_LEN_MAX := 165.0 # 물결 주기 최대(px)
const JAZZ_FADE_START := 0.6    # 사거리의 이 비율(0~1)부터 투명해지기 시작
const JAZZ_NOTE_TYPES := 3      # 음표 모양 가짓수(랜덤)
# rlimit(사거리=화면폭×비율)은 GameState.JOB_STATS에 있음(음악가 0.5)
# 메이드/맨몸(던지기): 저화력·랜덤 포물선
const LOB_ANGLE_MIN := 0.0      # 던지는 각도 최소(수평)
const LOB_ANGLE_MAX := 45.0     # 던지는 각도 최대(위로 45도)
const LOB_POWER := 900.0        # 던지는 힘(사거리) — 조금 늘림
const LOB_GRAVITY := 1500.0     # 포물선 중력
# 보안관(총): 장거리·직선·불발(확률은 JOB_STATS misfire=0.12)
const SHERIFF_BULLET_SPEED := 840.0

var _fire_timer: float = 0.0
var _committed_anim: String = "" # 끝까지 재생할 1회성 모션(hit/shoot/melee)
var _attack_fired: bool = false  # 이번 공격에서 발사/타격이 이미 일어났는지(준비→마무리 속도 전환)
var _melee_pending: float = -1.0 # 근접 딜 대기 타이머
var _ranged_pending: float = -1.0 # 원거리 발사 대기 타이머(모션 타이밍)
var _jump_state: String = ""     # ""/prep/air/land
var _jump_prep_timer: float = 0.0
var _jump_land_timer: float = 0.0
var _sit_phase: String = ""      # ""/down/up
var _hurt_flash_timer: float = 0.0
var _poison_timer: float = 0.0   # 독(지속 데미지) 남은 시간
var _poison_tick: float = 0.0    # 다음 독 틱까지
var _slow_timer: float = 0.0     # 둔화(이동 감속) 남은 시간
var _atk_buff_t: float = 0.0     # 말린 멸치: 공격력 버프 남은 시간
const ATK_BUFF_MULT := 1.5       # 말린 멸치: +50%
var _guard_t: float = 0.0        # 방패 자세: 피해감소 남은 시간
var _guard_pct: float = 0.0      # 방패 자세: 피해감소율(예 0.40)
var _encore_t: float = 0.0       # 앵콜: 공속+40%·이속+20% 남은 시간
const ENCORE_ASPD := 1.4
const ENCORE_MSPD := 1.2
var _hurt_popups: Array = []     # 치즈가 받은 데미지 숫자(머리 위로 상승+페이드)
const HURT_POP_DUR := 0.8
# 눕기 그림자 크기는 현재 sit 스프라이트 프레임에 직접 맞춘다(_draw 참고)
var _move_was_active: bool = false   # 직전 프레임에 이동 입력이 있었는지(새로 미는 순간 감지용)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle_fx: Node = $MuzzleFlash
var _click_player: AudioStreamPlayer   # 보안관 불발 "철컥" 소리


func _ready() -> void:
	position.y = Layout.ground_y()   # 어떤 기기에서도 바닥에 서도록
	# 선택 직업 스탯 적용(시스템밸런스 §4)
	var st: Dictionary = GameState.job_stats()
	var lvm := GameState.level_mult()          # 등급(Lv) 배율 — hp/원/근에 곱함
	max_health = st["hp"] * lvm
	ranged_damage = st["ranged"] * lvm
	near_damage = st["near"] * lvm
	# 펄 축복(이번 판) — 발톱=공격+% / 배=체력+% (§5.5, 로드맵 6단계)
	match GameState.selected_blessing:
		"claw":
			var p := 1.0 + GameState.blessing_pct("atk")
			ranged_damage *= p
			near_damage *= p
		"belly":
			max_health *= 1.0 + GameState.blessing_pct("hp")
	attack_interval = 1.0 / float(st["atk_spd"])
	move_multiplier = st["move"]
	crit_chance = st["crit"]
	crit_type = st["crit_type"]
	crit_mult = st["crit_mult"]
	ranged_mode = st.get("rmode", "straight")
	ranged_limit_frac = st.get("rlimit", 0.0)
	ranged_misfire = st.get("misfire", 0.0)
	ranged_shape = st.get("rshape", "dot")
	ranged_fire_delay = st.get("rdelay", 0.0)
	health = max_health
	anim.flip_h = false  # 절대 좌우 반전 안 함 — 치즈는 항상 오른쪽을 본다
	# 선택한 직업의 스프라이트로 교체
	var frames := load(GameState.job_frames_path())
	if frames:
		anim.sprite_frames = frames
		anim.play("idle")
	anim.animation_finished.connect(_on_anim_finished)
	add_to_group("player")
	# 충돌 레이어를 코드로 명시(.tscn 헤더값은 Godot이 무시함):
	#   layer 4 = 플레이어 / mask 2 = 적만(몸으로 밀기·관문). 적은 mask 4로 플레이어에 막힘.
	collision_layer = 4
	collision_mask = 2
	# 불발 소리(철컥) — 짧은 클릭음을 코드로 생성
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = _make_click_sound()
	_click_player.volume_db = -4.0
	add_child(_click_player)


## "철컥" 불발 소리 — 짧게 감쇠하는 노이즈 버스트를 즉석에서 생성.
func _make_click_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.06)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var tt := float(i) / float(rate)
		var env := exp(-tt * 70.0)                      # 빠른 감쇠
		var s := (randf() * 2.0 - 1.0) * env * 0.7      # 노이즈 × 감쇠
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


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
			_attack_fired = true     # 타격 끝 → 마무리는 천천히
	# 원거리: 모션 시작 후 약간 뒤(손이 던지는/총 쏘는 순간)에 실제 발사
	if _ranged_pending >= 0.0:
		_ranged_pending -= delta
		if _ranged_pending <= 0.0:
			_ranged_pending = -1.0
			_fire_ranged()
			_attack_fired = true     # 발사 끝 → 마무리는 천천히

	# 상태이상: 독(0.5초마다 지속 데미지) / 둔화(타이머만, 감속은 velocity에서)
	if _poison_timer > 0.0:
		_poison_timer -= delta
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 0.5
			_poison_damage(2.0)
	if _slow_timer > 0.0:
		_slow_timer -= delta
	if _atk_buff_t > 0.0:
		_atk_buff_t -= delta
	if _guard_t > 0.0:
		_guard_t -= delta
	if _encore_t > 0.0:
		_encore_t -= delta

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
		_melee_pending = -1.0    # 근접 딜 대기도 취소
		_ranged_pending = -1.0   # 원거리 발사 대기도 취소
	_move_was_active = move_active

	# --- 앉기 상태머신: 숙여서 홀드 → 떼면 일어남(스프라이트 끝까지) ---
	# 전환 시점에 anim.play("sit")를 "명시적으로" 호출해야 함.
	# (이전에 sit이 끝나 멈춰있으면 speed만 올려선 다시 안 움직여 → 일어나기 영구 잠김 버그)
	var want_crouch := on_ground and (Touch.crouch_held or Input.is_action_pressed("crouch"))
	if want_crouch and _sit_phase == "" and _jump_state == "" and _committed_anim == "":
		_sit_phase = "down"
		anim.play("sit")              # 처음부터 숙이기 시작
		anim.speed_scale = 1.0
	elif _sit_phase == "down" and not want_crouch:
		_sit_phase = "up"
		anim.play("sit")              # 멈춰있던 sit을 확실히 재생 상태로
		anim.frame = SIT_HOLD_FRAME   # 숙인 프레임(7)부터 이어서 일어남
		anim.speed_scale = 1.0
	crouching = _sit_phase == "down"
	if _sit_phase != "":
		direction = 0.0   # 앉기/일어나기 중 이동 잠금

	# 사격/근접 모션 중에는 제자리에 멈춤(움직이면서 공격 불가)
	if on_ground and (_committed_anim == "shoot" or _committed_anim == "melee"):
		direction = 0.0

	var slow_factor := 0.5 if _slow_timer > 0.0 else 1.0   # 둔화 시 절반 속도
	var encore_m := ENCORE_MSPD if _encore_t > 0.0 else 1.0   # 앵콜 이속 버프
	velocity.x = direction * base_speed * move_multiplier * slow_factor * encore_m

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

	# 받은 데미지 숫자 상승/소멸
	if not _hurt_popups.is_empty():
		for p in _hurt_popups:
			p["t"] += delta
		while not _hurt_popups.is_empty() and _hurt_popups[0]["t"] >= HURT_POP_DUR:
			_hurt_popups.pop_front()

	_update_animation(direction)
	queue_redraw()   # 발밑 그림자(점프 높이/눕기 반영) + 데미지 숫자 갱신


## 발밑 그림자 — 검정 30% 타원. 점프하면 바닥에 남고 작아진다.
## 누우면(crouch) 좌우로 넓고 + 위로 올라가 "지면에 누운" 느낌.
func _draw() -> void:
	var gy_local := Layout.ground_y() - position.y
	if gy_local < 0.0:
		gy_local = 0.0
	var t := clampf(1.0 - gy_local / 500.0, 0.35, 1.0)   # 높이 오를수록 작고 옅게
	# 그림자 크기를 "현재 sit 스프라이트 프레임"에 직접 맞춤 — 누운 프레임=크게, 선 프레임=작게
	var blend := 0.0
	if _sit_phase == "down":
		# 0프레임(섬)→7프레임(완전히 누움)으로 갈수록 1
		blend = clampf(float(anim.frame) / float(SIT_HOLD_FRAME), 0.0, 1.0)
	elif _sit_phase == "up" and anim.sprite_frames != null:
		# 7프레임(누움)→마지막(섬)으로 갈수록 0
		var last := float(maxi(anim.sprite_frames.get_frame_count("sit") - 1, SIT_HOLD_FRAME + 1))
		blend = clampf((last - float(anim.frame)) / (last - float(SIT_HOLD_FRAME)), 0.0, 1.0)
	var rx := lerpf(76.0, 120.0, blend)          # 좌우 반경(누울수록 넓게)
	var ry_scale := lerpf(0.26, 0.30, blend)     # 위아래 납작 정도
	var sy := gy_local - 20.0 * blend            # 누울수록 위로
	draw_set_transform(Vector2(0.0, sy), 0.0, Vector2(1.0, ry_scale))
	draw_circle(Vector2.ZERO, rx * t, Color(0, 0, 0, 0.3 * t))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hurt_popups()


## 치즈가 받은 데미지 숫자 — 머리 위로 상승하며 점점 투명(빨강)
func _draw_hurt_popups() -> void:
	if _hurt_popups.is_empty():
		return
	var font: Font = preload("res://assets/fonts/DoHyeon-Regular.ttf")
	if font == null:
		return
	for p in _hurt_popups:
		var f: float = clampf(p["t"] / HURT_POP_DUR, 0.0, 1.0)
		var y := -236.0 - 48.0 * f
		var a := 1.0 - f
		var col := Color(1.0, 0.35, 0.3, a)   # 빨강(피해)
		var txt := "-" + str(p["amount"])
		var pos := Vector2(-40.0, y)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 28, 5, Color(0, 0, 0, a * 0.85))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 28, col)


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


## --- 공격 (근접/원거리 버튼 분리. 누르는 동안 attack_interval마다 발동) ---
##   근접 버튼(터치 / 키 K) → 근접 / 원거리 버튼(터치 / 키 L) → 원거리. 둘 다면 근접 우선.
func _handle_attack() -> void:
	if _sit_phase != "":
		return   # 앉은 중엔 공격 안 함
	if _fire_timer > 0.0:
		return
	var want_melee := Touch.melee_held or Input.is_key_pressed(KEY_K)
	var want_ranged := Touch.ranged_held or Input.is_action_pressed("attack")   # L = 원거리
	if not (want_melee or want_ranged):
		return
	_fire_timer = attack_interval / (ENCORE_ASPD if _encore_t > 0.0 else 1.0)   # 앵콜 공속 버프
	_attack_fired = false              # 새 공격 시작 → 준비동작 빠른 속도부터
	if want_melee:
		_committed_anim = "melee"        # 근접 모션(끝까지 재생)
		_melee_pending = melee_hit_delay # 딜은 모션 중간에(펀치 닿을 때)
	else:
		_committed_anim = "shoot"  # 사격 모션(끝까지 재생)
		if ranged_fire_delay > 0.0:
			_ranged_pending = ranged_fire_delay  # 모션 타이밍 맞춰 늦게 발사
		else:
			_fire_ranged()                       # 음악가 등은 즉시 발사
			_attack_fired = true                 # 즉시 발사 직업 → 마무리는 천천히


## 크리 판정 — 기본 데미지를 받아 (데미지, 넉백, 스턴, 크리여부) 산출.
## 평타는 약하게(작은 넉백), 크리 터지면 직업 효과가 강하게.
func _roll_attack(base_dmg: float) -> Dictionary:
	var dmg := base_dmg
	if _atk_buff_t > 0.0:
		dmg *= ATK_BUFF_MULT   # 말린 멸치 버프 중
	var kb := NORMAL_KNOCKBACK
	var stun := 0.0
	var is_crit := randf() < crit_chance
	if is_crit:
		match crit_type:
			"strike":    dmg *= crit_mult       # 보안관/맨몸: 강타
			"knockback": kb = CRIT_KNOCKBACK    # 메이드: 강넉백
			"stun":      stun = CRIT_STUN        # 음악가: 스턴
	return {"dmg": dmg, "kb": kb, "stun": stun, "crit": is_crit}


## 근접 공격 — 사정거리 안에서 "가까운 순으로 최대 3마리"만 때린다.
func _melee_attack() -> void:
	var hit := _roll_attack(near_damage)
	# 사정거리 안 적들을 거리와 함께 모은다
	var targets: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		# 지상 근접은 공중 적 못 때림 — 점프(공중)해서 높이 맞춰야 타격
		if on_ground and e.has_method("is_air") and e.is_air():
			continue
		var d := global_position.distance_to((e as Node2D).global_position)
		if d <= melee_range:
			targets.append({"e": e, "d": d})
	# 가까운 순 정렬 후 최대 MELEE_MAX_TARGETS마리만 타격
	targets.sort_custom(func(a, b): return a["d"] < b["d"])
	var n := mini(targets.size(), MELEE_MAX_TARGETS)
	for i in range(n):
		var e = targets[i]["e"]
		if e.has_method("take_damage"):
			e.take_damage(hit["dmg"], hit["kb"], hit["stun"], hit["crit"])


## 직업별 원거리 발사.
##   보안관: 일자 끝까지 + 가끔 불발 / 음악가: 일자 짧은 사거리(페이드) /
##   메이드·맨몸: 손으로 포물선 던지기(랜덤 각도, 위로도 던져짐).
func _fire_ranged() -> void:
	if bullet_scene == null:
		return
	# 보안관 불발 — 총알이 힘없이 나가 바로 앞에 툭 떨어짐(데미지 0) + "철컥" 소리.
	if ranged_misfire > 0.0 and randf() < ranged_misfire:
		var dud := bullet_scene.instantiate()
		dud.global_position = global_position + muzzle_offset
		get_parent().add_child(dud)
		if dud.has_method("setup"):
			dud.setup({
				"mode": "lob", "shape": "dot",
				"dmg": 0.0, "kb": 0.0, "stun": 0.0, "crit": false,
				"vx": randf_range(120.0, 210.0), "vy": -randf_range(90.0, 180.0),
				"gravity": 2400.0,
			})
		if is_instance_valid(_click_player):
			_click_player.play()
		return
	var hit := _roll_attack(ranged_damage)
	var cfg := {"dmg": hit["dmg"], "kb": hit["kb"], "stun": hit["stun"], "crit": hit["crit"]}
	var is_lob := ranged_mode == "lob"
	var is_gun := ranged_mode == "straight" and ranged_limit_frac <= 0.0  # 보안관 총만
	if is_lob:
		# 손 던지기: 항상 같은 45도 포물선 → 수평 사거리 ≈ 화면 절반(일정해서 조준 가능).
		#   45도 사거리 R = v²/g, v²=2u² → R=2u²/g. R=화면½ 로 u 역산.
		var screen_w := get_viewport_rect().size.x
		var g := LOB_GRAVITY
		var u := sqrt(screen_w * 0.22 * g)   # 45도 성분(vx=vy=u). 머즐 높이 보정해 착지 ≈ 화면 절반
		cfg["mode"] = "lob"
		cfg["shape"] = ranged_shape   # 맨몸=돌(stone) / 메이드=접시(plate)
		cfg["vx"] = u
		cfg["vy"] = -u
		cfg["gravity"] = g
	elif is_gun:
		# 보안관: 빠른 직선 총알, 끝까지
		cfg["mode"] = "straight"
		cfg["dir"] = Vector2.RIGHT
		cfg["shape"] = "dot"
		cfg["speed"] = SHERIFF_BULLET_SPEED
	else:
		# 음악가: 음표(랜덤 모양) + 느림(랜덤) + 물결(랜덤) + 짧은 사거리(페이드)
		cfg["mode"] = "straight"
		cfg["dir"] = Vector2.RIGHT
		cfg["shape"] = "note"
		cfg["note_type"] = randi() % JAZZ_NOTE_TYPES
		cfg["speed"] = randf_range(JAZZ_SPEED_MIN, JAZZ_SPEED_MAX)
		cfg["max_range"] = get_viewport_rect().size.x * ranged_limit_frac
		cfg["fade_start"] = JAZZ_FADE_START
		cfg["wave_amp"] = randf_range(JAZZ_WAVE_AMP_MIN, JAZZ_WAVE_AMP_MAX)
		cfg["wave_freq"] = TAU / randf_range(JAZZ_WAVE_LEN_MIN, JAZZ_WAVE_LEN_MAX)
	var bullet := bullet_scene.instantiate()
	bullet.global_position = global_position + muzzle_offset
	get_parent().add_child(bullet)
	if bullet.has_method("setup"):
		bullet.setup(cfg)
	# 보안관 총 발사: 큰 화염 + 화면 흔들림(불발과 확 차이)
	if is_gun and is_instance_valid(muzzle_fx):
		muzzle_fx.flash()
		Fx.request_shake(5.0)


func _nearest_enemy(exclude_air: bool = false) -> Node2D:
	var nearest: Node2D = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		# 지상에선 공중 적을 근접 대상에서 제외(점프해야 닿음) → 지상에선 원거리로 처리
		if exclude_air and on_ground and e.has_method("is_air") and e.is_air():
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
	if GameState.cheats.get("godmode", false):   # 개발자 치트: 무적
		return
	if _guard_t > 0.0:
		amount *= (1.0 - _guard_pct)   # 방패 자세: 피해 감소
	if amount >= 1.0:
		_hurt_popups.append({"amount": int(round(amount)), "t": 0.0})   # 받은 데미지 숫자
	health -= amount
	_hurt_flash_timer = 0.15
	_committed_anim = "hit"   # 피격 모션(끝까지·빠르게), 진행 중 공격 취소
	_melee_pending = -1.0
	_ranged_pending = -1.0
	_sit_phase = ""           # 맞으면 앉기 해제
	if health <= 0.0:
		health = 0.0
		_dead = true
		died.emit()   # 게임오버 — game.gd가 연출 처리


## --- 소모품 효과 (로드맵 4단계 §5.4) ---
## 낡은 붕대: 즉시 고정 회복(최대 초과 안 함)
func heal(amount: float) -> void:
	if _dead:
		return
	health = minf(max_health, health + amount)

## 말린 멸치: 공격력 버프 dur초(중첩 시 더 긴 쪽 유지)
func apply_atk_buff(dur: float) -> void:
	if _dead:
		return
	_atk_buff_t = maxf(_atk_buff_t, dur)

## 폭죽: 살아있는 모든 적에게 고정 광역 데미지
func aoe_damage(amount: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		if e.has_method("take_damage"):
			e.take_damage(amount, 0.0, 0.0, false)

## --- 스킬 자가 효과 (로드맵 5단계) ---
## 방패 자세: dur초 동안 받는 피해 pct만큼 감소
func apply_guard(dur: float, pct: float) -> void:
	if _dead:
		return
	_guard_t = maxf(_guard_t, dur)
	_guard_pct = pct

## 앵콜: dur초 동안 공속+40%·이속+20%
func apply_encore(dur: float) -> void:
	if _dead:
		return
	_encore_t = maxf(_encore_t, dur)


## 적 발사체/근접의 상태이상 — 독(지속딜) / 둔화(이동 감속)
func apply_status(st: String) -> void:
	if _dead or GameState.cheats.get("godmode", false):
		return
	match st:
		"poison":
			_poison_timer = 3.0
			_poison_tick = 0.5
		"slow":
			_slow_timer = 2.5


## 독 지속 데미지 — 피격 모션 없이 체력만 깎음(틱마다 호출)
func _poison_damage(amount: float) -> void:
	if _dead:
		return
	_hurt_popups.append({"amount": int(round(amount)), "t": 0.0})
	health -= amount
	if health <= 0.0:
		health = 0.0
		_dead = true
		died.emit()


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
		ss = ATTACK_RECOVER_SPEED if _attack_fired else ATTACK_PREP_SPEED   # 준비=빠름 / 발사후=자연스럽게
	elif next == "hit":
		ss = HIT_ANIM_SPEED
	elif next == "jump":
		match _jump_state:
			"prep": ss = JUMP_PREP_SPEED
			"air":  ss = JUMP_AIR_SPEED
			"land": ss = JUMP_LAND_SPEED
	elif next == "sit":
		ss = SIT_SPEED      # 앉기/일어나기 빠르게(회피용)
	anim.speed_scale = ss

	# 앉기: 누르고 있는 동안 완전히 숙인 프레임에서 정지(떼면 일어남 재생)
	if next == "sit" and _sit_phase == "down" and anim.frame >= SIT_HOLD_FRAME:
		anim.frame = SIT_HOLD_FRAME
		anim.speed_scale = 0.0
