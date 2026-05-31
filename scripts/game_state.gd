extends Node
## 게임 전역 상태 (오토로드 "GameState") — 씬이 바뀌어도 유지.
## 지금은 선택한 직업만. (나중에 보유 직업·동전·진행도 등 확장)

## 선택 직업: "base"(맨몸) / "sheriff"(보안관) / "maid"(메이드) / "jazz"(음악가)
var selected_job: String = "base"

## 직업별 기본 스탯 (시스템밸런스 §4, Lv1 기준)
##  hp=체력 / ranged=원거리공격력 / near=근거리공격력 / atk_spd=공격속도 / move=이동속도배율
const JOB_STATS := {
	"base":    {"hp": 100.0, "ranged": 8.0,  "near": 12.0, "atk_spd": 1.0, "move": 1.0},
	"sheriff": {"hp": 130.0, "ranged": 11.0, "near": 10.0, "atk_spd": 1.1, "move": 1.0},
	"maid":    {"hp": 120.0, "ranged": 6.0,  "near": 16.0, "atk_spd": 1.0, "move": 1.15},
	"jazz":    {"hp": 110.0, "ranged": 14.0, "near": 6.0,  "atk_spd": 1.0, "move": 1.0},
}


## 선택 직업의 SpriteFrames 경로
func job_frames_path() -> String:
	return "res://assets/sprites/cheese/%s/cheese_%s.tres" % [selected_job, selected_job]


## 선택 직업의 스탯
func job_stats() -> Dictionary:
	return JOB_STATS.get(selected_job, JOB_STATS["base"])
