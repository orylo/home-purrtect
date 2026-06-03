extends "res://scripts/npc_talk.gd"
## 펄 — 미연시풍 대화 화면 (로드맵 6단계, §5.5 / 기획_펄로맨스.md).
##   출격 축복은 1회용 — 매번 찾아와 받아야 함. 보석 헌납으로 호감도↑.

const PINK := Color(1.0, 0.72, 0.86)
const PURPLE := Color(0.78, 0.55, 0.85)

const GREET := [
	"",
	"어머, 또 오셨네요. …무슨 일이시죠?",
	"당신은… 왜 제게 잘 보이려 하지 않죠? (호기심)",
	"그, 그렇게 빤히 보지 마세요… (얼굴 붉힘)",
	"당신 앞에선 자꾸 가면이 흘러내려요…",
	"이제 당신 곁이 제일 편해요. …우리만의 비밀이에요.",
]


func _start() -> void:
	_menu()


func _menu() -> void:
	var lv: int = GameState.pearl_level()
	portrait(PURPLE, "shy" if lv >= 3 else "neutral")
	say("펄  ·  호감도 Lv%d" % lv, PINK, GREET[clampi(lv, 0, 5)])
	choices([
		["◆ 출격 축복을 받는다", _bless_menu],
		["◆ 보석을 바친다", _gift_menu],
		["나간다", _leave],
	])


func _bless_menu() -> void:
	portrait(PURPLE, "neutral")
	if GameState.selected_blessing != "":
		say("펄", PINK, "이미 가호를 내려드렸어요. 다음 출격에 함께할 거예요.")
	else:
		say("펄", PINK, "이번 출격, 무엇을 빌어드릴까요? (한 번만 드릴 수 있어요)")
	var items: Array = []
	for bid in GameState.BLESSING_ORDER:
		var d: Dictionary = GameState.BLESSINGS[bid]
		var pct: int = int(round(GameState.blessing_pct(d["kind"]) * 100.0))
		items.append(["%s  +%d%%" % [String(d["name"]), pct], _grant.bind(bid)])
	items.append(["뒤로", _menu])
	choices(items)


func _grant(bid: String) -> void:
	GameState.set_blessing(bid)
	portrait(PURPLE, "happy")
	say("펄", PINK, "%s — 이번 한 번뿐이에요.\n부디… 살아 돌아오세요." % String(GameState.BLESSINGS[bid]["name"]))
	choices([["고마워, 펄", _menu]])


func _gift_menu() -> void:
	portrait(PURPLE, "neutral")
	var items: Array = []
	for gid in GameState.GEM_ORDER:
		var n: int = GameState.mat_count(gid)
		if n > 0:
			items.append(["%s ×%d  (+%d)" % [String(GameState.MATERIALS[gid]["name"]), n, int(GameState.GEM_FAVOR[gid])], _gift.bind(gid)])
	if items.is_empty():
		say("펄", PINK, "…오늘은 빈손이시네요. (살짝 시무룩)")
		choices([["미안, 다음에", _menu]])
		return
	items.append(["뒤로", _menu])
	say("펄", PINK, "어떤 걸 제게 주시겠어요?")
	choices(items)


func _gift(gid: String) -> void:
	var g: int = GameState.donate_gem(gid)
	var rich: bool = g >= 15
	portrait(PURPLE, "happy" if rich else "neutral")
	if rich:
		say("펄", PINK, "어머… 이렇게 귀한 걸. (눈빛이 흔들린다)\n호감도 +%d" % g)
	else:
		say("펄", PINK, "고마워요. 마음, 받을게요.\n호감도 +%d" % g)
	choices([["더 줄게", _gift_menu], ["이만 갈게", _menu]])


func _leave() -> void:
	go("res://scenes/home.tscn")
