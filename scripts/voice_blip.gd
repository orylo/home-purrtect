extends Node
## VoiceBlip (오토로드) — NPC "재잘거림" 보이스(절차적 합성). 동물의숲/Undertale식.
##   NPC 대사가 한 글자씩 타이핑될 때 짧은 블립음을 쏴 "지껄이는" 분위기를 준다.
##   실제 단어는 안 들리는 게 의도(분위기용). 치즈는 무대사라 미적용.
##   외부 에셋/라이브러리 0개: AudioStreamWAV를 런타임 합성, 글자마다 pitch_scale로 변조.
##   샘플 .ogg 스왑 훅: 프로필 sample_path를 채우면 합성 대신 그 음절을 pitch 변조 재생(미래 업그레이드).

const RATE := 22050
const REF_FREQ := 200.0        # 합성 기준 주파수(실제 음정은 pitch_scale로 변조)
const BLIP_MS := 75            # 블립 길이(60~90ms) — pitch_scale로 더 짧아짐
const VOL_DB := -15.0          # 분위기용, 작게(빠른 연타라 너무 크면 시끄러움)
const ATK_MS := 5.0            # 어택(톡 끊김)
const DECAY := 40.0            # 디케이 계수(클수록 빨리 사라짐)
const POOL := 6               # 동시 블립 풀(빠른 연타 대비)

## 캐릭터별 피치 프로필 — 새 NPC는 여기 한 줄 추가로 확장. 전부 시작값·튜닝 대상.
##   base_freq Hz(낮을수록 굵음: 맥스<펑거스<펄) / jitter(클수록 지껄임) / waveform(음색)
##   blip_every(N글자마다 1회) / char_ms(타이핑 속도, 작을수록 빠름) / sample_path(있으면 .ogg 변조)
## sample_path 채워짐 = 녹음 음절(.wav) pitch_scale 변조 재생(합성 대신). 펑거스=시스템 알림 음색도 겸함.
const VOICE_PROFILES := {
	"fungus": {"base_freq": 220.0, "jitter": 0.15, "waveform": "square",   "blip_every": 1, "char_ms": 22.0, "sample_path": "res://assets/audio/voice/blip_fungus.wav"},  # 거들먹·빠름·종알종알
	"pearl":  {"base_freq": 330.0, "jitter": 0.05, "waveform": "sine",     "blip_every": 2, "char_ms": 45.0, "sample_path": "res://assets/audio/voice/blip_pearl.wav"},  # 또박또박·우아·느림
	"max":    {"base_freq": 180.0, "jitter": 0.10, "waveform": "triangle", "blip_every": 2, "char_ms": 35.0, "sample_path": "res://assets/audio/voice/blip_max.wav"},  # 능글·낮음·느긋
}

## 무음 처리할 글자(공백·개행·일부 문장부호 — 글자에만 블립).
const SILENT := [" ", "\n", "\t", " ", "「", "」", "(", ")", "·", "—", "-", "ㅡ", "\"", "'"]

var _players: Array = []
var _pool_i := 0
var _wave_cache := {}          # waveform → AudioStreamWAV(REF_FREQ 1개)
var _sample_cache := {}        # sample_path → AudioStream
var _blip_count := {}          # profile별 blip_every 카운터(연속 호출 시 N글자마다)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 인게임 이벤트(트리 일시정지) 중에도 재생
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = VOL_DB
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)


## 타이핑 속도(글자 간격, 초). npc 대화 루프가 프로필 속도를 쓰게.
func char_sec(profile_id: String) -> float:
	if VOICE_PROFILES.has(profile_id):
		return float(VOICE_PROFILES[profile_id].get("char_ms", 30.0)) / 1000.0
	return 0.03


## 글자 1개 타이핑 시 호출. 미등록 화자·꺼짐·무음 글자면 조용히 무시(안전).
func blip(profile_id: String, ch: String, char_index: int, total: int) -> void:
	if not VOICE_PROFILES.has(profile_id):
		return
	if not GameState.voice_enabled:
		return
	if ch == "" or SILENT.has(ch):
		return
	var prof: Dictionary = VOICE_PROFILES[profile_id]
	# blip_every: N글자마다 1회(공백 무음은 위에서 이미 제외 → 실제 발화 글자 기준 카운트)
	var every: int = int(prof.get("blip_every", 1))
	if every > 1:
		var c: int = int(_blip_count.get(profile_id, 0)) + 1
		_blip_count[profile_id] = c
		if (c % every) != 0:
			return

	# 주파수 = base × (1±jitter) × 진행도 완만변동 × 문장부호 억양
	var base: float = float(prof.get("base_freq", 220.0))
	var jit: float = float(prof.get("jitter", 0.1))
	var freq: float = base * (1.0 + randf_range(-jit, jit))
	if total > 1:
		freq *= 1.0 + 0.06 * sin(float(char_index) / float(total) * PI)   # 문장 진행 완만 변동
	if ch == "?":
		freq *= 1.18                       # 끝 올림(의문)
	elif ch == "…" or ch == "." or ch == ",":
		freq *= 0.85                       # 내림(흐림)

	var p: AudioStreamPlayer = _next_player()
	var sample_path: String = String(prof.get("sample_path", ""))
	if sample_path != "":
		# ── 샘플 .ogg 스왑 훅: base_freq 대신 pitch_scale로 음절 변조 ──
		p.stream = _load_sample(sample_path)
		p.pitch_scale = clampf(freq / base, 0.5, 2.0)
	else:
		# ── 기본: 절차적 합성음(파형 1개 + pitch_scale 변조) ──
		p.stream = _tone(String(prof.get("waveform", "sine")))
		p.pitch_scale = clampf(freq / REF_FREQ, 0.4, 3.0)
	p.play()


## 시스템 알림(즉시표시·非타이핑)용 — 펑거스 음색 단발 블립 1회(과하지 않게).
##   타이핑되는 시스템 알림은 blip("fungus", …)을 글자마다 쓸 것(별도 system 프로필 없음 = 펑거스 그대로).
func notify() -> void:
	blip("fungus", "A", 0, 1)


## 화자가 바뀌거나 대사 시작 시 호출(blip_every 카운터 리셋). 선택.
func reset(profile_id: String = "") -> void:
	if profile_id == "":
		_blip_count.clear()
	else:
		_blip_count[profile_id] = 0


func _next_player() -> AudioStreamPlayer:
	_pool_i = (_pool_i + 1) % _players.size()
	return _players[_pool_i]


func _load_sample(path: String) -> AudioStream:
	if _sample_cache.has(path):
		return _sample_cache[path]
	var st = load(path)
	_sample_cache[path] = st
	return st


## 파형별 짧은 톤(REF_FREQ) 1회 합성·캐시 — 빠른 어택 + 빠른 디케이로 "톡" 끊김.
func _tone(waveform: String) -> AudioStreamWAV:
	if _wave_cache.has(waveform):
		return _wave_cache[waveform]
	var n := int(RATE * BLIP_MS / 1000.0)
	var atk := maxf(RATE * ATK_MS / 1000.0, 1.0)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var ph := fmod(REF_FREQ * t, 1.0)
		var w := 0.0
		match waveform:
			"square":   w = 1.0 if ph < 0.5 else -1.0
			"triangle": w = 4.0 * absf(ph - 0.5) - 1.0
			_:          w = sin(ph * TAU)
		var env := minf(float(i) / atk, 1.0) * exp(-t * DECAY)
		s[i] = w * env * 0.5
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	_wave_cache[waveform] = wav
	return wav
