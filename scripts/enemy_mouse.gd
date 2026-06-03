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
const ENEMY_FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const DMG_POP_DUR := 0.8
const AIR_HEIGHT := 230.0   # 공중 적이 떠 있는 높이(px)
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
var _dive: float = 0.0         # 참새 급강하(공격 때 내려갔다 올라옴) 타이머
const DIVE_DUR := 0.5
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
		anim.position.y -= AIR_HEIGHT
		$Hitbox.position.y -= AIR_HEIGHT   # 공중 적은 그려진 위치에서 맞게


func _apply_def() -> void:
	max_health = float(def.get("hp", 20))
	damage = float(def.get("dmg", 5))
	attack_interval = float(def.get("atkint", 1.0))
	move_speed = 120.0 * float(def.get("spd", 1.0))
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
			anim.sprite_frames = sf
			_use_sprite = true
			_has_idle = sf.has_animation("idle")
			_has_attack = sf.has_animation("attack")
			var fh: float = float(sf.get_frame_texture("walk", 0).get_height())
			var sc: float = (_body_r * 2.6) / maxf(fh, 1.0)   # 화면 표시 높이 = 몸크기 기준
			if _id in BLACK_IDS:
				sc *= 1.12                                     # 검은쥐 3종 = 회색보다 약간 크게
			anim.scale = Vector2(sc, sc)
			anim.position = Vector2(0, -fh * sc * 0.5)         # 발이 원점(바닥선)
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
	if _dive > 0.0:
		_dive -= delta
	# placeholder 적: hit 애니가 없어 타이머로 피격 경직 해제(안 그러면 영영 멈춤)
	if _hit and not _use_sprite:
		_hit_timer -= delta
		if _hit_timer <= 0.0:
			_hit = false

	if not stunned and not dead:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_walking = not _walking
			_phase_timer = walk_time if _walking else stop_time
			if _use_sprite and not _hit and not dead and anim.animation != "attack":
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
			if ranged and not _air and _atk_range > 0.0 and dist <= _atk_range:
				base_vx = 0.0
			else:
				base_vx = -move_speed * (_eslow_factor if _eslow_timer > 0.0 else 1.0)
	_knockback = move_toward(_knockback, 0.0, 420.0 * delta)
	velocity.x = base_vx + _knockback
	velocity.y = 0.0
	move_and_slide()
	_push_vx = 0.0

	# 공격
	_attack_timer -= delta
	if not stunned and not dead and _attack_timer <= 0.0:
		if ranged:
			if _atk_range > 0.0 and dist <= _atk_range:
				_attack_timer = attack_interval
				_fire_projectile()
				if _use_sprite and _has_attack and not _hit:
					anim.play("attack")
		elif _is_touching_player():
			_attack_timer = attack_interval
			_lunge = 0.16
			if _use_sprite and _has_attack and not _hit:
				anim.play("attack")
			if _kind == "dive":
				_dive = DIVE_DUR     # 참새: 공격 때 급강하(내려갔다 올라옴)
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
	var b := ENEMY_BULLET.instantiate()
	if _kind == "lob":
		b.shape = "stone"          # 투척쥐 2종 = 길냥이 돌멩이와 동일
	elif _id == "bee":
		b.shape = "cone"           # 벌 = 원뿔 독침

	# 박쥐: 머리 높이 수평 음파 — 치즈가 서 있으면 맞고, 앉으면(숙이면) 회피
	if _high:
		var head_y := -180.0
		b.global_position = Vector2(global_position.x - 10.0, Layout.ground_y() + head_y)
		b.hit_y_offset = head_y
		b.dodge_by_crouch = true
		get_parent().add_child(b)
		b.setup(Vector2(-460.0, 0.0), damage, _status, _bcolor, 0.0)   # 수평 직선
		return

	var oy := -AIR_HEIGHT if _air else -90.0
	var origin := global_position + Vector2(-10, oy)
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
		# 참새 급강하: 공격 중엔 sin 곡선으로 바닥까지 내려갔다 올라옴
		var dive_lift := 0.0
		if _dive > 0.0:
			dive_lift = sin((1.0 - _dive / DIVE_DUR) * PI) * AIR_HEIGHT
		var cy := -_body_r - 12.0 - (AIR_HEIGHT if _air else 0.0) + dive_lift
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
			_stun_timer = stun
		Fx.request_shake(7.0 if crit else 3.0)
		if play_sfx:
			Sfx.impact(crit)   # 근접·원거리 통일(punch), 크리=퍼벅
		var _fy := -50.0 - (AIR_HEIGHT if _air else 0.0)
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
	Fx.burst("slime_drip", global_position + Vector2(0, -42.0 - (AIR_HEIGHT if _air else 0.0)), 0.4, 44, 14.0, true, minf(dur, 1.2))

## 스킬 스턴(완전 정지 dur초) — 자장가. 데미지·넉백 없음
func apply_stun(dur: float) -> void:
	if dead:
		return
	_stun_timer = maxf(_stun_timer, dur)
	Fx.burst("dizzy_stars", global_position + Vector2(0, -92.0 - (AIR_HEIGHT if _air else 0.0)), 0.46, 46, 14.0, true, dur)


## 이동/정지 애니(idle 있으면 정지 시 idle, 아니면 walk).
func _play_move_anim() -> void:
	if _has_idle and not _walking:
		if anim.animation != "idle":
			anim.play("idle")
	elif anim.animation != "walk":
		anim.play("walk")


func _on_anim_finished() -> void:
	if dead:
		queue_free()
	elif anim.animation == "hit" or anim.animation == "attack":
		_hit = false
		_play_move_anim()


func _die() -> void:
	dead = true
	GameState.enemy_killed.emit()                                    # 스테이지 이벤트 트리거(첫 처치 등)
	GameState.coins += int(round(_coin * GameState.run_coin_mult))   # 처치 코인(§3.1, 곳간 축복 배율)
	for mid in Enemies.roll_drops(_id):   # 전리품 드랍(§5.2)
		GameState.add_material(mid)
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$Hitbox.set_deferred("monitorable", false)
	queue_redraw()
	var pop := POP.instantiate()
	get_parent().add_child(pop)
	pop.global_position = global_position + Vector2(0, -45 - (AIR_HEIGHT if _air else 0.0))
	Fx.request_shake(7.0)
	Fx.request_hitstop(0.05)
	Fx.burst("poof_explosion", global_position + Vector2(0, -45.0 - (AIR_HEIGHT if _air else 0.0)), 0.6, 47)
	Sfx.play("pop")
	if _use_sprite:
		anim.modulate = Color(1, 1, 1)
		if anim.sprite_frames != null and anim.sprite_frames.has_animation("ghost"):
			anim.play("ghost")               # 옛 mouse_frames(있으면)
		else:
			anim.play("hit")                 # 신규 침입자 프레임엔 ghost 없음 → hit 후 종료 시 free
			get_tree().create_timer(0.5).timeout.connect(queue_free)
	else:
		var t := get_tree().create_timer(0.05)
		t.timeout.connect(queue_free)
