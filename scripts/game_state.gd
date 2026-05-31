extends Node
## 게임 전역 상태 (오토로드 "GameState") — 씬이 바뀌어도 유지.
## 지금은 선택한 직업만. (나중에 보유 직업·동전·진행도 등 확장)

## 선택 직업: "base"(맨몸) / "sheriff"(보안관) / "maid"(메이드) / "jazz"(음악가)
var selected_job: String = "base"

## 직업별 기본 스탯 + 크리티컬
##  hp=체력 / ranged=원거리 / near=근거리 / atk_spd=공격속도 / move=이동배율
##  crit=크리율 / crit_type=크리효과(strike 강타·knockback 강넉백·stun 스턴) / crit_mult=강타 배수
##  rmode=원거리 발사방식(straight 일자 / lob 포물선던지기)
##  rlimit=일자 사거리(화면폭 대비 비율, 0=끝까지) / misfire=불발 확률(보안관)
const JOB_STATS := {
	"base":    {"hp": 80.0,  "ranged": 6.0,  "near": 8.0,  "atk_spd": 0.9, "move": 1.0,  "crit": 0.05, "crit_type": "strike",    "crit_mult": 1.5, "rmode": "lob",      "rlimit": 0.0, "misfire": 0.0},
	"sheriff": {"hp": 140.0, "ranged": 13.0, "near": 11.0, "atk_spd": 0.8, "move": 1.0,  "crit": 0.15, "crit_type": "strike",    "crit_mult": 2.0, "rmode": "straight", "rlimit": 0.0, "misfire": 0.12},
	"maid":    {"hp": 110.0, "ranged": 5.0,  "near": 18.0, "atk_spd": 1.0, "move": 1.25, "crit": 0.15, "crit_type": "knockback", "crit_mult": 1.0, "rmode": "lob",      "rlimit": 0.0, "misfire": 0.0},
	"jazz":    {"hp": 90.0,  "ranged": 16.0, "near": 4.0,  "atk_spd": 0.7, "move": 0.9,  "crit": 0.12, "crit_type": "stun",      "crit_mult": 1.0, "rmode": "straight", "rlimit": 0.5, "misfire": 0.0},
}


## 선택 직업의 SpriteFrames 경로
func job_frames_path() -> String:
	return "res://assets/sprites/cheese/%s/cheese_%s.tres" % [selected_job, selected_job]


## 선택 직업의 스탯
func job_stats() -> Dictionary:
	return JOB_STATS.get(selected_job, JOB_STATS["base"])
