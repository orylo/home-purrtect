extends Node
## 게임 전역 상태 (오토로드 "GameState") — 씬이 바뀌어도 유지.
## 지금은 선택한 직업만. (나중에 보유 직업·동전·진행도 등 확장)

## 빌드 버전 — 시작/선택 화면에 "0.0N ver." 로 표시(배포 때마다 올림)
const BUILD := "0.21"


## 코드로 직접 그리는 텍스트(데미지 숫자·WASD 등)도 Pretendard를 쓰도록 전역 기본 폰트 지정
func _ready() -> void:
	var f := load("res://assets/fonts/DoHyeon-Regular.ttf")
	if f:
		ThemeDB.fallback_font = f

## --- 개발 게이트 ---  출시 빌드 만들 때 false 또는 OS.has_feature("dev")로 교체
const DEV := true
func is_dev() -> bool:
	return DEV

## 진행 자동 저장/이어하기 — 개발 중엔 false(매번 1-1부터 순서대로 테스트). 출시 땐 true.
const AUTOSAVE := false

## --- 이번 판 런 설정 (게임 본체가 이것만 읽어 실행) ---
var mode: String = "player"        # "player" | "dev"
var sandbox: bool = false           # 테스트 스테이지(자동 웨이브 없음 — 디버그로 직접 스폰)
var difficulty: float = 1.0        # 적 스탯 배율 M (시스템밸런스 §3)
var cheats := {"godmode": false, "enemy_oneshot": false, "enemy_count_mult": 1.0}
var coins: int = 0                 # 재화(상점 시스템 때 사용)

## --- 등급(Lv) 배율 (시스템밸런스 §2.2) — hp/원거리/근거리에 곱함 ---
const LV_MULT := [1.0, 1.5, 2.2, 3.2, 4.5]
func level_mult(job: String = "") -> float:
	var j := job if job != "" else selected_job
	return LV_MULT[clampi(int(job_level.get(j, 1)) - 1, 0, 4)]

## --- 레벨업 구매 (상점, 시스템밸런스 §5.2-C) ---
## 다음 Lv 도달 비용: Lv1→2=1,000 / 2→3=2,500 / 3→4=5,000 / 4→5=10,000
const LEVELUP_COST := [1000, 2500, 5000, 10000]   # index = 현재 Lv-1
func levelup_cost(job: String = "") -> int:
	var j := job if job != "" else selected_job
	var lv := int(job_level.get(j, 1))
	if lv >= 5:
		return 0   # 최고 레벨
	return LEVELUP_COST[lv - 1]

func can_levelup(job: String = "") -> bool:
	var j := job if job != "" else selected_job
	var c := levelup_cost(j)
	return c > 0 and coins >= c

func do_levelup(job: String = "") -> bool:
	var j := job if job != "" else selected_job
	if not can_levelup(j):
		return false
	coins -= levelup_cost(j)
	job_level[j] = int(job_level.get(j, 1)) + 1
	if mode != "dev" and AUTOSAVE:
		save_game()
	return true

## --- 소모품 (상점 구매·보유, 시스템밸런스 §5.4) ---
## 전투 중 실제 사용은 다음 조각(소모품 탭·HUD). 지금은 "사서 보유"까지.
const CONSUMABLES := {
	"bandage":     {"name": "낡은 붕대", "price": 40, "desc": "체력 30 회복"},
	"anchovy":     {"name": "말린 멸치", "price": 50, "desc": "8초 공격 +50%"},
	"firecracker": {"name": "폭죽",      "price": 80, "desc": "광역 60 데미지"},
}
var inventory := {"bandage": 0, "anchovy": 0, "firecracker": 0}

func consumable_price(id: String) -> int:
	return int(CONSUMABLES.get(id, {}).get("price", 0))

func can_buy_consumable(id: String) -> bool:
	return CONSUMABLES.has(id) and coins >= consumable_price(id)

func buy_consumable(id: String) -> bool:
	if not can_buy_consumable(id):
		return false
	coins -= consumable_price(id)
	inventory[id] = int(inventory.get(id, 0)) + 1
	if mode != "dev" and AUTOSAVE:
		save_game()
	return true

## 선택 직업: "base"(맨몸) / "sheriff"(보안관) / "maid"(메이드) / "jazz"(음악가)
var selected_job: String = "base"

## --- 스테이지 진행 ---
var stage_major: int = 1
var stage_minor: int = 1

## 해금된 직업(플레이어 모드). 항상 맨몸 포함. 해금 타임라인(§6-A):
##   1-3 클리어(→1-4) = 보안관 / 1-7 클리어(→1-8) = 메이드·음악가.
##   (본 게임에선 1-7 상점 구매지만 상점 전이라 클리어로 해금 — 상점 붙으면 구매로 교체.)
## 개발자 모드는 이 값과 무관(개발자 메뉴에서 4종 자유 선택).
var unlocked_jobs: Array = ["base"]

## 첫 클리어한 스테이지(파밍 재클리어 시 보너스 중복 방지)
var cleared_stages: Array = []


func is_job_unlocked(job: String) -> bool:
	return unlocked_jobs.has(job)


## 스테이지 클리어 보상 — 첫 클리어면 보너스 코인 지급(파밍은 0). 지급액 반환(연출용).
##   첫 클리어 = 20 + 5×스테이지번호 (§5.1) + 보스 보너스(1-10 +100 / 1-20 +200)
func award_stage_clear() -> int:
	if cleared_stages.has(stage_minor):
		return 0
	cleared_stages.append(stage_minor)
	var bonus := 20 + 5 * stage_minor
	if stage_minor == 10:
		bonus += 100
	elif stage_minor == 20:
		bonus += 200
	coins += bonus
	return bonus


## 도달한(현재) 스테이지 기준으로 해금 직업 보강 — idempotent(세이브 로드 후에도 안전)
func _check_stage_unlocks() -> void:
	if stage_minor >= 4 and not unlocked_jobs.has("sheriff"):
		unlocked_jobs.append("sheriff")        # 1-3 클리어 → 보안관
	if stage_minor >= 8:                          # 1-7 클리어 → 메이드·음악가
		if not unlocked_jobs.has("maid"):
			unlocked_jobs.append("maid")
		if not unlocked_jobs.has("jazz"):
			unlocked_jobs.append("jazz")


## "1-1" 같은 표시용 문자열
func stage_label() -> String:
	return "%d-%d" % [stage_major, stage_minor]


## 다음 스테이지로(클리어 시) — 도달 스테이지에 맞춰 직업 해금
func advance_stage() -> void:
	stage_minor += 1
	_check_stage_unlocks()


## 처음부터(필요 시) — 1-1, 맨몸만
func reset_progress() -> void:
	stage_major = 1
	stage_minor = 1
	unlocked_jobs = ["base"]
	cleared_stages = []
	selected_job = "base"
	coins = 0
	job_level = {"base": 1, "sheriff": 1, "maid": 1, "jazz": 1}
	inventory = {"bandage": 0, "anchovy": 0, "firecracker": 0}

## 직업별 기본 스탯 + 크리티컬
##  hp=체력 / ranged=원거리 / near=근거리 / atk_spd=공격속도 / move=이동배율
##  crit=크리율 / crit_type=크리효과(strike 강타·knockback 강넉백·stun 스턴) / crit_mult=강타 배수
##  rmode=원거리 발사방식(straight 일자 / lob 포물선던지기)
##  rlimit=일자 사거리(화면폭 대비 비율, 0=끝까지) / misfire=불발 확률(보안관)
##  rshape=투사체 모양(dot 흰원 / stone 회색돌 / plate 접시 / note 음표)
##  rdelay=공격 시작 후 실제 발사까지 딜레이(초) — 모션 타이밍 맞춤
const JOB_STATS := {
	"base":    {"hp": 80.0,  "ranged": 6.0,  "near": 8.0,  "atk_spd": 0.9, "move": 1.0,  "crit": 0.05, "crit_type": "strike",    "crit_mult": 1.5, "rmode": "lob",      "rlimit": 0.0, "misfire": 0.0,  "rshape": "stone", "rdelay": 0.2},
	"sheriff": {"hp": 140.0, "ranged": 13.0, "near": 11.0, "atk_spd": 0.8, "move": 1.0,  "crit": 0.15, "crit_type": "strike",    "crit_mult": 2.0, "rmode": "straight", "rlimit": 0.0, "misfire": 0.12, "rshape": "dot",   "rdelay": 0.12},
	"maid":    {"hp": 110.0, "ranged": 5.0,  "near": 18.0, "atk_spd": 1.0, "move": 1.25, "crit": 0.15, "crit_type": "knockback", "crit_mult": 1.0, "rmode": "lob",      "rlimit": 0.0, "misfire": 0.0,  "rshape": "plate", "rdelay": 0.2},
	"jazz":    {"hp": 90.0,  "ranged": 16.0, "near": 4.0,  "atk_spd": 0.7, "move": 0.9,  "crit": 0.12, "crit_type": "stun",      "crit_mult": 1.0, "rmode": "straight", "rlimit": 0.5, "misfire": 0.0,  "rshape": "note",  "rdelay": 0.0},
}


# ============================================================
#  직업 명칭 & 등급 표기 시스템
#   · 직업명 = 직업 + Lv 조합으로 결정(직업마다 Lv별 호칭 다름)
#   · 등급 라벨 = Lv만으로 결정(전 직업 공통), 색은 Lv별
#   · 맨몸(길냥이)은 Lv/등급 없음 — 직업명만
# ============================================================

## 직업별 Lv1~5 호칭. 맨몸은 단일("길냥이").
const JOB_TITLES := {
	"base":    ["길냥이"],
	"sheriff": ["견습 보안관", "부보안관", "보안관", "주 보안관", "보안관장"],
	"maid":    ["견습 메이드", "초급 메이드", "중급 메이드", "고급 메이드", "시녀장"],
	"jazz":    ["거리 악사", "연주자", "악장", "명연주자", "마에스트로"],
}

## 등급 라벨(Lv1~5 공통)
const RANK_LABELS := ["이름 없는 등급", "떠오르는 등급", "소문난 등급", "이름난 등급", "전설의 등급"]

## 등급 라벨 색(Lv1 회색 → Lv5 금색). 나중에 조정 가능하게 변수.
var rank_colors := [
	Color(0.45, 0.45, 0.45),  # Lv1 회색
	Color(0.16, 0.50, 0.85),  # Lv2 하늘
	Color(0.18, 0.60, 0.32),  # Lv3 초록
	Color(0.50, 0.30, 0.85),  # Lv4 보라
	Color(0.90, 0.55, 0.00),  # Lv5 금색
]

## 직업별 현재 등급(Lv). 지금은 전부 1(레벨 시스템 붙으면 여기 갱신).
var job_level := {"base": 1, "sheriff": 1, "maid": 1, "jazz": 1}


## 맨몸은 등급 라벨이 없다
func has_rank(job: String) -> bool:
	return job != "base"


## 직업+Lv 호칭 (예: 견습 보안관)
func job_title(job: String) -> String:
	var names: Array = JOB_TITLES.get(job, ["?"])
	var idx: int = clampi(int(job_level.get(job, 1)) - 1, 0, names.size() - 1)
	return names[idx]


## 등급 라벨 텍스트 (맨몸은 "")
func rank_label(job: String) -> String:
	if not has_rank(job):
		return ""
	var idx: int = clampi(int(job_level.get(job, 1)) - 1, 0, RANK_LABELS.size() - 1)
	return RANK_LABELS[idx]


## 등급 라벨 색
func rank_color(job: String) -> Color:
	var idx: int = clampi(int(job_level.get(job, 1)) - 1, 0, rank_colors.size() - 1)
	return rank_colors[idx]


## 선택 직업의 SpriteFrames 경로
func job_frames_path() -> String:
	return "res://assets/sprites/cheese/%s/cheese_%s.tres" % [selected_job, selected_job]


## 선택 직업의 스탯
func job_stats() -> Dictionary:
	return JOB_STATS.get(selected_job, JOB_STATS["base"])


# ============================================================
#  진행 저장 (플레이어 모드 전용) — user://save.json
# ============================================================
const SAVE_PATH := "user://save.json"

func save_game() -> void:
	var data := {
		"stage_major": stage_major, "stage_minor": stage_minor,
		"unlocked_jobs": unlocked_jobs, "coins": coins,
		"cleared_stages": cleared_stages,
		"selected_job": selected_job,   # 마지막 출격 세팅(로드맵 3단계)
		"job_level": job_level,         # 직업별 Lv(상점 레벨업, 로드맵 4단계)
		"inventory": inventory,         # 소모품 보유(상점 구매, 로드맵 4단계)
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_DICTIONARY:
		stage_major = int(data.get("stage_major", 1))
		stage_minor = int(data.get("stage_minor", 1))
		coins = int(data.get("coins", 0))
		cleared_stages = []
		var cs = data.get("cleared_stages", [])
		if typeof(cs) == TYPE_ARRAY:
			for s in cs:
				cleared_stages.append(int(s))
		# 해금 직업 복원(옛 세이브엔 없을 수 있음 → 맨몸만으로 시작 후 스테이지로 보강)
		unlocked_jobs = ["base"]
		var uj = data.get("unlocked_jobs", [])
		if typeof(uj) == TYPE_ARRAY:
			for j in uj:
				var js := String(j)
				if not unlocked_jobs.has(js):
					unlocked_jobs.append(js)
		_check_stage_unlocks()   # 도달 스테이지 기준으로 일관성 보강
		# 마지막 출격 직업 복원(해금 안 된 값이면 맨몸으로)
		var sj := String(data.get("selected_job", "base"))
		selected_job = sj if unlocked_jobs.has(sj) else "base"
		# 직업별 Lv 복원(상점 레벨업)
		var jl = data.get("job_level", {})
		if typeof(jl) == TYPE_DICTIONARY:
			for k in job_level.keys():
				job_level[k] = clampi(int(jl.get(k, 1)), 1, 5)
		# 소모품 보유 복원
		var inv = data.get("inventory", {})
		if typeof(inv) == TYPE_DICTIONARY:
			for k in inventory.keys():
				inventory[k] = maxi(0, int(inv.get(k, 0)))

func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	reset_progress()
	coins = 0
