extends Node
## 게임 전역 상태 (오토로드 "GameState") — 씬이 바뀌어도 유지.
## 지금은 선택한 직업만. (나중에 보유 직업·동전·진행도 등 확장)

## 선택 직업: "base"(맨몸) / "sheriff"(보안관) / "maid"(메이드) / "jazz"(음악가)
var selected_job: String = "base"


## 선택 직업의 SpriteFrames 경로
func job_frames_path() -> String:
	return "res://assets/sprites/cheese/%s/cheese_%s.tres" % [selected_job, selected_job]
