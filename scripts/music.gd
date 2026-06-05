extends Node
## Music (오토로드) ─ 화면별 배경음악(BGM). 자동로드라 씬이 바뀌어도 끊기지 않고,
## 현재 씬에 맞는 곡으로 자연스럽게 전환된다.
##   · 전투(main.tscn)        = battle.wav (술집 피아노 "Drunken Party")
##   · 그 외(시작·홈·상점 등) = menu.wav   ("Going Bananas")
##   · 켜짐/꺼짐은 GameState.bgm_enabled에 저장(홈 [설정]에서 토글).
##   · 볼륨은 효과음에 안 묻히게 낮게(-14dB).

const VOL_DB := -14.0
const TRACKS := {
	"menu":   preload("res://assets/music/menu.wav"),
	"battle": preload("res://assets/music/battle.wav"),
	"boss":   preload("res://assets/music/boss.wav"),   # 보스전 ─ 긴박하게
}
## 씬 파일 → 트랙. 목록에 없는 씬은 모두 "menu". "none"=무음(그 씬이 직접 음악 재생).
const SCENE_TRACK := {
	"res://scenes/main.tscn": "battle",
	"res://scenes/prologue.tscn": "none",   # 프롤로그는 자체 음악(슬픔→온기) 재생
}
## 보스 스테이지 ─ 전투씬이어도 boss 트랙. 키="막-스테이지".
const BOSS_STAGES := {
	"1-10": true,
	"1-20": true,
}

var _player: AudioStreamPlayer
var _cur := ""           # 현재 재생 중인 트랙 키
var _override := ""      # 이벤트 전용 강제 트랙(""=없음). set_override로 지정, clear_override로 해제.


func _ready() -> void:
	# 인게임 이벤트·대사로 트리가 일시정지돼도 음악 추적이 멈추지 않게(전환 누락·끊김 방지).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = VOL_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	# 각 트랙을 전체 구간 이음새 없이 반복하도록 루프 설정
	for k in TRACKS.keys():
		var s: AudioStreamWAV = TRACKS[k]
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(round(s.get_length() * s.mix_rate))


## 매 프레임 현재 씬을 보고, 맞는 트랙이 아니면 전환(켜져 있을 때만 실제 재생).
func _process(_delta: float) -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	# 전투 씬을 벗어나면 이벤트 오버라이드 자동 해제(메뉴·홈에 보스음악 새는 것 방지).
	if _override != "" and sc.scene_file_path != "res://scenes/main.tscn":
		_override = ""
	var key: String = SCENE_TRACK.get(sc.scene_file_path, "menu")
	if key == "battle" and BOSS_STAGES.has("%d-%d" % [GameState.stage_major, GameState.stage_minor]):
		key = "boss"                         # 보스 스테이지면 보스 BGM
	if _override != "":
		key = _override                      # 이벤트 전용 강제 트랙(set_override)
	if key != _cur:
		_cur = key
		if key == "none":
			_player.stop()
		elif GameState.bgm_enabled:
			_play_cur()


func _play_cur() -> void:
	if _cur == "" or not TRACKS.has(_cur):
		return   # "none" 등은 재생 안 함(그 씬이 직접 음악 처리)
	# 같은 곡이 이미 재생 중이면 재시작하지 않음(끊김 방지).
	if _player.stream == TRACKS[_cur] and _player.playing:
		return
	_player.stream = TRACKS[_cur]
	_player.play()


# ── 이벤트 전용 BGM 오버라이드 ────────────────────────────────
## 특정 이벤트(예: 보스 첫 등장)에서 일시적으로 다른 트랙을 강제 재생.
##   사용: Music.set_override("boss")  …이벤트…  Music.clear_override()
##   "첫 등장시에만" 같은 1회성은 호출부에서 플래그(예: GameState.cleared_stages 유무)로 가드.
##   key는 TRACKS의 키("menu"/"battle"/"boss"). 잘못된 키면 무시.
func set_override(key: String) -> void:
	if key != "" and not TRACKS.has(key):
		return
	_override = key
	# 즉시 반영(다음 _process에서도 잡지만, 끊김 없이 바로 전환)
	if GameState.bgm_enabled and key != "" and key != _cur:
		_cur = key
		_play_cur()


## 이벤트 BGM 해제 → 다음 _process에서 씬 기준 트랙으로 자연 복귀.
func clear_override() -> void:
	_override = ""


## 켜기/끄기. 저장까지 한다.
func set_enabled(on: bool) -> void:
	GameState.bgm_enabled = on
	GameState.save_game()
	if on:
		_play_cur()
	else:
		_player.stop()


## 토글 후 현재 상태(켜짐=true) 반환.
func toggle() -> bool:
	set_enabled(not GameState.bgm_enabled)
	return GameState.bgm_enabled
