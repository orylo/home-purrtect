extends Node
## 연출 공용 모듈 (오토로드 "Fx") ─ 화면 흔들림 + 히트스톱
## 다른 스크립트가 request_shake / request_hitstop를 호출하면 발동.

var shake: float = 0.0          # 현재 흔들림 세기(px). game.gd가 읽어 화면에 적용.
var _hitstop_token: int = 0


## 화면 흔들림 요청(누적되지 않고 더 큰 값으로 갱신)
func request_shake(amount: float) -> void:
	shake = maxf(shake, amount)


## 히트스톱 ─ 아주 잠깐 시간을 멈췄다 복구(타격의 묵직함)
func request_hitstop(duration: float) -> void:
	_hitstop_token += 1
	var my := _hitstop_token
	Engine.time_scale = 0.05
	# ignore_time_scale=true 라 멈춘 동안에도 실제 시간으로 타이머가 흐름
	await get_tree().create_timer(duration, true, false, true).timeout
	if my == _hitstop_token:
		Engine.time_scale = 1.0


# ── 이펙트 스프라이트 (assets/fx/<name>/0~8.png, 9프레임) ──────────
var _sf_cache: Dictionary = {}   # "name|loop" → SpriteFrames

func _frames(anim: String, loop: bool) -> SpriteFrames:
	var key := anim + ("|1" if loop else "|0")
	if _sf_cache.has(key):
		return _sf_cache[key]
	var sf := SpriteFrames.new()
	for i in 9:
		var tex: Texture2D = load("res://assets/fx/%s/%d.png" % [anim, i])
		if tex:
			sf.add_frame("default", tex)
	sf.set_animation_loop("default", loop)
	sf.set_animation_speed("default", 18.0)
	_sf_cache[key] = sf
	return sf

## 월드 좌표 pos에 9프레임 이펙트를 1회(또는 loop) 재생하고 끝나면 자동 제거.
##  scale: 342px 원본 기준 배율 / z: z_index / fps / loop+life: 루프 시 life초 후 제거.
func burst(anim: String, pos: Vector2, scale: float = 1.0, z: int = 40,
		fps: float = 18.0, loop: bool = false, life: float = 0.0,
		modulate: Color = Color.WHITE) -> void:
	var scn := get_tree().current_scene
	if scn == null:
		return
	var s := AnimatedSprite2D.new()
	# 클리어(트리 일시정지) 중에도 타격/처치 이펙트가 끝까지 재생되게.
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	s.sprite_frames = _frames(anim, loop)
	s.global_position = pos
	s.scale = Vector2(scale, scale)
	s.z_index = z
	s.modulate = modulate
	s.speed_scale = fps / 18.0
	scn.add_child(s)
	s.play("default")
	if loop:
		if life > 0.0:
			get_tree().create_timer(life).timeout.connect(s.queue_free)
	else:
		s.animation_finished.connect(s.queue_free)
