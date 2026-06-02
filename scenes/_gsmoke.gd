extends Node
func _ready() -> void:
	var G = GameState
	G.reset_progress()
	print("reset: owned=", G.owned_grades, " grade=", G.equipped_grade)
	# 1-3 클리어 시뮬 → 보안관 지급
	G.stage_minor = 4; G._check_stage_unlocks()
	print("1-3후: sheriff owns=", G.owns_job("sheriff"), " owned=", G.owned_grades.get("sheriff"))
	# 보안관 장착
	G.selected_job = "sheriff"; G.equipped_grade = G.top_grade("sheriff")
	print("장착 보안관 등급=", G.equipped_grade, " 배율=", G.level_mult(), " 슬롯=", G.skill_slots())
	# 떠오르는(2등급) 제작
	G.coins = 5000
	print("next_grade=", G.next_grade("sheriff"), " cost=", G.craft_grade_cost("sheriff"), " can=", G.can_craft_grade("sheriff"))
	G.craft_grade("sheriff")
	print("제작후: owned=", G.owned_grades.get("sheriff"), " coins=", G.coins, " top=", G.top_grade("sheriff"))
	G.equipped_grade = 3; G.selected_job="sheriff"
	print("3등급 장착: 배율=", G.level_mult(), " 슬롯=", G.skill_slots(), " 라벨=", G.rank_label(0,"sheriff"), " 명칭=", G.job_title("sheriff"))
	# 세이브 왕복
	G.AUTOSAVE = true; G.mode="player"; G.save_game()
	G.owned_grades = {"base":[1]}; G.equipped_grade=1; G.selected_job="base"
	G.load_game()
	print("로드후: owned=", G.owned_grades, " sel=", G.selected_job, " grade=", G.equipped_grade)
	get_tree().quit()
