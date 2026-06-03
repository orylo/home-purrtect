extends Node
## Music (오토로드) — 배경음악(BGM). 자동로드라 씬이 바뀌어도 끊김 없이 계속 흐른다.
##   · 짧은 카툰 루프(assets/music/bgm.wav)를 이음새 없이 반복.
##   · 켜짐/꺼짐은 GameState.bgm_enabled에 저장(홈 [설정]에서 토글).
##   · 볼륨은 효과음에 안 묻히게 낮게(-14dB).

const BGM := preload("res://assets/music/bgm.wav")
const VOL_DB := -14.0
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = VOL_DB
	# 전체 구간 이음새 없이 반복 — 루프 끝점은 (길이×샘플레이트)로 계산(압축 포맷이어도 정확)
	var s: AudioStreamWAV = BGM
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(round(s.get_length() * s.mix_rate))
	_player.stream = s
	add_child(_player)
	if GameState.bgm_enabled:
		_player.play()


## 켜기/끄기. 저장까지 한다.
func set_enabled(on: bool) -> void:
	GameState.bgm_enabled = on
	GameState.save_game()
	if on:
		if not _player.playing:
			_player.play()
	else:
		_player.stop()


## 토글 후 현재 상태(켜짐=true) 반환.
func toggle() -> bool:
	set_enabled(not GameState.bgm_enabled)
	return GameState.bgm_enabled
