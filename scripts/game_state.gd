extends Node
## 게임 전역 상태 (오토로드 "GameState") — 씬이 바뀌어도 유지.
## 지금은 선택한 직업만. (나중에 보유 직업·동전·진행도 등 확장)

signal enemy_killed   # 적 처치 시(스테이지 이벤트 트리거용). enemy_mouse._die에서 emit.

## 빌드 버전 — 시작/선택 화면에 "X.Y.Z ver." 로 표시. 의미체계(CLAUDE.md "버전 체계" 참조):
##   X(메이저): 출시·대폭 변경급 / Y(마이너): 장기 큰 이벤트·막 완성 단위(0.1.0=1막 완전 완성)
##   Z(패치): 자잘한 모든 업데이트마다 +1, 99에서 안 넘어가고 100으로 계속(0.0.99 → 0.0.100).
##   1.0.0 = 3막까지 완성 첫 정식 출시.
const BUILD := "0.0.78"


## 코드로 직접 그리는 텍스트(데미지 숫자·WASD 등)도 Pretendard를 쓰도록 전역 기본 폰트 지정
func _ready() -> void:
	var f := load("res://assets/fonts/Pretendard-Regular.ttf")
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
var bgm_enabled: bool = true       # 배경음악 켜짐(홈 [설정] 토글, Music 오토로드가 읽음)
var prologue_seen: bool = false    # 프롤로그 컷씬 봤는지(첫 실행 자동재생 게이트)
var coachmark_seen: Array = []     # 홈 코치마크 본 항목 id 목록(1회성, 예: "prep"/"pearl"/"max")

## --- 등급 배율 (시스템밸런스 §2.2) — hp/원거리/근거리에 곱함 ---
## ★합성 승급 모델(2026-06-04): 다음 등급 = 직전 등급 장비 + 재료(+코인). 합성 시 직전 등급 소모(등급당 0/1개).
##   배율은 "장착된 등급"(equipped_grade) 기준. (자산관리 §2 / 시스템밸런스 §2.2)
const LV_MULT := [1.0, 1.5, 2.2, 3.2, 4.5]
func level_mult() -> float:
	return LV_MULT[clampi(equipped_grade - 1, 0, 4)]

## --- 등급 합성 승급 (시스템밸런스 §5.2-C/§2.2) ---
## 코인 비용: 2등급 1,000 / 3 2,500 / 4 5,000 / 5 10,000 (index = 만들 등급 - 2)
const GRADE_COST := [1000, 2500, 5000, 10000]
## 2등급 승급 재료(자산관리 §2.5 / 시스템밸런스 §5.2-B). 3~5등급 재료는 2막 TBD(현재 코인만).
const GRADE_CRAFT := {
	"sheriff": {2: {"fur_black": 10, "button": 3, "safety_pin": 2}},
	"maid":    {2: {"fur_black": 10, "sack": 3, "thread_spool": 2}},
	"jazz":    {2: {"fur_black": 10, "wheel": 3, "nail": 2}},
}

## job이 보유한 최고 등급(없으면 0)
func top_grade(job: String) -> int:
	var a: Array = owned_grades.get(job, [])
	return (a as Array).max() if a.size() > 0 else 0

## 화면 표시용 등급(장착직업=장착등급 / 그 외=보유 최고, 없으면 1)
func display_grade(job: String) -> int:
	if job == selected_job:
		return equipped_grade
	var g := top_grade(job)
	return g if g > 0 else 1

func owns_job(job: String) -> bool:
	return (owned_grades.get(job, []) as Array).size() > 0

## 다음 제작 가능 등급(보유 최고+1, 5 초과/미보유면 0)
func next_grade(job: String) -> int:
	var g := top_grade(job)
	if g <= 0 or g >= 5:
		return 0
	return g + 1

func craft_grade_cost(job: String) -> int:
	var ng := next_grade(job)
	return GRADE_COST[ng - 2] if ng >= 2 else 0

## 다음 등급 승급에 필요한 재료(없으면 {}) — 2등급만 정의, 3~5는 코인만.
func grade_mats(job: String) -> Dictionary:
	var ng := next_grade(job)
	return GRADE_CRAFT.get(job, {}).get(ng, {})

func can_craft_grade(job: String) -> bool:
	var ng := next_grade(job)
	if ng < 2 or coins < craft_grade_cost(job):
		return false
	var mats := grade_mats(job)
	for mid in mats:
		if mat_count(mid) < int(mats[mid]):
			return false
	return true

## 합성 승급: 직전 등급 장비 + 재료 + 코인 → 다음 등급. 직전 등급은 소모(0/1개).
func craft_grade(job: String) -> bool:
	if not can_craft_grade(job):
		return false
	var ng := next_grade(job)
	coins -= craft_grade_cost(job)
	var mats := grade_mats(job)
	for mid in mats:
		materials[mid] = mat_count(mid) - int(mats[mid])
	_remove_grade(job, ng - 1)              # 직전 등급 소모
	_add_grade(job, ng)
	if job == selected_job and equipped_grade == ng - 1:
		equipped_grade = ng                 # 소모된 등급을 장착 중이었으면 새 등급 장착
	if mode != "dev" and AUTOSAVE:
		save_game()
	return true

## 보유 등급 세트에 등급 추가(중복 방지·정렬)
func _add_grade(job: String, g: int) -> void:
	var a: Array = owned_grades.get(job, [])
	if g >= 1 and not a.has(g):
		a.append(g)
		a.sort()
	owned_grades[job] = a

## 보유 등급 세트에서 등급 제거(합성 소모)
func _remove_grade(job: String, g: int) -> void:
	var a: Array = owned_grades.get(job, [])
	a.erase(g)
	owned_grades[job] = a

## [개발자] 직업+등급 즉시 장착(1~grade 전부 보유 처리)
func dev_set_job(job: String, grade: int) -> void:
	if not unlocked_jobs.has(job):
		unlocked_jobs.append(job)
	for g in range(1, grade + 1):
		_add_grade(job, g)
	selected_job = job
	equipped_grade = clampi(grade, 1, 5)

## --- 소모품 (상점 구매·보유, 시스템밸런스 §5.4) ---
## 전투 중 실제 사용은 다음 조각(소모품 탭·HUD). 지금은 "사서 보유"까지.
## type: "food"(소모품 도감) / "toy"(장난감 도감) — 전투에선 동일 슬롯 일회용. 도감 분류용.
## ※ 전투 중 실제 사용·휴대 최대 5개·쥐덫 설치 메커니즘은 [구현 대기](현재 구매·보유까지).
const CONSUMABLES := {
	"bandage":     {"name": "낡은 붕대", "price": 40,  "type": "food", "desc": "체력 30 회복"},
	"milk":        {"name": "우유",      "price": 75,  "type": "food", "desc": "체력 70 회복"},
	"anchovy":     {"name": "말린 멸치", "price": 50,  "type": "food", "desc": "8초 공격 +50%"},
	"firecracker": {"name": "폭죽",      "price": 80,  "type": "toy",  "desc": "광역 60 데미지"},
	"bomb":        {"name": "폭탄",      "price": 150, "type": "toy",  "desc": "광역 120 데미지"},
	"pepper":      {"name": "후추통",    "price": 70,  "type": "toy",  "desc": "5초 광역 둔화(피해 없음)"},
	"mousetrap":   {"name": "쥐덫",      "price": 90,  "type": "toy",  "desc": "설치 — 밟은 적 3초 묶음"},
}
var inventory := {"bandage": 0, "milk": 0, "anchovy": 0, "firecracker": 0, "bomb": 0, "pepper": 0, "mousetrap": 0}
## 전투 준비 소모품 슬롯(종류만 저장, 양은 inventory 따라감) — 로드맵 4단계
var item_slots := ["", "", ""]

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

## --- 전리품 인벤토리 (드랍·매입·제작, 시스템밸런스 §5.2) ---
## sell=맥스 매입가(§5.2-C). 표시 순서대로 MAT_ORDER.
const MATERIALS := {
	# 부위/장비(침입자 드랍)
	"fur_gray":        {"name": "회색쥐 털",   "sell": 2},
	"fur_black":       {"name": "검은쥐 털",   "sell": 4},
	"wheel":           {"name": "롤러 바퀴",   "sell": 3},
	"sack":            {"name": "포대 조각",   "sell": 3},
	"bat_wing":        {"name": "박쥐 날개",   "sell": 3},
	"sparrow_feather": {"name": "참새 깃털",   "sell": 3},
	"honey_drop":      {"name": "벌꿀",        "sell": 4},
	"spider_silk":     {"name": "거미줄 실",   "sell": 3},
	# 연상 잡템(침입자 드랍 10%) — 매입가 출처: 기획_전리품보석도감.md §2 (플레이테스트 튜닝 대상)
	"cheese_crumb":    {"name": "치즈 부스러기", "sell": 1},
	"cheese":          {"name": "치즈 조각",   "sell": 4},
	"nail":            {"name": "녹슨 못",     "sell": 2},
	"button":          {"name": "단추",        "sell": 2},
	"thread_spool":    {"name": "실패",        "sell": 2},
	"safety_pin":      {"name": "옷핀",        "sell": 2},
	"cotton":          {"name": "솜뭉치",      "sell": 1},
	"bread":           {"name": "빵 조각",     "sell": 1},
	"honeycomb":       {"name": "벌집",        "sell": 4},
	# 보석 18종 사다리(등급별 독립 드랍 · §5.5) — 자갈~다이아
	"gem_gravel":      {"name": "얼룩 자갈",     "sell": 15},
	"gem_pebble":      {"name": "빛나는 조약돌", "sell": 30},
	"gem_shell":       {"name": "조개껍데기",   "sell": 55},
	"gem_marble":      {"name": "유리구슬",     "sell": 90},
	"gem_glass_bead":  {"name": "투명 구슬",    "sell": 140},
	"gem_agate":       {"name": "마노",        "sell": 220},
	"gem_quartz":      {"name": "수정 원석",    "sell": 340},
	"gem_amber":       {"name": "호박",        "sell": 520},
	"gem_amethyst":    {"name": "자수정",      "sell": 800},
	"gem_garnet":      {"name": "석류석",      "sell": 1250},
	"gem_rose":        {"name": "로즈쿼츠",     "sell": 1900},
	"gem_teal":        {"name": "청록석",      "sell": 2900},
	"gem_sapphire":    {"name": "사파이어",    "sell": 4400},
	"gem_emerald":     {"name": "에메랄드",     "sell": 6800},
	"gem_pearl":       {"name": "진주",        "sell": 10500},
	"gem_teardrop":    {"name": "눈물 수정",    "sell": 16000},
	"gem_ruby":        {"name": "루비",        "sell": 25000},
	"gem_diamond":     {"name": "다이아몬드",  "sell": 50000},
}
const MAT_ORDER := ["fur_gray", "fur_black", "wheel", "sack", "bat_wing", "sparrow_feather", "honey_drop", "spider_silk", "cheese_crumb", "cheese", "nail", "button", "thread_spool", "safety_pin", "cotton", "bread", "honeycomb", "gem_gravel", "gem_pebble", "gem_shell", "gem_marble", "gem_glass_bead", "gem_agate", "gem_quartz", "gem_amber", "gem_amethyst", "gem_garnet", "gem_rose", "gem_teal", "gem_sapphire", "gem_emerald", "gem_pearl", "gem_teardrop", "gem_ruby", "gem_diamond"]
## 보석 사다리 순서(자갈→다이아) — 펄 헌납·도감 등에서 사용
const GEM_ORDER := ["gem_gravel", "gem_pebble", "gem_shell", "gem_marble", "gem_glass_bead", "gem_agate", "gem_quartz", "gem_amber", "gem_amethyst", "gem_garnet", "gem_rose", "gem_teal", "gem_sapphire", "gem_emerald", "gem_pearl", "gem_teardrop", "gem_ruby", "gem_diamond"]
var materials := {}   # id -> 보유 수 (lazy: 없으면 0)
var run_loot := {}    # 이번 전투에서 얻은 전리품(클리어 화면 표시용, 세이브 안 함)

## 전투 시작 시 호출 — 이번 판 전리품 집계 리셋 + 곳간 축복 동전 배율 + 축복 1회 소비
## (player._ready가 game._ready보다 먼저 실행되어 발톱·배는 이미 적용된 뒤 여기서 소비됨)
func start_battle_loot() -> void:
	run_loot = {}
	run_coin_mult = (1.0 + blessing_pct("coin")) if selected_blessing == "coin" else 1.0
	selected_blessing = ""   # 축복은 1회용 — 매 출격마다 펄에게 다시 받아야 함(§5.5)

func add_material(id: String, n: int = 1) -> void:
	materials[id] = int(materials.get(id, 0)) + n
	run_loot[id] = int(run_loot.get(id, 0)) + n   # 이번 판 집계

## 클리어 화면용 — 이번 판 전리품 요약 문자열("회색쥐 털 ×4, 보석 ×1") / 없으면 ""
func run_loot_summary() -> String:
	var parts: Array = []
	for id in MAT_ORDER:
		var n: int = int(run_loot.get(id, 0))
		if n > 0:
			parts.append("%s ×%d" % [String(MATERIALS[id]["name"]), n])
	return ", ".join(parts)

func mat_count(id: String) -> int:
	return int(materials.get(id, 0))

func sell_material(id: String, n: int = 1) -> int:
	## n개 판매 → 얻은 코인 반환(보유보다 많으면 보유만큼). n<0 = 전량.
	if not MATERIALS.has(id):
		return 0
	var have := mat_count(id)
	if n < 0:
		n = have
	n = clampi(n, 0, have)
	if n <= 0:
		return 0
	var gain := n * int(MATERIALS[id]["sell"])
	materials[id] = have - n
	coins += gain
	if mode != "dev" and AUTOSAVE:
		save_game()
	return gain

## --- 직업 제작 (상점, 시스템밸런스 §5.2-B) ---
## 메이드 = 회색쥐 털×12 + 포대 조각×2 + 치즈 부스러기×4 + 코인500
## 음악가 = 회색쥐 털×12 + 롤러 바퀴×2 + 녹슨 못×1 + 코인500
const CRAFT_RECIPES := {
	"maid": {"name": "메이드", "coin": 500, "mats": {"fur_gray": 12, "sack": 2, "cheese_crumb": 4}},
	"jazz": {"name": "음악가", "coin": 500, "mats": {"fur_gray": 12, "wheel": 2, "nail": 1}},
}

## 1등급(이름없는) 제작 가능? — 레시피 있고, 아직 1등급 미보유, 상점에 노출(해금)됐고, 자원 충분.
##  (unlocked_jobs = "상점 제작 노출" / owns_job = "이미 1등급 보유" — 새 모델: 둘은 별개)
func can_craft_job(job: String) -> bool:
	if not CRAFT_RECIPES.has(job) or owns_job(job) or not is_job_unlocked(job):
		return false
	var r: Dictionary = CRAFT_RECIPES[job]
	if coins < int(r["coin"]):
		return false
	for mid in r["mats"]:
		if mat_count(mid) < int(r["mats"][mid]):
			return false
	return true

func craft_job(job: String) -> bool:
	if not can_craft_job(job):
		return false
	var r: Dictionary = CRAFT_RECIPES[job]
	coins -= int(r["coin"])
	for mid in r["mats"]:
		materials[mid] = mat_count(mid) - int(r["mats"][mid])
	if not unlocked_jobs.has(job):
		unlocked_jobs.append(job)
	_add_grade(job, 1)   # 1등급(이름없는) 장비를 보유로 추가
	if mode != "dev" and AUTOSAVE:
		save_game()
	return true

## --- 스킬 시스템 (로드맵 5단계, 시스템밸런스 §4.2·§2.4·§2.2) ---
## order: 1번째(1-9,250) / 2번째(1-15,500) / 3번째(2막 라쿤,1000·Lv3 슬롯)
## scaled: 데미지·수치가 Lv 배율(§2.2)을 받는지. cd: 쿨타임(초). base: Lv1 수치값.
## kind: 전투 발동 종류(combat). dur/pct 등은 Lv 불변(§규칙C).
const SKILLS := {
	# 보안관: 제어 / 생존 / 광역딜
	"warn_shot": {"job": "sheriff", "name": "경고 사격", "order": 1, "cd": 10.0, "price": 250,  "scaled": false, "kind": "stagger", "dur": 2.5, "desc": "다가오는 침입자 2~3초 멈칫 + 살짝 밀기"},
	"shield":    {"job": "sheriff", "name": "방패 자세", "order": 2, "cd": 18.0, "price": 500,  "scaled": false, "kind": "guard",   "dur": 4.0, "pct": 0.40, "desc": "4초 받는 피해 40%↓"},
	"support":   {"job": "sheriff", "name": "지원 요청", "order": 3, "cd": 35.0, "price": 1000, "scaled": true,  "kind": "barrage", "base": 60.0, "delay": 1.0, "desc": "1초 후 화면 전체 60×Lv"},
	# 메이드: 넉백딜 / 바닥제어 / 원거리광역
	"sweep":     {"job": "maid", "name": "대청소", "order": 1, "cd": 12.0, "price": 250,  "scaled": true,  "kind": "knockback", "base": 30.0, "desc": "광역 강제 넉백 + 30×Lv"},
	"wax":       {"job": "maid", "name": "왁스칠", "order": 2, "cd": 16.0, "price": 500,  "scaled": false, "kind": "slowfield", "dur": 4.0, "pct": 0.60, "desc": "4초 미끄럼 장판, 이속 60%↓"},
	"plates":    {"job": "maid", "name": "접시 폭풍", "order": 3, "cd": 30.0, "price": 1000, "scaled": true,  "kind": "platestorm", "base": 25.0, "desc": "접시 난사, 각 25×Lv"},
	# 음악가: 광역딜 / 스턴 / 자가버프
	"discord":   {"job": "jazz", "name": "불협화음", "order": 1, "cd": 10.0, "price": 250,  "scaled": true,  "kind": "aoe_slow", "base": 35.0, "slow_dur": 1.5, "desc": "광역 35×Lv + 1.5초 둔화"},
	"lullaby":   {"job": "jazz", "name": "자장가", "order": 2, "cd": 20.0, "price": 500,  "scaled": false, "kind": "stun", "dur": 2.0, "desc": "범위 2초 스턴"},
	"encore":    {"job": "jazz", "name": "앵콜", "order": 3, "cd": 30.0, "price": 1000, "scaled": false, "kind": "selfbuff", "dur": 6.0, "aspd": 0.40, "mspd": 0.20, "desc": "6초 공속+40%·이속+20%"},
}
var owned_skills: Array = []                                  # 보유 스킬 id
var equipped_skills := {"sheriff": [], "maid": [], "jazz": []}  # job -> 장착 슬롯 배열

## 현재 직업×Lv 활성 슬롯 수(§2.2): 맨몸 0 / Lv1·2 2 / Lv3·4 3 / Lv5 4
func skill_slots(job: String = "") -> int:
	var j := job if job != "" else selected_job
	if j == "base":
		return 0
	var g := equipped_grade if j == selected_job else top_grade(j)
	if g >= 5:
		return 4
	if g >= 3:
		return 3
	return 2

func owns_skill(id: String) -> bool:
	return owned_skills.has(id)

## 1막 구매 가능: 보유 직업 스킬 + 미보유 + order≤2(3번째는 2막) + 코인 충분
func can_buy_skill(id: String) -> bool:
	if not SKILLS.has(id) or owns_skill(id):
		return false
	var s: Dictionary = SKILLS[id]
	if not is_job_unlocked(s["job"]):
		return false
	if int(s["order"]) >= 3:
		return false   # 3번째 스킬 = 2막 라쿤(미판매)
	return coins >= int(s["price"])

func buy_skill(id: String) -> bool:
	if not can_buy_skill(id):
		return false
	coins -= int(SKILLS[id]["price"])
	owned_skills.append(id)
	if mode != "dev" and AUTOSAVE:
		save_game()
	return true

## 직업의 보유 스킬 id 목록
func owned_for(job: String) -> Array:
	var out: Array = []
	for id in owned_skills:
		if SKILLS.has(id) and SKILLS[id]["job"] == job:
			out.append(id)
	return out

## 직업의 장착 스킬(활성 슬롯 수로 자른 것)
func equipped_for(job: String) -> Array:
	var arr: Array = equipped_skills.get(job, [])
	var n := skill_slots(job)
	return arr.slice(0, n) if arr.size() > n else arr

func is_equipped(job: String, id: String) -> bool:
	return equipped_for(job).has(id)

func equip_skill(job: String, id: String) -> bool:
	if not owns_skill(id) or SKILLS.get(id, {}).get("job", "") != job:
		return false
	var arr: Array = equipped_skills.get(job, [])
	if arr.has(id):
		return true
	if arr.size() >= skill_slots(job):
		return false
	arr.append(id)
	equipped_skills[job] = arr
	if mode != "dev" and AUTOSAVE:
		save_game()
	return true

func unequip_skill(job: String, id: String) -> bool:
	var arr: Array = equipped_skills.get(job, [])
	arr.erase(id)
	equipped_skills[job] = arr
	if mode != "dev" and AUTOSAVE:
		save_game()
	return true

## 스킬 수치(데미지/회복 등) — scaled면 §2.2 Lv 배율 곱함
func skill_value(id: String) -> float:
	var s: Dictionary = SKILLS.get(id, {})
	var v := float(s.get("base", 0.0))
	if bool(s.get("scaled", false)):
		v *= level_mult()   # 장착 등급 배율(전투 중 = 장착 직업의 스킬)
	return v

## --- 동료(호루라기) 시스템 (로드맵 6단계, 시스템밸런스 §5.5-B) ---
## 만남(meet 스테이지·무료 이벤트) 후 호루라기를 맥스에서 구매. 슬롯 1개 → 매 판 택1, 전투 중 호출.
## kind: 전투 발동 종류. meet: 만남 스테이지(1-13/1-16).
const COMPANIONS := {
	"dove":      {"name": "비둘기", "price": 300, "cd": 22.0, "meet": 13, "kind": "dove_bomb",  "dmg": 10.0, "slow_dur": 3.0, "slow_pct": 0.40, "desc": "전방 광역 똥 폭격 — 3초 둔화 40%↓ + 딜"},
	"chihuahua": {"name": "치와와", "price": 500, "cd": 30.0, "meet": 16, "kind": "dog_charge", "dmg": 5.0,  "desc": "좌→우로 달리며 지상 침입자 전부 밀어냄"},
}
const COMPANION_ORDER := ["dove", "chihuahua"]
var owned_companions: Array = []      # 보유(호루라기 구매) 동료 id
var equipped_companion: String = ""   # 장착(매 판 택1) 동료 id

func owns_companion(id: String) -> bool:
	return owned_companions.has(id)

## 1막 구매 가능: 미보유 + 코인 충분 (기획상 meet 이벤트 후지만, 상점이 테스트 상시노출이라 코인만 게이팅)
func can_buy_companion(id: String) -> bool:
	if not COMPANIONS.has(id) or owns_companion(id):
		return false
	return coins >= int(COMPANIONS[id]["price"])

func buy_companion(id: String) -> bool:
	if not can_buy_companion(id):
		return false
	coins -= int(COMPANIONS[id]["price"])
	owned_companions.append(id)
	if equipped_companion == "":
		equipped_companion = id   # 첫 동료는 자동 장착
	if mode != "dev" and AUTOSAVE:
		save_game()
	return true

func equip_companion(id: String) -> void:
	if id == "" or owns_companion(id):
		equipped_companion = id   # ""(해제) 또는 보유 동료
		if mode != "dev" and AUTOSAVE:
			save_game()

## [개발자용] 동료 둘 다 지급 + 첫 동료 장착 (동료 테스트)
func dev_grant_companions() -> void:
	owned_companions = ["dove", "chihuahua"]
	equipped_companion = "dove"

## --- 펄: 출격 축복 + 호감도(보석 헌납) (로드맵 6단계, 시스템밸런스 §5.5) ---
## 1-5 해금. 출격 전 축복 1개 택1(매 판). 보석 헌납 → 호감도 누적 → 레벨↑ → 축복 강화.
const BLESSINGS := {
	"claw":  {"name": "맹수의 발톱", "kind": "atk",  "desc": "이번 판 공격력 +"},
	"belly": {"name": "튼튼한 배",   "kind": "hp",   "desc": "이번 판 체력 +"},
	"coin":  {"name": "부자집 곳간", "kind": "coin", "desc": "이번 판 동전 획득 +"},
}
const BLESSING_ORDER := ["claw", "belly", "coin"]
const GEM_FAVOR := {"gem_gravel": 1, "gem_pebble": 1, "gem_shell": 2, "gem_marble": 2, "gem_glass_bead": 3, "gem_agate": 4, "gem_quartz": 6, "gem_amber": 8, "gem_amethyst": 12, "gem_garnet": 17, "gem_rose": 24, "gem_teal": 33, "gem_sapphire": 45, "gem_emerald": 62, "gem_pearl": 85, "gem_teardrop": 115, "gem_ruby": 155, "gem_diamond": 200}
const FAVOR_THRESHOLDS := [40, 120, 320, 800]   # Lv2/Lv3/Lv4/Lv5 누적 호감도(가속 곡선, 2026-06-04 재계산). Lv3=1막 현실 천장 / Lv4·5=2막+
var pearl_favor: int = 0          # 누적 호감도
var selected_blessing: String = ""   # 이번 판 축복("claw"/"belly"/"coin"/"")
var run_coin_mult: float = 1.0    # 이번 판 동전 배율(곳간 축복)

func pearl_unlocked() -> bool:
	return stage_minor >= 6   # 1-5 클리어 후

func pearl_level() -> int:
	var lv := 1
	for t in FAVOR_THRESHOLDS:
		if pearl_favor >= int(t):
			lv += 1
	return lv

func favor_to_next() -> int:
	var lv := pearl_level()
	if lv > FAVOR_THRESHOLDS.size():
		return 0   # Lv5 만렙
	return int(FAVOR_THRESHOLDS[lv - 1]) - pearl_favor

## 축복 효과 %: 공격/체력 = 15%~30% / 동전 = 25%~50% (호감도 Lv1~5 강화, §5.5)
func blessing_pct(kind: String) -> float:
	var lv := pearl_level()
	if kind == "coin":
		return 0.25 + float(lv - 1) * 0.0625
	return 0.15 + float(lv - 1) * 0.0375

func set_blessing(id: String) -> void:
	selected_blessing = id if BLESSINGS.has(id) else ""
	if mode != "dev" and AUTOSAVE:
		save_game()

## 보석 헌납 → 호감도. 헌납한 favor 반환(0=실패)
func donate_gem(id: String) -> int:
	if not GEM_FAVOR.has(id) or mat_count(id) <= 0:
		return 0
	materials[id] = mat_count(id) - 1
	var g := int(GEM_FAVOR[id])
	pearl_favor += g
	if mode != "dev" and AUTOSAVE:
		save_game()
	return g

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


## 클리어 이벤트 텍스트(로드맵 2-B) — 해당 스테이지 클리어 시 띄울 해금 이벤트. 없으면 "".
## (지금은 placeholder 안내 텍스트. 나중에 컷신·NPC를 이 자리에 끼움.)
## 해금 이벤트 씬으로 넘길 때, 방금 깬 스테이지 번호(이벤트 씬이 읽고 0으로 리셋). 세이브 안 함(전환용)
var pending_event_stage: int = 0

func clear_event_for(stage: int) -> String:
	match stage:
		3:  return "보안관이 합류했다!\n전투 준비에서 직업으로 선택할 수 있어."
		5:  return "고양이 숙녀 '펄'을 만났다.\n(펄 시스템은 준비 중 — 로드맵 6단계)"
		7:  return "맥스의 상점이 열렸다!\n메이드·음악가를 전리품으로 제작할 수 있어."
		9:  return "맥스가 스킬을 팔기 시작했다!\n상점 [스킬] 탭에서 직업 스킬 구매."
		10: return "중간보스 펑거스를 물리쳤다!"
		13: return "비둘기 동료를 만났다.\n(동료 시스템은 준비 중)"
		15: return "두 번째 스킬을 살 수 있게 됐다!"
		16: return "치와와 동료를 만났다.\n(동료 시스템은 준비 중)"
		19: return "직업 2등급(떠오르는) 제작이 열렸다!\n맥스 상점에서 상위 등급 직업을 만들 수 있어."
		20: return "최종보스 큰 뱀을 물리쳤다! 1막 클리어!"
		_:  return ""


## [개발자용] 현재 선택 직업의 스킬을 전부 지급 + 슬롯만큼 장착 (스킬 테스트)
func dev_grant_skills() -> void:
	var job := selected_job
	if job == "base":
		job = "sheriff"
		selected_job = "sheriff"
		if not unlocked_jobs.has("sheriff"):
			unlocked_jobs.append("sheriff")
	_add_grade(job, maxi(1, equipped_grade if job == selected_job else top_grade(job)))
	equipped_skills[job] = []
	for sid in SKILLS:
		if SKILLS[sid]["job"] == job:
			if not owned_skills.has(sid):
				owned_skills.append(sid)
			if equipped_skills[job].size() < skill_slots(job):
				equipped_skills[job].append(sid)


## 도달한(현재) 스테이지 기준으로 해금 직업 보강 — idempotent(세이브 로드 후에도 안전)
func _check_stage_unlocks() -> void:
	if stage_minor >= 4:                          # 1-3 클리어 → 보안관 "지급"(1등급 보유)
		if not unlocked_jobs.has("sheriff"):
			unlocked_jobs.append("sheriff")
		_add_grade("sheriff", 1)
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
	equipped_grade = 1
	owned_grades = {"base": [1]}
	coins = 0
	inventory = {"bandage": 0, "milk": 0, "anchovy": 0, "firecracker": 0, "bomb": 0, "pepper": 0, "mousetrap": 0}
	materials = {}
	item_slots = ["", "", ""]
	owned_skills = []
	equipped_skills = {"sheriff": [], "maid": [], "jazz": []}
	owned_companions = []
	equipped_companion = ""
	pearl_favor = 0
	selected_blessing = ""
	run_coin_mult = 1.0

## 직업별 기본 스탯 + 크리티컬
##  hp=체력 / ranged=원거리 / near=근거리 / atk_spd=공격속도 / move=이동배율
##  crit=크리율 / crit_type=크리효과(strike 강타·knockback 강넉백·stun 스턴) / crit_mult=강타 배수
##  rmode=원거리 발사방식(straight 일자 / lob 포물선던지기)
##  rlimit=일자 사거리(화면폭 대비 비율, 0=끝까지) / misfire=불발 확률(보안관)
##  rshape=투사체 모양(dot 흰원 / stone 회색돌 / plate 접시 / note 음표)
##  rdelay=공격 시작 후 실제 발사까지 딜레이(초) — 모션 타이밍 맞춤
const JOB_STATS := {
	"base":    {"hp": 80.0,  "ranged": 6.0,  "near": 8.0,  "atk_spd": 0.9, "move": 1.0,  "crit": 0.05, "crit_type": "strike",    "crit_mult": 1.5, "rmode": "lob",      "rlimit": 0.0, "misfire": 0.0,  "rshape": "stone", "rdelay": 0.2, "melee_targets": 2},
	"sheriff": {"hp": 140.0, "ranged": 13.0, "near": 11.0, "atk_spd": 0.8, "move": 1.0,  "crit": 0.15, "crit_type": "strike",    "crit_mult": 2.0, "rmode": "straight", "rlimit": 0.0, "misfire": 0.12, "rshape": "dot",   "rdelay": 0.12, "melee_targets": 2},
	"maid":    {"hp": 110.0, "ranged": 5.0,  "near": 18.0, "atk_spd": 1.0, "move": 1.25, "crit": 0.15, "crit_type": "knockback", "crit_mult": 1.0, "rmode": "lob",      "rlimit": 0.0, "misfire": 0.0,  "rshape": "plate", "rdelay": 0.2, "melee_targets": 3},
	"jazz":    {"hp": 90.0,  "ranged": 16.0, "near": 4.0,  "atk_spd": 0.9, "move": 0.9,  "crit": 0.12, "crit_type": "stun",      "crit_mult": 1.0, "rmode": "straight", "rlimit": 0.72, "misfire": 0.0,  "rshape": "note",  "rdelay": 0.0, "melee_targets": 2},
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

## ★보유 등급 세트 (직업 → 보유한 등급 Array, 정렬). 각 (직업×등급) = 별개 장비.
##   맨몸은 항상 [1](등급 개념 없음). 제작/해금/dev로 추가됨.
var owned_grades: Dictionary = {"base": [1]}
## 현재 장착된 직업의 등급(전투 배율·슬롯·표기에 쓰임). selected_job과 짝.
var equipped_grade: int = 1


## 맨몸은 등급 라벨이 없다
func has_rank(job: String) -> bool:
	return job != "base"


## 직업+등급 호칭 (예: 견습 보안관). grade 생략 시 표시용 등급 자동.
func job_title(job: String, grade: int = 0) -> String:
	var names: Array = JOB_TITLES.get(job, ["?"])
	var g := grade if grade > 0 else display_grade(job)
	return names[clampi(g - 1, 0, names.size() - 1)]


## 등급 라벨 텍스트 (맨몸은 "")
func rank_label(grade: int = 0, job: String = "") -> String:
	if job == "base":
		return ""
	var g := grade if grade > 0 else display_grade(job if job != "" else selected_job)
	return RANK_LABELS[clampi(g - 1, 0, RANK_LABELS.size() - 1)]


## 등급 라벨 색
func rank_color(grade: int = 0, job: String = "") -> Color:
	var g := grade if grade > 0 else display_grade(job if job != "" else selected_job)
	return rank_colors[clampi(g - 1, 0, rank_colors.size() - 1)]


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
		"selected_job": selected_job,   # 마지막 장착 직업
		"equipped_grade": equipped_grade,  # 장착 등급
		"owned_grades": owned_grades,   # 보유 (직업×등급) 세트(★등급=별개 장비)
		"inventory": inventory,         # 소모품 보유(상점 구매, 로드맵 4단계)
		"materials": materials,         # 전리품 보유(드랍·매입·제작, 로드맵 4단계)
		"item_slots": item_slots,       # 소모품 슬롯 배치(로드맵 4단계)
		"owned_skills": owned_skills,   # 보유 스킬(로드맵 5단계)
		"equipped_skills": equipped_skills,  # 장착 스킬(로드맵 5단계)
		"owned_companions": owned_companions,    # 보유 동료(로드맵 6단계)
		"equipped_companion": equipped_companion,
		"pearl_favor": pearl_favor,              # 펄 호감도(로드맵 6단계)
		"selected_blessing": selected_blessing,
		"bgm_enabled": bgm_enabled,              # 배경음악 켜짐 여부
		"prologue_seen": prologue_seen,          # 프롤로그 봤는지
		"coachmark_seen": coachmark_seen,        # 홈 코치마크 본 항목
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
		bgm_enabled = bool(data.get("bgm_enabled", true))
		prologue_seen = bool(data.get("prologue_seen", false))
		coachmark_seen = []
		var cms = data.get("coachmark_seen", [])
		if typeof(cms) == TYPE_ARRAY:
			for c in cms:
				coachmark_seen.append(String(c))
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
		# 보유 등급 세트 복원 (없으면 옛 job_level에서 마이그레이션: Lv N → 1..N 보유)
		owned_grades = {"base": [1]}
		var og = data.get("owned_grades", null)
		if typeof(og) == TYPE_DICTIONARY:
			for k in og.keys():
				var arr: Array = []
				for g in og[k]:
					var gi := clampi(int(g), 1, 5)
					if not arr.has(gi):
						arr.append(gi)
				arr.sort()
				if arr.size() > 0:
					owned_grades[String(k)] = arr
		else:
			var jl = data.get("job_level", {})
			if typeof(jl) == TYPE_DICTIONARY:
				for k in jl.keys():
					var lv := clampi(int(jl[k]), 1, 5)
					owned_grades[String(k)] = range(1, lv + 1)
		if not owns_job("base"):
			owned_grades["base"] = [1]
		# 장착 직업이 미보유면 맨몸으로
		if not owns_job(selected_job):
			selected_job = "base"
		equipped_grade = clampi(int(data.get("equipped_grade", maxi(1, top_grade(selected_job)))), 1, 5)
		# 소모품 보유 복원
		var inv = data.get("inventory", {})
		if typeof(inv) == TYPE_DICTIONARY:
			for k in inventory.keys():
				inventory[k] = maxi(0, int(inv.get(k, 0)))
		# 전리품 보유 복원
		materials = {}
		var mat = data.get("materials", {})
		if typeof(mat) == TYPE_DICTIONARY:
			for k in mat.keys():
				if MATERIALS.has(k):
					materials[k] = maxi(0, int(mat[k]))
		# 소모품 슬롯 복원
		var slots = data.get("item_slots", [])
		if typeof(slots) == TYPE_ARRAY:
			for i in range(3):
				var v := String(slots[i]) if i < slots.size() else ""
				item_slots[i] = v if CONSUMABLES.has(v) else ""
		# 스킬 보유·장착 복원
		owned_skills = []
		var osk = data.get("owned_skills", [])
		if typeof(osk) == TYPE_ARRAY:
			for s in osk:
				if SKILLS.has(String(s)) and not owned_skills.has(String(s)):
					owned_skills.append(String(s))
		equipped_skills = {"sheriff": [], "maid": [], "jazz": []}
		var esk = data.get("equipped_skills", {})
		if typeof(esk) == TYPE_DICTIONARY:
			for j in equipped_skills.keys():
				var arr = esk.get(j, [])
				if typeof(arr) == TYPE_ARRAY:
					for s in arr:
						var sid := String(s)
						if SKILLS.has(sid) and SKILLS[sid]["job"] == j and owned_skills.has(sid):
							equipped_skills[j].append(sid)
		# 동료 복원(로드맵 6단계)
		owned_companions = []
		var ocp = data.get("owned_companions", [])
		if typeof(ocp) == TYPE_ARRAY:
			for c in ocp:
				if COMPANIONS.has(String(c)) and not owned_companions.has(String(c)):
					owned_companions.append(String(c))
		var ec := String(data.get("equipped_companion", ""))
		equipped_companion = ec if owned_companions.has(ec) else ""
		# 펄 호감도·축복 복원(로드맵 6단계)
		pearl_favor = maxi(0, int(data.get("pearl_favor", 0)))
		var sbl := String(data.get("selected_blessing", ""))
		selected_blessing = sbl if BLESSINGS.has(sbl) else ""

func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	reset_progress()
	coins = 0
