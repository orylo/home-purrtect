extends Node
## 게임 전역 상태 (오토로드 "GameState") — 씬이 바뀌어도 유지.
## 지금은 선택한 직업만. (나중에 보유 직업·동전·진행도 등 확장)

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


## 선택 직업의 SpriteFrames 경로
func job_frames_path() -> String:
	return "res://assets/sprites/cheese/%s/cheese_%s.tres" % [selected_job, selected_job]


## 선택 직업의 스탯
func job_stats() -> Dictionary:
	return JOB_STATS.get(selected_job, JOB_STATS["base"])
