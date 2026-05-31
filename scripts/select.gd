extends Control
## 시작 직업 선택 화면 (테스트용) — 4직업 중 하나 고르면 게임 시작.
## 원래는 장비/직업 변경으로 바뀌지만, 테스트 편의를 위해 시작 시 선택.

const JOBS := {
	"base": "맨몸",
	"sheriff": "보안관",
	"maid": "메이드",
	"jazz": "음악가",
}
const BUILD := "v4"   # 배포할 때마다 올림 — 폰에서 최신인지 확인용


func _ready() -> void:
	$Build.text = "build " + BUILD
	for job in JOBS:
		var box: Control = $Center/Box/Row.get_node(job)
		var preview: TextureRect = box.get_node("Preview")
		preview.texture = load("res://assets/sprites/cheese/%s/idle/idle_01.png" % job)
		var btn: Button = box.get_node("Btn")
		btn.text = JOBS[job]
		btn.pressed.connect(_pick.bind(job))


func _pick(job: String) -> void:
	GameState.selected_job = job
	get_tree().change_scene_to_file("res://scenes/main.tscn")
