extends Control
## 시작 직업 선택 화면 (테스트용) — 4직업 중 하나 고르면 게임 시작.
## 원래는 장비/직업 변경으로 바뀌지만, 테스트 편의를 위해 시작 시 선택.

const JOBS := {
	"base": "맨몸",
	"sheriff": "보안관",
	"maid": "메이드",
	"jazz": "음악가",
}
const BUILD := "0.07"   # 배포할 때마다 올림 — 폰에서 최신인지 확인용 (0.0N ver.)


func _ready() -> void:
	$Build.text = BUILD + " ver."
	# 스테이지 표시 + 해금 안내
	var title: Label = $Center/Box/Title
	if GameState.jobs_unlocked:
		title.text = "스테이지 %s — 직업 선택" % GameState.stage_label()
	else:
		title.text = "스테이지 %s — 맨몸 치즈로 시작!\n(클리어하면 직업 해금)" % GameState.stage_label()

	for job in JOBS:
		var box: Control = $Center/Box/Row.get_node(job)
		var preview: TextureRect = box.get_node("Preview")
		preview.texture = load("res://assets/sprites/cheese/%s/idle/idle_01.png" % job)
		var btn: Button = box.get_node("Btn")
		btn.text = JOBS[job]
		# 1-1은 맨몸만, 1-2부터 전 직업 해금. 잠긴 직업은 반투명 + 비활성.
		var unlocked: bool = (job == "base") or GameState.jobs_unlocked
		btn.disabled = not unlocked
		box.modulate = Color(1, 1, 1, 1.0) if unlocked else Color(1, 1, 1, 0.35)
		if not unlocked:
			btn.text = JOBS[job] + " (잠김)"
		btn.pressed.connect(_pick.bind(job))


func _pick(job: String) -> void:
	GameState.selected_job = job
	get_tree().change_scene_to_file("res://scenes/main.tscn")
