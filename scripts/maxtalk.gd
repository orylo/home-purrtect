extends "res://scripts/npc_talk.gd"
## 맥스 - 상점 주인 NPC 인사 화면. [상점을 연다] → shop.tscn.

const ORANGE := Color(1.0, 0.6, 0.15)


func _start() -> void:
	portrait(Color(0.55, 0.42, 0.32), "happy")
	say("맥스", ORANGE, "어서 오게, 우리 동네 영웅!\n쓸 만한 물건 많이 들여놨지. 둘러보겠나?")
	choices([
		["상점을 연다", func(): go("res://scenes/shop.tscn")],
		["나간다", func(): go("res://scenes/home.tscn")],
	])
