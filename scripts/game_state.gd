extends Node
## 게임 전역 상태 (오토로드 "GameState") — 씬이 바뀌어도 유지.
## 지금은 선택한 직업만. (나중에 보유 직업·동전·진행도 등 확장)

## 빌드 버전 — 시작/선택 화면에 "0.0N ver." 로 표시(배포 때마다 올림)
const BUILD := "0.14"


## 코드로 직접 그리는 텍스트(데미지 숫자·WASD 등)도 Pretendard를 쓰도록 전역 기본 폰트 지정
func _ready() -> void:
	var f := load("res://assets/fonts/DoHyeon-Regular.ttf")
	if f:
		ThemeDB.fallback_font = f

## 선택 직업: "base"(맨몸) / "sheriff"(보안관) / "maid"(메이드) / "jazz"(음악가)
var selected_job: String = "base"

## --- 스테이지 진행 ---
## 1막 = 1-1, 1-2, ... / 첫 판(1-1)은 맨몸만, 클리어하면 1-2부터 직업 해금.
var stage_major: int = 1
var stage_minor: int = 1
var jobs_unlocked: bool = false   # false = 맨몸만(1-1), true = 4직업 선택 가능(1-2~)


## "1-1" 같은 표시용 문자열
func stage_label() -> String:
	return "%d-%d" % [stage_major, stage_minor]


## 다음 스테이지로(클리어 시) — 직업 해금
func advance_stage() -> void:
	stage_minor += 1
	jobs_unlocked = true


## 처음부터(필요 시) — 1-1, 맨몸만
func reset_progress() -> void:
	stage_major = 1
	stage_minor = 1
	jobs_unlocked = false
	selected_job = "base"

## 직업별 기본 스탯 + 크리티컬
##  hp=체력 / ranged=원거리 / near=근거리 / atk_spd=공격속도 / move=이동배율
##  crit=크리율 / crit_type=크리효과(strike 강타·knockback 강넉백·stun 스턴) / crit_mult=강타 배수
##  rmode=원거리 발사방식(straight 일자 / lob 포물선던지기)
##  rlimit=일자 사거리(화면폭 대비 비율, 0=끝까지) / misfire=불발 확률(보안관)
##  rshape=투사체 모양(dot 흰원 / stone 회색돌 / plate 접시 / note 음표)
##  rdelay=공격 시작 후 실제 발사까지 딜레이(초) — 모션 타이밍 맞춤
const JOB_STATS := {
	"base":    {"hp": 80.0,  "ranged": 6.0,  "near": 8.0,  "atk_spd": 0.9, "move": 1.0,  "crit": 0.05, "crit_type": "strike",    "crit_mult": 1.5, "rmode": "lob",      "rlimit": 0.0, "misfire": 0.0,  "rshape": "stone", "rdelay": 0.5},
	"sheriff": {"hp": 140.0, "ranged": 13.0, "near": 11.0, "atk_spd": 0.8, "move": 1.0,  "crit": 0.15, "crit_type": "strike",    "crit_mult": 2.0, "rmode": "straight", "rlimit": 0.0, "misfire": 0.12, "rshape": "dot",   "rdelay": 0.3},
	"maid":    {"hp": 110.0, "ranged": 5.0,  "near": 18.0, "atk_spd": 1.0, "move": 1.25, "crit": 0.15, "crit_type": "knockback", "crit_mult": 1.0, "rmode": "lob",      "rlimit": 0.0, "misfire": 0.0,  "rshape": "plate", "rdelay": 0.5},
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
