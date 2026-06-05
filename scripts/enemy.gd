extends CharacterBody2D
## 적 (범용) — def(Enemies.ENEMY_DEFS)로 종류별 스탯·생김새·행동을 받는다.
##   침입자 10종 모두 실제 스프라이트(ENEMY_FRAMES: 회색3·박쥐·벌·참새·거미 + 검은3=회색 셰이더 리스킨).
##   placeholder(_draw 도형)는 보스 2종(boss_fungus·boss_snake, def "sprite":false)만.
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
const ENEMY_FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const DMG_POP_DUR := 0.8
const AIR_HEIGHT := 230.0   # 공중 적이 떠 있는 높이(px)
const STAGE_ENTER_MARGIN := 100.0   # 원거리 적은 화면 우측에서 이만큼 안으로 들어와야 멈춰 발사(스폰 밖 정지 방지)
## 침입자별 SpriteFrames(검은 계열은 회색 프레임 재사용 + 어둡게 모듈레이트)
const ENEMY_FRAMES := {
	"gray":          "res://assets/sprites/enemies/gray/gray_frames.tres",
	"gray_roller":   "res://assets/sprites/enemies/gray_roller/gray_roller_frames.tres",
	"gray_thrower":  "res://assets/sprites/enemies/gray_thrower/gray_thrower_frames.tres",
	"black":         "res://assets/sprites/enemies/gray/gray_frames.tres",
	"black_roller":  "res://assets/sprites/enemies/gray_roller/gray_roller_frames.tres",
	"black_thrower": "res://assets/sprites/enemies/gray_thrower/gray_thrower_frames.tres",
	"bat":           "res://assets/sprites/enemies/bat/bat_frames.tres",
	"bee":           "res://assets/sprites/enemies/bee/bee_frames.tres",
	"sparrow":       "res://assets/sprites/enemies/sparrow/sparrow_frames.tres",
	"spider":        "res://assets/sprites/enemies/spider/spider_frames.tres",
}
const BLACK_IDS := ["black", "black_roller", "black_thrower"]   # 회색 프레임 리스킨
const DARK_SHADER := preload("res://assets/shaders/enemy_darken.gdshader")
const GHOST_FRAMES := preload("res://assets/sprites/ghost/ghost_frames.tres")   # 통일 죽음 귀신
# 종류별 화면 크기 배율(쥐·투척쥐 제외하고 키움). 기본 1.0.
const SIZE_MULT := {
	"gray_roller": 1.28, "black_roller": 1.18,
	"black": 1.05, "black_thrower": 0.93,   # 검은쥐 3종 ≈ 회색투척쥐 크기
	"bat": 1.35, "bee": 1.40, "sparrow": 1.16, "spider": 1.32,
}
# 발 위치 미세조정(양수=아래로 내려 지면에 더 가깝게). fh*sc 비율.
const FOOT_NUDGE := {"spider": 0.14}
## 발 그림자 보정 — 스프라이트별 [발 중심 x(프레임px·중심기준), 발 반폭(프레임px)]. ×스프라이트배율 = 화면px.
##   그림자를 실제 발 footprint에 맞춤(좌우 쏠림·폭 보정). 미등록 적=기본(중심·_body_r). black=gray 프레임 재사용.
const SHADOW_FOOT := {
	"gray": [36.0, 81.0], "gray_roller": [28.0, 67.0], "gray_thrower": [2.0, 161.0],
	"black": [36.0, 81.0], "black_roller": [28.0, 67.0], "black_thrower": [2.0, 161.0],
	"spider": [-10.0, 153.0], "bee": [30.0, 37.0], "sparrow": [40.0, 104.0], "bat": [48.0, 42.0],
}
const WINDUP_MELEE := 0.22    # 근접(placeholder 폴백): 모션 시작 후 타격까지
const WINDUP_RANGED := 0.30   # 원거리(placeholder 폴백): 모션 시작 후 발사까지
# attack 애니에서 발사/타격이 일어나는 프레임(스프라이트 분석값).
const ATK_RELEASE := {
	"gray_thrower": 8, "black_thrower": 8,
	"bee": 7, "spider": 9, "bat": 4, "sparrow": 6,
}
# 사거리 안에서 attack 사이클을 루프하며 연속발사(발사=ATK_RELEASE 프레임).
const LOOP_SHOOTERS := ["gray_thrower", "black_thrower", "spider", "bee"]
# 발사 프레임에서 탄환 생성 위치(스프라이트 중심 기준 프레임px). 손/침/복부/입.
const EMIT_OFFSET := {
	"gray_thrower":  Vector2(-118, 0),    # 던지는 손
	"black_thrower": Vector2(-118, 0),
	"bee":           Vector2(-110, 72),   # 엉덩이 침(좌하단)
	"spider":        Vector2(-115, 30),   # 엉덩이가 좌측 향할 때(#9) 뾰족한 끝(좌하단)
	"bat":           Vector2(-51, -15),   # 입(좌)
}
# 공중 상하진동: c=평균 높이(px,위로) / a=진폭 / s=각속도. 최저점(바닥)=c-a.
const AIR_BOB := {
	"bat":     {"c": 221.0, "a": 120.0, "s": 1.6},   # 폭 큼: 최저점=치즈 얼굴 높이
	"bee":     {"c": 250.0, "a": 40.0,  "s": 3.6},   # 작고 빠르게
	"sparrow": {"c": 145.0, "a": 130.0, "s": 2.4},   # 크게 내려와 쪼기
}

# def에서 채워지는 행동/외형
var def: Dictionary = {}
var _kind := "melee"
var _air := false
var _high := false    # 박쥐: 머리 높이 수평 음파(서면 맞고 앉으면 회피)
var _big := false     # 보스: 큰 덩치 → 히트박스 확대 + 밀기 불가
var _status := ""
var _use_sprite := true
var _has_idle := false      # 침입자 프레임에 idle 있나(공중=walk만)
var _has_attack := false    # attack 애니 있나
var _color := Color(0.6, 0.6, 0.62)
var _bcolor := Color(0.7, 0.7, 0.7)
var _body_r := 44.0
var _coin := 0        # 처치 시 지급 코인
var _id := ""         # 적 id(전리품 드랍용)
var _atk_range := 0.0
var _armor := 0.0
var _ename := "회색쥐"
var _base_modulate := Color(1, 1, 1)

var health: float
var dead: bool = false
var _phase_timer: float = 0.0
var _walking: bool = true
var _hit: bool = false
var _hit_timer: float = 0.0    # placeholder 적의 피격 경직 회복 타이머(hit 애니가 없으므로)
var _attack_timer: float = 0.0
var _push_vx: float = 0.0
var _flash: float = 0.0
var _flash_crit: bool = false
var _knockback: float = 0.0
var _stun_timer: float = 0.0
var _eslow_timer: float = 0.0    # 스킬 둔화(왁스칠·불협화음 등) 남은 시간
var _eslow_factor: float = 1.0   # 둔화 시 이동 배율
var _lunge: float = 0.0        # 근접 찌르기 모션 타이머
var _windup: float = 0.0           # placeholder 폴백: 공격 모션 후 타격까지 남은 시간
var _pending_release: bool = false # 공격 모션 재생 중, 발사/타격 프레임 대기
var _release_ranged: bool = false
var _loop_active: bool = false     # 루프 슈터: 교전 중 attack 사이클 루프 진행 여부
var _loop_prev_frame: int = -1     # 발사프레임 통과 감지용(직전 프레임)
var _air_phase: float = 0.0        # 공중 상하진동 위상
var _air_dip_armed: bool = true    # 바닥(최저점) 1회 트리거 준비
var _sprite_foot_y: float = 0.0    # 스프라이트 발 기준 y
var _sprite_sc: float = 1.0        # 스프라이트 배율(그림자 발 footprint 환산용)
var _size_mult: float = 1.0        # 화면 크기 배율(그림자 크기에도 반영)
var _popups: Array = []

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	# 충돌 레이어를 코드로 명시(.tscn 헤더값은 Godot이 무시함):
	#   layer 2 = 적 / mask 4 = 플레이어(관문)만. 적끼리(layer 2)는 안 막혀 통과(겹침 허용).
	collision_layer = 2
	collision_mask = 4
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
		_air_phase = randf() * TAU   # 개체마다 진동 위상 분산(군집이 따로 출렁이게)


func _apply_def() -> void:
	max_health = float(def.get("hp", 20))
	damage = float(def.get("dmg", 5))
	attack_interval = float(def.get("atkint", 1.0))
	move_speed = 120.0 * float(def.get("spd", 1.0))
	# 적별 걷·멈 리듬(없으면 @export 기본 1.5/1.0 유지). 이후 _ready의 randf가 곱해짐.
	walk_time = float(def.get("wt", walk_time))
	stop_time = float(def.get("st", stop_time))
	_kind = def.get("kind", "melee")
	_air = def.get("air", false)
	_high = def.get("high", false)
	_big = def.get("big", false)
	_status = def.get("status", "")
	_use_sprite = def.get("sprite", true)
	_color = def.get("color", Color(0.6, 0.6, 0.62))
	_bcolor = def.get("bcolor", Color(0.7, 0.7, 0.7))
	_body_r = float(def.get("radius", 44)) * 1.25   # 치즈(원본 100%)와 균형 맞춘 적 크기(원본 ×1.25)
	_atk_range = float(def.get("range", 0))
	_coin = int(def.get("coin", 0))
	_id = String(def.get("id", ""))
	_armor = float(def.get("armor", 0))
	_ename = def.get("name", "침입자")
	# 침입자별 SpriteFrames 로드(있으면 placeholder 대신 실제 스프라이트)
	if ENEMY_FRAMES.has(_id):
		var sf: SpriteFrames = load(ENEMY_FRAMES[_id])
		if sf != null:
			if _id in LOOP_SHOOTERS:
				sf = sf.duplicate(true)                       # 공유 리소스 보호
				sf.set_animation_loop("attack", true)          # 발사 사이클 무한 루프
			anim.sprite_frames = sf
			_use_sprite = true
			_has_idle = sf.has_animation("idle")
			_has_attack = sf.has_animation("attack")
			var fh: float = float(sf.get_frame_texture("walk", 0).get_height())
			_size_mult = float(SIZE_MULT.get(_id, 1.0))       # 종류별 크기 보정(그림자에도)
			var sc: float = (_body_r * 2.6) / maxf(fh, 1.0) * _size_mult
			_sprite_sc = sc                                    # 그림자 발 footprint 환산용
			anim.scale = Vector2(sc, sc)
			var nudge: float = float(FOOT_NUDGE.get(_id, 0.0)) * fh * sc
			_sprite_foot_y = -fh * sc * 0.5 + nudge           # 발이 원점(+nudge=지면에 더 가깝게)
			anim.position = Vector2(0, _sprite_foot_y)
			if _id in BLACK_IDS:
				var mat := ShaderMaterial.new()                # 회색 몸통만 어둡게(흰 손·눈 유지)
				mat.shader = DARK_SHADER
				anim.material = mat
	if _use_sprite and _color.v < 0.45 and not ENEMY_FRAMES.has(_id):
		_base_modulate = _color   # 프레임 없는 어두운 placeholder만 곱연산 다크(검은쥐는 셰이더가 처리)
	# 보스: 큰 덩치에 맞춰 히트박스(탄환 명중)를 몸 중심으로 확대
	if _big:
		var hb_shape := RectangleShape2D.new()
		hb_shape.size = Vector2(_body_r * 1.7, _body_r * 2.2)
		$Hitbox/CollisionShape2D.shape = hb_shape
		$Hitbox.position.y = -(_body_r + 12.0)   # placeholder 몸 중심


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
	if _eslow_timer > 0.0:
		_eslow_timer -= delta
	if _lunge > 0.0:
		_lunge -= delta
	# 피격 경직 해제 = 타이머(모든 적 안전망). 루프슈터(투척쥐 등)는 hit 애니가
	#   _play_move_anim에 가로채여 animation_finished("hit")가 안 와 _hit이 영영 안 풀리던 버그 방지.
	if _hit:
		_hit_timer -= delta
		if _hit_timer <= 0.0:
			_hit = false

	if not stunned and not dead:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_walking = not _walking
			_phase_timer = walk_time if _walking else stop_time
			if _use_sprite and not _hit and not dead and not _pending_release and not _loop_active and anim.animation != "attack":
				_play_move_anim()

	var ranged := _kind == "lob" or _kind == "shoot"
	var dist := _dist_to_player()

	# 이동
	var base_vx := 0.0
	if not stunned:
		if _push_vx > 0.0:
			base_vx = _push_vx
		elif _walking and not _hit and not dead:
			# 지상 원거리(투척쥐·거미)만 사거리에서 멈춰 발사(다가오지 않음).
			# 공중 원거리(박쥐·벌)는 멈추지 않고 계속 비행하며 발사(§3.1 "비행(멈춤 없음)").
			if ranged and not _air and _atk_range > 0.0 and dist <= _atk_range and _on_stage():
				base_vx = 0.0
			else:
				base_vx = -move_speed * (_eslow_factor if _eslow_timer > 0.0 else 1.0)
	_knockback = move_toward(_knockback, 0.0, 420.0 * delta)
	velocity.x = base_vx + _knockback
	velocity.y = 0.0
	move_and_slide()
	_push_vx = 0.0

	# 공격
	if _id in LOOP_SHOOTERS:
		# 사거리 안에서 attack 사이클 루프 + ATK_RELEASE 프레임마다 발사(투척쥐·거미·벌).
		_update_loop_shooter(delta, dist, stunned)
	elif _air and AIR_BOB.has(_id):
		# 공중 바닥트리거(박쥐·참새): 진동 최저점에서 공격 시작 → 발사/타격은 release 프레임.
		_update_air_attacker(dist, stunned)
		_resolve_pending_release(delta)
	else:
		# 일반(쥐 근접 등): 트리거 시 모션 먼저 → release 프레임(또는 폴백 시간)에 타격.
		_attack_timer -= delta
		if not stunned and not dead and not _pending_release and _attack_timer <= 0.0:
			if ranged:
				if _atk_range > 0.0 and dist <= _atk_range and _on_stage():
					_attack_timer = attack_interval
					_start_attack(true)
			elif _is_touching_player():
				_attack_timer = attack_interval
				_start_attack(false)
		_resolve_pending_release(delta)

	# 스프라이트 적: 근접 찌르기 + 번쩍/스턴 색
	if _use_sprite:
		anim.position.x = -(_lunge / 0.16) * 16.0 if _lunge > 0.0 else 0.0
		if _air and AIR_BOB.has(_id):
			# 공중 상하진동. 박쥐·참새는 공격 모션 중엔 위상 정지(최저점에 머물러 타격).
			var freeze: bool = anim.animation == "attack" and (_id == "bat" or _id == "sparrow")
			if not freeze:
				_air_phase += float(AIR_BOB[_id]["s"]) * delta
			var raise: float = float(AIR_BOB[_id]["c"]) + sin(_air_phase) * float(AIR_BOB[_id]["a"])
			anim.position.y = _sprite_foot_y - raise
			$Hitbox.position.y = anim.position.y          # 보이는 높이에서 맞게
		else:
			anim.position.y = _sprite_foot_y
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


## 공격 트리거 — 모션을 먼저 재생, 발사/타격은 release 프레임(또는 폴백 시간)에.
func _start_attack(is_ranged: bool) -> void:
	_pending_release = true
	_release_ranged = is_ranged
	_lunge = 0.16
	if _use_sprite and _has_attack and not _hit:
		anim.play("attack")
		anim.frame = 0
	# placeholder(스프라이트/ATK_RELEASE 없음) 폴백용 시간
	_windup = WINDUP_RANGED if is_ranged else WINDUP_MELEE


## 대기 중인 공격 해소: 스프라이트는 release 프레임 도달 시, 그 외는 시간 경과 시.
func _resolve_pending_release(delta: float) -> void:
	if not _pending_release:
		return
	if _use_sprite and ATK_RELEASE.has(_id):
		if anim.animation == "attack" and anim.frame >= int(ATK_RELEASE[_id]):
			_pending_release = false
			_resolve_attack()
	else:
		_windup -= delta
		if _windup <= 0.0:
			_pending_release = false
			_resolve_attack()


## 루프 슈터(투척쥐·거미·벌): 교전 중 attack 사이클을 계속 루프,
## ATK_RELEASE 프레임 통과 순간 발사. 루프 속도를 공격 간격에 맞춤. idle 안 씀.
func _update_loop_shooter(delta: float, dist: float, stunned: bool) -> void:
	var in_range := _atk_range > 0.0 and dist <= _atk_range and _on_stage()
	if stunned or dead or _hit or not in_range:
		if _loop_active:
			_loop_active = false
			anim.speed_scale = 1.0
			if not _hit:           # _hit이면 hit 애니 재생 중 → 가로채지 않음
				_play_move_anim()
		return
	if not _loop_active or anim.animation != "attack":
		_loop_active = true
		_loop_prev_frame = -1
		var fc := float(anim.sprite_frames.get_frame_count("attack"))
		var fs: float = maxf(anim.sprite_frames.get_animation_speed("attack"), 1.0)
		var base_dur := fc / fs                                  # 전체 사이클 길이(초)
		anim.speed_scale = clampf(base_dur / maxf(attack_interval, 0.4), 0.5, 3.0)
		anim.play("attack")
		anim.frame = 0
	var rf := int(ATK_RELEASE[_id])
	if anim.frame == rf and _loop_prev_frame != rf:
		_fire_projectile()
	_loop_prev_frame = anim.frame


## 공중 바닥트리거(박쥐·참새): 진동 최저점(sin≈-1)에서 1회 공격 시작.
##   박쥐=사거리 내 음파(얼굴 높이), 참새=x로 가까우면 쪼기.
func _update_air_attacker(dist: float, stunned: bool) -> void:
	if stunned or dead or _hit or _pending_release:
		return
	var s := sin(_air_phase)
	if s > -0.2:
		_air_dip_armed = true                  # 위로 떠오르면 다음 바닥트리거 준비
	if _air_dip_armed and s < -0.85:           # 최저점 부근
		var can := false
		if _kind == "dive":
			can = _is_touching_player()        # 참새: 치즈에 가까울 때만 쪼기
		else:
			can = _atk_range > 0.0 and dist <= _atk_range   # 박쥐: 사거리 내
		if can:
			_air_dip_armed = false
			_start_attack(_kind != "dive")     # 박쥐=원거리, 참새=근접


## release 프레임에서 실제 발사/타격. 그 사이 죽거나 경직/스턴되면 취소.
func _resolve_attack() -> void:
	if dead or _stun_timer > 0.0 or _hit:
		return
	if _release_ranged:
		if _atk_range > 0.0 and _dist_to_player() <= _atk_range * 1.25:
			_fire_projectile()
		return
	# 근접
	if _is_touching_player() or _kind == "dive":
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("take_damage"):
			player.take_damage(damage)
			if _status != "" and player.has_method("apply_status"):
				player.apply_status(_status)


func _fire_projectile() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_lunge = 0.16
	var b := ENEMY_BULLET.instantiate()
	var bcol := _bcolor            # 발사체 색(아래에서 종류별 지정)
	if _kind == "lob":
		b.shape = "stone"          # 투척쥐 = 돌멩이. 회색=치즈 돌과 동일 / 검은투척쥐=어둡게.
		bcol = Color(0.26, 0.23, 0.22) if _id == "black_thrower" else Color(0.55, 0.55, 0.58)
	elif _id == "bee":
		b.shape = "cone"           # 벌 = 원뿔 독침
	elif _id == "spider":
		b.shape = "web"            # 거미 = 흰 거미줄
		bcol = Color(1, 1, 1)
	elif _id == "bat":
		b.shape = "sonic"          # 박쥐 = 초음파
		bcol = Color(0.85, 0.95, 1.0)

	# 박쥐: 입 위치(현재 비행 높이=최저점이면 치즈 얼굴)에서 수평 음파. 서면 맞고 앉으면 회피.
	if _high:
		var emit := _emit_pos()
		b.global_position = emit
		b.hit_y_offset = emit.y - global_position.y    # 음파가 지나는 높이(바닥 기준)
		b.dodge_by_crouch = true
		get_parent().add_child(b)
		b.setup(Vector2(-460.0, 0.0), damage, _status, bcol, 0.0)   # 수평 직선
		return

	var origin := _emit_pos()
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
		b.setup(Vector2(vx, vy), damage, _status, bcol, g)
	else:
		var dir := (target - origin).normalized()
		b.setup(dir * 520.0, damage, _status, bcol, 0.0)                   # 직선


## 탄환 생성 위치(월드). 스프라이트 부위(EMIT_OFFSET) 기준, 없으면 폴백.
func _emit_pos() -> Vector2:
	var base := global_position + anim.position    # 스프라이트 중심(공중=진동 반영)
	if _use_sprite and EMIT_OFFSET.has(_id):
		var off: Vector2 = EMIT_OFFSET[_id] * anim.scale.x
		if anim.flip_h:
			off.x = -off.x
		return base + off
	var oy: float = anim.position.y if (_air and _use_sprite) else -90.0
	return global_position + Vector2(-10, oy)


## 치즈 지상 근접이 닿는지 판단용: 현재 떠 있는 높이(px, 양수). 낮을수록 지상에서 타격 가능.
func air_height_now() -> float:
	return _air_raise()


## 공중 적의 현재 떠 있는 높이(px, 양수). 진동 스프라이트는 실시간 높이, 그 외 폴백.
func _air_raise() -> float:
	if _air and _use_sprite and AIR_BOB.has(_id):
		return -anim.position.y
	return AIR_HEIGHT if _air else 0.0


func _dist_to_player() -> float:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return 99999.0
	return absf(global_position.x - (p as Node2D).global_position.x)


## 원거리 적이 "멈춰서 발사"해도 되는 위치인지 = 화면(스테이지) 안에 충분히 들어왔는지.
##   치즈가 우측 스폰 근처에서 버텨도 적이 화면 밖에서 멈추지 않고 최소한 안으로 들어오게.
func _on_stage() -> bool:
	return global_position.x <= get_viewport_rect().size.x - STAGE_ENTER_MARGIN


func _draw() -> void:
	_draw_damage_popups()
	if dead:
		return
	# 발밑 그림자 — 발 footprint에 맞춤(좌우 쏠림 보정 + 폭=max(_body_r, 발폭)) + 공중 높이 연동.
	var sh_t := 1.0
	if _air:
		sh_t = clampf(1.0 - _air_raise() / 500.0, 0.30, 1.0)
	var sh_rx := _body_r * _size_mult
	var sh_x := 0.0
	if SHADOW_FOOT.has(_id):
		var sfd: Array = SHADOW_FOOT[_id]
		sh_x = float(sfd[0]) * _sprite_sc * (-1.0 if (_use_sprite and anim.flip_h) else 1.0)   # 발 중심으로(반전 반영)
		sh_rx = maxf(sh_rx, float(sfd[1]) * _sprite_sc)                                          # 발폭이 넓으면 그만큼
	var sh_lift := sh_rx * sh_t * Layout.SHADOW_LIFT_FRAC   # 접지점에 붙게 살짝 위로
	draw_set_transform(Vector2(sh_x, -sh_lift), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, sh_rx * sh_t, Color(0, 0, 0, 0.3 * sh_t))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# placeholder 몸 (스프라이트 안 쓰는 적 — 보스 등. 공중 스프라이트 적은 여기 안 옴)
	if not _use_sprite:
		var cy := -_body_r - 12.0 - _air_raise()
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
		var hy := -158.0 - _air_raise()
		var ratio := clampf(health / max_health, 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, hy, w, 9.0), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(-w * 0.5, hy, w * ratio, 9.0), Color(0.95, 0.25, 0.2, 1.0))
		draw_rect(Rect2(-w * 0.5, hy, w, 9.0), Color(1, 1, 1, 0.6), false, 1.5)


func _draw_damage_popups() -> void:
	if _popups.is_empty():
		return
	var font: Font = ENEMY_FONT
	var base_y := -174.0 - _air_raise()
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
	if dead or _air or _big:    # 공중 적·보스는 밀기 대상 아님
		return
	_push_vx = max(_push_vx, amount)


func is_dead() -> bool:
	return dead


## 공중 적인지 — 치즈가 지상 근접으로 못 때리고, 점프해야 닿음
func is_air() -> bool:
	return _air


## play_sfx: false면 피격음을 내지 않는다(근접 다중타격은 player가 휘두름당 1번만 재생).
func take_damage(amount: float, knockback: float = 70.0, stun: float = 0.0, crit: bool = false, play_sfx: bool = true) -> void:
	if dead:
		return
	# 공중 적도 "실제로 닿은" 공격이면 데미지 적용:
	#   · 투사체(포물선/총알) = 닿으면 명중(지상에서 던진 포물선이 호로 닿아도 OK)
	#   · 근접 = 닿지 못함(player._melee_attack에서 지상이면 공중 적 제외 → 점프해야 타격)
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
		_hit_timer = 0.22        # placeholder 회복 시간(sprite는 hit 애니 종료로 해제)
		_flash = 0.12
		_flash_crit = crit
		_knockback = maxf(_knockback, knockback)
		if stun > 0.0:
			_begin_stun(stun)   # 음악가 크리 스턴도 별빙글 표시(스턴=별빙글 통일)
		Fx.request_shake(7.0 if crit else 3.0)
		if play_sfx:
			Sfx.impact(crit)   # 근접·원거리 통일(punch), 크리=퍼벅
		var _fy := -50.0 - _air_raise()
		if crit:
			Fx.burst("critical_hit", global_position + Vector2(0, _fy), 0.62, 45)
		else:
			Fx.burst("impact_flash", global_position + Vector2(0, _fy), 0.42, 45)
		if knockback >= 140.0:
			Fx.burst("knockback", global_position + Vector2(0, _fy), 0.5, 44)   # 강한 넉백 whoosh
		if _use_sprite:
			anim.play("hit")


## 스킬 둔화(이동 배율 factor로 dur초) — 왁스칠·불협화음
func apply_slow(dur: float, factor: float) -> void:
	if dead:
		return
	_eslow_timer = maxf(_eslow_timer, dur)
	_eslow_factor = factor
	Fx.burst("slime_drip", global_position + Vector2(0, -42.0 - _air_raise()), 0.4, 44, 14.0, true, minf(dur, 1.2))

## 스킬 스턴(완전 정지 dur초) — 자장가. 데미지·넉백 없음
func apply_stun(dur: float) -> void:
	if dead:
		return
	_begin_stun(dur)

## 스턴 적용 공통 — 타이머 갱신 + 별빙글 이펙트(스턴=별빙글 통일: 자장가·음악가 크리 둘 다).
func _begin_stun(dur: float) -> void:
	if dur <= 0.0 or dead:
		return
	_stun_timer = maxf(_stun_timer, dur)
	Fx.burst("dizzy_stars", global_position + Vector2(0, -92.0 - _air_raise()), 0.46, 46, 14.0, true, dur)


## 이동/정지 애니(idle 있으면 정지 시 idle, 아니면 walk).
func _play_move_anim() -> void:
	_loop_active = false
	if _use_sprite:
		anim.speed_scale = 1.0
	# 원거리 적이 사거리 안에서 교전 중이면(멈춰 발사) 발사 사이에 idle 유지.
	var engaged := (_kind == "lob" or _kind == "shoot") and _atk_range > 0.0 and _dist_to_player() <= _atk_range and _on_stage()
	if _has_idle and (not _walking or engaged):
		if anim.animation != "idle":
			anim.play("idle")
	elif anim.animation != "walk":
		anim.play("walk")


func _on_anim_finished() -> void:
	if dead:
		queue_free()
	elif anim.animation == "hit" or anim.animation == "attack":
		_hit = false
		_play_move_anim()   # 투척쥐 attack은 네이티브 루프라 여기 안 옴


func _die() -> void:
	dead = true
	GameState.enemy_killed.emit()                                    # 스테이지 이벤트 트리거(첫 처치 등)
	GameState.add_coins(int(round(_coin * GameState.run_coin_mult)))   # 처치 코인(§3.1, 곳간 축복 배율)
	for mid in Enemies.roll_drops(_id):   # 전리품 드랍(§5.2)
		GameState.add_material(mid)
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$Hitbox.set_deferred("monitorable", false)
	# 클리어(마지막 처치) 시 트리가 일시정지돼도 죽음 연출(귀신·펑)이 끝까지 재생되게.
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()
	var pop := POP.instantiate()
	pop.process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(pop)
	pop.global_position = global_position + Vector2(0, -45 - _air_raise())
	Fx.request_shake(7.0)
	Fx.request_hitstop(0.05)
	Fx.burst("poof_explosion", global_position + Vector2(0, -45.0 - _air_raise()), 0.6, 47)
	Sfx.play("pop")
	_show_ghost()


## 통일 죽음 귀신: 적 크기에 비례, 그 자리에서 점점 투명·위로 떠올라 사라짐.
func _show_ghost() -> void:
	anim.visible = true
	anim.material = null                  # 검은쥐 셰이더 제거(귀신은 흰색)
	anim.flip_h = false
	anim.speed_scale = 1.0
	anim.modulate = Color(1, 1, 1, 1)
	anim.sprite_frames = GHOST_FRAMES
	anim.play("float")
	var gh: float = float(GHOST_FRAMES.get_frame_texture("float", 0).get_height())
	var gsc: float = (_body_r * 2.4 * _size_mult) / maxf(gh, 1.0)   # 적 크기 비례
	anim.scale = Vector2(gsc, gsc)
	# 시작 위치 = 적 몸 중심(공중은 진동 높이 반영)
	var start_y: float = anim.position.y if _use_sprite else (-_body_r - 12.0)
	anim.position = Vector2(0, start_y)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(anim, "position:y", start_y - 130.0, 1.1)   # 위로 떠오름
	t.tween_property(anim, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)  # 점점 투명
	t.chain().tween_callback(queue_free)
