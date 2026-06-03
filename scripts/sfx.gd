extends Node
## Sfx (오토로드) — 효과음.
##   Sfx.play("click" / "coin" / "hit" / "crit" / "pop" / "jump" / "shoot" / "heal" / "buff")
##   · 실제 음원(assets/sfx/, Kenney CC0)이 있으면 그걸 재생 — click·coin·hit·crit·heal·buff.
##   · 없으면 코드 합성음으로 폴백 — pop·jump·shoot(직업별 피치 변주가 살아서 합성 유지).
##   폴링 플레이어로 동시재생 + 미세 피치 변주.

const RATE := 22050
# 실제 음원 파일(있으면 합성보다 우선). 배열=변주(랜덤 1개 선택).
const FILES := {
	"click": ["res://assets/sfx/click_a.wav", "res://assets/sfx/click_b.wav"],
	"coin":  ["res://assets/sfx/coin.ogg"],
	"hit":   ["res://assets/sfx/hit_a.ogg", "res://assets/sfx/hit_b.ogg"],
	"crit":  ["res://assets/sfx/crit.ogg"],
	"heal":  ["res://assets/sfx/heal.ogg"],
	"buff":  ["res://assets/sfx/buff.ogg"],
}
var _players: Array = []
var _idx := 0
var _cache := {}        # key(name 또는 res경로) -> AudioStream (1회 로드/생성 후 재사용)


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func play(name: String, pitch: float = 1.0, vol_db: float = -4.0) -> void:
	var stream := _stream_for(name)
	if stream == null:
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch * randf_range(0.96, 1.05)   # 미세 피치 변주(반복 단조로움 방지)
	p.volume_db = vol_db
	p.play()


## 실제 음원 파일이 있으면 그걸(변주 랜덤), 없으면 코드 합성음을 돌려준다.
func _stream_for(name: String) -> AudioStream:
	if FILES.has(name):
		var paths: Array = FILES[name]
		var path: String = paths[randi() % paths.size()]
		if not _cache.has(path):
			_cache[path] = load(path)   # 임포트된 AudioStream(ogg/wav)
		if _cache[path] != null:
			return _cache[path]
	# 폴백: 코드 합성
	if not _cache.has(name):
		_cache[name] = _gen(name)
	return _cache[name]


# ── 합성 헬퍼 ───────────────────────────────────────────
func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _noise(dur: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (randf() * 2.0 - 1.0) * exp(-t * decay) * amp
	return s

## f0→f1 주파수 스윕(사인). square=네모파, noise_amt=노이즈 섞기.
func _sweep(f0: float, f1: float, dur: float, decay: float, square := false, noise_amt := 0.0) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f: float = lerp(f0, f1, t)
		phase += TAU * f / RATE
		var v := sin(phase)
		if square:
			v = 1.0 if v >= 0.0 else -1.0
		var env := exp(-(float(i) / RATE) * decay)
		s[i] = (v * (1.0 - noise_amt) + (randf() * 2.0 - 1.0) * noise_amt) * env * 0.6
	return s

## 음 여러 개를 이어 붙임(코인·회복 아르페지오). square 옵션.
func _arp(freqs: Array, dur_each: float, square := false, decay := 10.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		var n := int(RATE * dur_each)
		var phase := 0.0
		for i in n:
			phase += TAU * float(f) / RATE
			var v := sin(phase)
			if square:
				v = 1.0 if v >= 0.0 else -1.0
			out.append(v * exp(-(float(i) / RATE) * decay) * 0.55)
	return out

func _add(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var va := a[i] if i < a.size() else 0.0
		var vb := b[i] if i < b.size() else 0.0
		s[i] = clampf(va + vb, -1.0, 1.0)
	return s


func _gen(name: String) -> AudioStreamWAV:
	match name:
		"click": return _wav(_noise(0.045, 80.0, 0.5))                          # UI 틱
		"pop":   return _wav(_add(_noise(0.12, 28.0, 0.7), _sweep(420, 120, 0.12, 22.0)))  # 처치 펑
		"hit":   return _wav(_add(_noise(0.06, 55.0, 0.55), _sweep(180, 70, 0.07, 40.0)))  # 타격 퍽
		"crit":  return _wav(_add(_add(_noise(0.08, 40.0, 0.6), _sweep(220, 90, 0.09, 30.0)), _sweep(700, 1300, 0.09, 16.0)))  # 크리(밝게)
		"jump":  return _wav(_sweep(360, 760, 0.16, 9.0))                       # 점프 삑↑
		"shoot": return _wav(_sweep(950, 320, 0.09, 16.0, false, 0.35))         # 발사 퓽↓
		"heal":  return _wav(_arp([660, 880, 1175], 0.06))                      # 회복 아르페지오↑
		"buff":  return _wav(_sweep(440, 980, 0.22, 6.0))                       # 버프 우↑
		"coin":  return _wav(_arp([988, 1319], 0.05, true, 12.0))               # 코인 띠링(네모파)
	return _wav(_noise(0.04, 80.0, 0.4))
