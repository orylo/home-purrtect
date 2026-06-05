extends Node
## 적 10종 정의 + 스테이지별 웨이브 구성 (시스템밸런스 §3.1 / §6-B).
## 회색쥐·검은쥐(맨몸)만 진짜 쥐 스프라이트, 나머지는 placeholder(색·크기로 구분).
## 아트 나오면 def의 sprite/color만 바꾸면 됨.
##
## def 필드:
##   name 이름 / hp / dmg / armor / spd(이동배율) / atkint(공격간격)
##   kind: "melee"(근접) / "lob"(포물선 투척) / "shoot"(직선 발사) / "dive"(공중→급강하 근접)
##   air: 공중(밀기 대상 아님, 높이 띄움) / sprite: 쥐 스프라이트 사용
##   color: placeholder 몸 색 / radius: placeholder 몸 크기(px)
##   range: 원거리 정지 사거리 / status: ""/"poison"/"slow" / bcolor: 탄환 색

const ENEMY_DEFS := {
	# --- 회색 1티어(지상) ---
	"gray":         {"name": "회색쥐", "hp": 20, "dmg": 5, "armor": 0, "spd": 0.9, "atkint": 1.0, "kind": "melee", "air": false, "sprite": true,  "color": Color(0.6, 0.6, 0.62), "radius": 44, "range": 0,   "status": "", "wt": 1.4, "st": 0.6,  "bcolor": Color(0.7,0.7,0.7)},
	"gray_roller":  {"name": "회색롤러쥐", "hp": 15, "dmg": 5, "armor": 0, "spd": 1.6, "atkint": 0.9, "kind": "melee", "air": false, "sprite": false, "color": Color(0.55, 0.6, 0.7), "radius": 38, "range": 0,   "status": "", "wt": 6.0, "st": 0.15, "bcolor": Color(0.7,0.7,0.7)},
	"gray_thrower": {"name": "회색투척쥐", "hp": 25, "dmg": 6, "armor": 0, "spd": 0.6, "atkint": 1.4, "kind": "lob",   "air": false, "sprite": false, "color": Color(0.55, 0.48, 0.4), "radius": 52, "range": 820, "status": "", "bcolor": Color(0.5,0.45,0.4)},
	# --- 검은 2티어(지상, 강화판) ---
	"black":        {"name": "검은쥐", "hp": 45, "dmg": 9, "armor": 2, "spd": 1.0, "atkint": 0.9, "kind": "melee", "air": false, "sprite": true,  "color": Color(0.2, 0.2, 0.22), "radius": 50, "range": 0,   "status": "", "wt": 2.0, "st": 0.7,  "bcolor": Color(0.3,0.3,0.3)},
	"black_roller": {"name": "검은롤러쥐", "hp": 30, "dmg": 8, "armor": 1, "spd": 1.8, "atkint": 0.8, "kind": "melee", "air": false, "sprite": false, "color": Color(0.22, 0.26, 0.34), "radius": 42, "range": 0,   "status": "", "wt": 6.0, "st": 0.15, "bcolor": Color(0.3,0.3,0.3)},
	"black_thrower":{"name": "검은투척쥐", "hp": 45, "dmg": 11, "armor": 1, "spd": 0.7, "atkint": 1.1, "kind": "lob",  "air": false, "sprite": false, "color": Color(0.28, 0.24, 0.2), "radius": 56, "range": 820, "status": "", "bcolor": Color(0.3,0.27,0.2)},
	# --- 비-쥐 4종 ---
	"bat":          {"name": "박쥐", "hp": 15, "dmg": 4, "armor": 0, "spd": 1.3, "atkint": 2.4, "kind": "shoot", "air": true,  "sprite": false, "high": true, "color": Color(0.42, 0.3, 0.5), "radius": 36, "range": 760, "status": "", "bcolor": Color(0.6,0.4,0.8)},
	"sparrow":      {"name": "참새", "hp": 20, "dmg": 6, "armor": 0, "spd": 1.2, "atkint": 1.3, "kind": "dive",  "air": true,  "sprite": false, "color": Color(0.7, 0.55, 0.35), "radius": 40, "range": 0,   "status": "", "bcolor": Color(0.7,0.55,0.35)},
	"bee":          {"name": "벌", "hp": 12, "dmg": 3, "armor": 0, "spd": 1.4, "atkint": 1.1, "kind": "shoot", "air": true,  "sprite": false, "color": Color(0.95, 0.78, 0.1), "radius": 28, "range": 820, "status": "poison", "bcolor": Color(0.95,0.8,0.1)},
	"spider":       {"name": "거미", "hp": 30, "dmg": 5, "armor": 0, "spd": 0.7, "atkint": 1.4, "kind": "shoot", "air": false, "sprite": false, "color": Color(0.25, 0.2, 0.28), "radius": 48, "range": 720, "status": "slow", "bcolor": Color(0.7,0.7,0.75)},
	# --- 보스(단일 개체 · placeholder · 스킬 없이 큰 덩치+큰 피통+접촉 공격) (§3.3) ---
	"boss_fungus":  {"name": "펑거스", "hp": 1000, "dmg": 14, "armor": 0, "spd": 0.45, "atkint": 1.5, "kind": "melee", "air": false, "sprite": false, "big": true, "color": Color(0.50, 0.20, 0.25), "radius": 120, "range": 0, "status": "", "bcolor": Color(0.7,0.4,0.4)},
	"boss_snake":   {"name": "큰 뱀", "hp": 1900, "dmg": 20, "armor": 0, "spd": 0.55, "atkint": 1.4, "kind": "melee", "air": false, "sprite": false, "big": true, "color": Color(0.25, 0.42, 0.22), "radius": 150, "range": 0, "status": "", "bcolor": Color(0.4,0.6,0.3)},
}

## 적별 처치 코인 (시스템밸런스 §3.1 "코인" 칸). 보스는 처치 코인 + 클리어 보너스 별도(§5.1).
const ENEMY_COIN := {
	"gray": 2, "gray_roller": 2, "gray_thrower": 3,
	"black": 5, "black_roller": 5, "black_thrower": 6,
	"bat": 3, "sparrow": 3, "bee": 4, "spider": 4,
	"boss_fungus": 50, "boss_snake": 80,
}


## 스테이지별 웨이브 - 각 웨이브 = [[적id, 수], ...] (시스템밸런스 §6-B, 2026-06-02 개정)
## 새 적 등장 앞당김 + 거의 모든 웨이브 2종 이상 혼합 + 첫 등장은 ×1. 1-10/1-20은 보스(웨이브 없음).
## "롤러쥐"=gray_roller, "투척쥐"=gray_thrower (검은 계열은 black_*로 명시).
const STAGE_WAVES := {
	1:  [[["gray",3]], [["gray",4]]],
	2:  [[["gray",4]], [["gray",3],["gray_roller",1]], [["gray",3],["gray_roller",2]]],
	3:  [[["gray",3],["gray_roller",2]], [["gray",4],["gray_thrower",1]], [["gray",3],["gray_roller",2],["gray_thrower",1]]],
	4:  [[["gray",3],["gray_roller",2]], [["gray",3],["gray_thrower",2]], [["gray",4],["gray_roller",2],["gray_thrower",1]]],
	5:  [[["gray",4],["gray_roller",2]], [["gray",3],["gray_thrower",2],["bat",1]], [["gray",3],["gray_roller",2],["bat",2]]],
	6:  [[["gray",3],["gray_roller",2],["bat",1]], [["gray",4],["gray_thrower",2]], [["gray",3],["gray_roller",3],["bat",2]]],
	7:  [[["gray",4],["gray_thrower",2],["bat",1]], [["gray_roller",3],["bat",2]], [["gray",4],["gray_thrower",2],["bat",2]]],
	8:  [[["gray",3],["gray_roller",2],["bat",2]], [["gray_thrower",3],["bat",2]], [["gray",4],["gray_roller",3],["gray_thrower",2],["bat",2]]],
	9:  [[["gray",4],["gray_roller",2],["gray_thrower",2]], [["bat",3],["gray",3]], [["gray_roller",3],["gray_thrower",3],["bat",2]], [["gray",4],["gray_roller",2],["bat",2]]],
	10: [[["boss_fungus",1]]],   # 보스: 펑거스(단일)
	11: [[["gray",4],["black",1]], [["gray",3],["gray_roller",2],["black",2]], [["gray",3],["black",3],["bat",2]]],
	12: [[["gray",3],["black",2],["spider",1]], [["gray_roller",3],["black",2]], [["gray",3],["black",3],["spider",2]]],
	13: [[["black",2],["black_roller",1],["spider",1]], [["gray",3],["gray_roller",2],["spider",2]], [["black",3],["black_roller",2],["bat",2]]],
	14: [[["gray",3],["black",2],["bee",1]], [["black_thrower",2],["bat",2]], [["black",3],["spider",2],["bee",2]]],
	15: [[["black",2],["bee",2],["spider",1]], [["gray",3],["black_roller",2],["sparrow",1]], [["black",3],["sparrow",2],["bat",2]]],
	16: [[["black",3],["sparrow",2],["bat",2]], [["black_thrower",3],["bee",2]], [["black",3],["spider",2],["bee",2],["sparrow",2]]],
	17: [[["black",3],["black_roller",2],["spider",1]], [["sparrow",2],["bee",2],["bat",2]], [["black_thrower",3],["spider",2],["bee",2]], [["black",4],["gray_roller",2]]],
	18: [[["black",3],["black_roller",3],["spider",2]], [["bee",3],["spider",2],["bat",2]], [["sparrow",3],["bat",3],["bee",2]], [["black",4],["black_thrower",2],["gray_roller",2]]],
	19: [[["black",4],["gray_roller",2],["spider",2]], [["black_thrower",3],["bee",3],["sparrow",2]], [["bat",3],["bee",2],["spider",3]], [["black",4],["black_roller",3],["gray_thrower",2]]],
	20: [[["boss_snake",1]]],    # 보스: 큰 뱀(단일)
}


## --- 전리품 드랍 (시스템밸런스 §5.2, 2026-06-03 재정의) ---
## 쥐 계열 = 티어별 털 30% + 행동별 장비 15% + 연상 잡템 10% / 비-쥐 = 부위 15% + 연상 잡템 10%.
## 처치당 각 항목 독립 굴림(여러 종 동시 드랍 가능). 보석은 GEM_DROP에서 등급별 독립 굴림.
const DROP_TABLE := {
	"gray":          [["fur_gray", 0.30], ["cheese_crumb", 0.10]],
	"gray_roller":   [["fur_gray", 0.30], ["wheel", 0.15], ["nail", 0.10]],
	"gray_thrower":  [["fur_gray", 0.30], ["sack", 0.15], ["thread_spool", 0.10]],
	"black":         [["fur_black", 0.30], ["cheese", 0.10]],
	"black_roller":  [["fur_black", 0.30], ["wheel", 0.15], ["button", 0.10]],
	"black_thrower": [["fur_black", 0.30], ["sack", 0.15], ["safety_pin", 0.10]],
	"bat":           [["bat_wing", 0.15], ["cotton", 0.10]],
	"sparrow":       [["sparrow_feather", 0.15], ["bread", 0.10]],
	"bee":           [["honey_drop", 0.15], ["honeycomb", 0.10]],
	"spider":        [["spider_silk", 0.15], ["button", 0.10]],
	# 보스는 전리품 없음(코인·클리어 보너스로 보상). 보석 굴림은 전 침입자 공통 적용.
}
## 보석 = 등급별 독립 드랍률(§5.5, 처치당 각 보석 독립 굴림). 옛 "2% 후 비중 굴림" 폐기.
const GEM_DROP := [
	["gem_gravel", 0.030], ["gem_pebble", 0.022], ["gem_shell", 0.016], ["gem_marble", 0.011],
	["gem_glass_bead", 0.008], ["gem_agate", 0.0055], ["gem_quartz", 0.0038], ["gem_amber", 0.0026],
	["gem_amethyst", 0.0018], ["gem_garnet", 0.0012], ["gem_rose", 0.0008], ["gem_teal", 0.0005],
	["gem_sapphire", 0.0003], ["gem_emerald", 0.00018], ["gem_pearl", 0.00011], ["gem_teardrop", 0.00007],
	["gem_ruby", 0.00004], ["gem_diamond", 0.00002],
]

## 적 처치 시 떨군 전리품 id 배열 반환(런타임 난수). 전리품·보석 모두 독립 굴림.
func roll_drops(id: String) -> Array:
	var out: Array = []
	for entry in DROP_TABLE.get(id, []):
		if randf() < float(entry[1]):
			out.append(String(entry[0]))
	for g in GEM_DROP:
		if randf() < float(g[1]):
			out.append(String(g[0]))
	return out


## 스테이지 번호 → 웨이브 구성 (없으면 회색쥐 기본)
func waves_for(stage: int) -> Array:
	return STAGE_WAVES.get(stage, [[["gray", 3]], [["gray", 4]]])


func def_of(id: String) -> Dictionary:
	var d: Dictionary = ENEMY_DEFS.get(id, ENEMY_DEFS["gray"]).duplicate()
	d["coin"] = ENEMY_COIN.get(id, 2)   # 처치 코인 주입(원본 const는 안 건드림)
	d["id"] = id                         # 전리품 드랍용 id 주입
	return d
