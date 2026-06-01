# Home Purrtect — 작업 지침 (CLAUDE.md)

## 프로젝트
1930년대 카툰풍(컵헤드 톤) 횡스크롤 액션 디펜스 게임. 가로 모드 · 2D · Godot 4.6 · iOS 우선.
개발자는 코딩 경험이 거의 없는 그래픽 디자이너(1인 인디). **친절하게, 한 번에 하나씩.**
라이브(웹): https://orylo.github.io/home-purrtect/

## 협업 구조 (중요)
두 개의 Claude가 역할을 나눠 일한다:
- **기획 챗 (claude.ai)**: 기획·설계·브레인스토밍. "무엇을 왜." `docs/기획_*.md`를 디벨롭.
- **나 (Claude Code)**: 실제 코딩·구현. "지금 무엇이 돌아가는가." 코드 + `docs/STATUS.md` 갱신.

사용자가 기획 챗에서 정리한 내용을 나에게 전달하면:
1. 해당 `docs/*.md`를 그 내용대로 갱신하고 깃헙에 push.
2. 구현까지 요청받으면 게임에 반영.
3. 작업할 때마다 `STATUS.md`에 "한 일 / 현재 현황 / 변경점"을 갱신해서 함께 push.

## 문서 역할
- `docs/기획_브리프.md` — 큰 그림(세계관·5막·시스템 개요·BM). 주인=기획.
- `docs/기획_시스템밸런스_1막.md` — 1막 상세 수치(전투·스탯·적·직업·보스). 주인=기획.
- `docs/기획_개발가이드.md` — 개발 순서·원칙. 주인=기획.
- `docs/STATUS.md` — 실제 구현 현황. 주인=나(Code), 작업마다 갱신.
- `docs/설계_·계획_플레이어-개발자모드.md` — 개발 인프라 설계/계획.
- **기획_\*.md = "미래 청사진(미구현 포함)" / STATUS.md = "실제 현실". 둘을 혼동하지 말 것.**

## 개발 원칙
1. **한 번에 다 만들지 않는다.** 작은 조각부터, 작동 확인 후 다음.
2. **임시 비주얼로 먼저**(컬러 박스), 그림은 나중에 교체.
3. 수치는 `기획_시스템밸런스_1막.md`를 따르되, **코드에서 튜닝한 값이 더 최신이면 그 값이 정답**(문서를 코드에 맞춤). 변경 시 STATUS에 기록.
4. 각 단계 끝에 **"어떻게 실행/확인하는지"** 알려줄 것(개발자가 초보).
5. **막히면 멈추고** 쉽게 설명하고 물어볼 것. 추측으로 밀어붙이지 말 것.
6. 사용자가 전달한 기획을 문서에 반영할 땐 **빠짐없이(특히 표 전체)** 옮길 것.

## Git / push 관습
- **커밋은 자주, push는 사용자가 "올려줘"라고 할 때만.** (push하면 자동으로 웹 배포됨)
- 웹에 올리는 변경이면 push 전에 `scripts/game_state.gd`의 `const BUILD`를 올린다(시작/선택 화면에 "0.NN ver." 표시).
- 미검증·보류 코드가 로컬에 커밋돼 있을 때 문서만 push해야 하면, 그 커밋을 origin 뒤로 재배치(rebase)해 **문서/대상 파일만 선별 push**한다. (의도치 않은 코드 라이브 방지)
- 커밋 메시지 끝: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

---

## 코드베이스 구조
```
home-purrtect/
├─ project.godot            # 프로젝트 설정·오토로드·입력맵 (메인씬 = scenes/start.tscn)
├─ export_presets.cfg       # 웹 export 설정 + html/head(OG·PWA·풀스크린 스크립트)
├─ scenes/                  # .tscn 씬
│  ├─ start.tscn            # 시작 화면(타이틀, [게임 시작]/[개발자 모드])
│  ├─ select.tscn           # 직업 선택 화면
│  ├─ dev_menu.tscn         # 개발자 메뉴(직업/Lv/스테이지/난이도/치트)
│  ├─ main.tscn             # 실제 게임 플레이(치즈·스포너·HUD·배경·디버그오버레이)
│  ├─ enemy_mouse.tscn      # 범용 적(쥐 스프라이트 + def로 종류별 구성)
│  ├─ bullet.tscn / enemy_bullet.tscn  # 치즈 탄환 / 적 탄환
│  └─ pop_effect.tscn       # 처치 "펑!" 이펙트
├─ scripts/                 # .gd (씬별 스크립트 + 오토로드)
├─ assets/
│  ├─ fonts/                # DoHyeon-Regular.ttf (웹 한글 검증된 폰트)
│  ├─ sprites/cheese/       # 직업별 치즈 SpriteFrames (base/sheriff/maid/jazz)
│  ├─ sprites/enemies/      # 적 스프라이트
│  ├─ backgrounds/          # 스테이지 배경(1920x1080 기준)
│  └─ ui/                   # caldera_theme.tres, 아이콘 등
├─ docs/                    # 기획·현황 문서(위 "문서 역할" 참조)
├─ web/                     # PWA manifest 등 웹 정적 파일
└─ .github/workflows/deploy.yml  # push→웹 배포 CI
```

### 오토로드 (project.godot, 전역 싱글톤)
- `Layout` (`layout.gd`) — 바닥선 y좌표·조작 영역 동적 계산(기기별 해상도 대응).
- `Touch` (`touch.gd`) — 모바일 가상 조이스틱/탭 입력 → `move_axis`·`consume_jump()` 등.
- `Fx` (`fx.gd`) — 화면 흔들림(`request_shake`)·히트스톱(`request_hitstop`).
- `GameState` (`game_state.gd`) — ★중심. 직업/스탯/Lv배율/명칭·등급/스테이지 진행/런 설정(mode·difficulty·cheats)/세이브(`user://save.json`)/`const BUILD`.
- `RotateGate` (`rotate_gate.gd`) — 세로 화면일 때 "가로로 돌려주세요" 게이트.
- `Enemies` (`enemy_data.gd`) — 적 10종 정의(ENEMY_DEFS) + 스테이지별 웨이브(STAGE_WAVES, §6-B).

### 코드 맵 (주요 스크립트)
- `player.gd` — 치즈: 이동/점프/앉기, 근접·원거리 자동전환 평타, 크리, 몸으로 밀기, 상태이상(독·둔화), 발밑 그림자·데미지 숫자.
- `enemy_mouse.gd` — 범용 적(`def`로 스탯·외형·행동 주입): 근접 찌르기 / 원거리 발사(직선·포물선) / 공중 / 방어력 / placeholder 드로잉.
- `enemy_data.gd` — 적 정의 + 스테이지 웨이브 데이터.
- `bullet.gd` / `enemy_bullet.gd` — 치즈 탄환(직업별 모양·포물선·깨짐) / 적 탄환(placeholder).
- `spawner.gd` — 현재 스테이지(`GameState.stage_minor`)의 웨이브를 읽어 종류별로 스폰.
- `game.gd` — 게임 코디네이터(스테이지 클리어/게임오버 흐름).
- `hud.gd` — 상단 정보바(HP·스테이지·적 수·일시정지) + 클리어/게임오버 패널.
- `bottom_hud.gd` / `joystick.gd` / `attack_button.gd` — 하단 모바일 조작 UI.
- `dev_menu.gd` / `debug_overlay.gd` — 개발자 메뉴 / 인게임 디버그 오버레이(🐞), 둘 다 DEV 게이트.
- `start.gd` / `select.gd` — 시작·직업선택 화면.
- `stage_background.gd` — 배경/바닥 정렬.

---

## 빌드 / 실행
- **에디터에서**: Godot로 프로젝트 열고 **F5**(메인씬 = `start.tscn`). 사용자가 가장 자주 쓰는 방법.
- **macOS Godot 바이너리**: `/Applications/Godot.app/Contents/MacOS/Godot` (헤드리스 검증·CI용).
- **특정 씬 바로 실행**: `Godot res://scenes/main.tscn`

## 검증 방법 (커밋 전 권장)
```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
# 1) 스크립트 구문 체크 (Layout/Fx/Enemies 등 오토로드 "Identifier not found"는 무시)
"$G" --headless --check-only --script scripts/파일.gd
# 2) 씬 로드 런타임 체크 (몇 초 띄웠다 종료, 에러 로그 확인)
"$G" --headless res://scenes/main.tscn --quit-after 200 2>&1 | grep -iE "SCRIPT ERROR|ERROR" | grep -viE "audio|driver|Vulkan|OpenGL|display"
```
- 오토로드 상태(예: 특정 스테이지)를 강제로 띄워 검증하려면, 임시 스모크 씬에서 `change_scene_to_file.call_deferred(...)`로 전환(_ready에서 즉시 전환 시 "tree busy" 에러).
- 최종 확인은 **사용자 F5** 또는 웹 배포 후 확인.

## 웹 배포
- `git push` → **GitHub Actions**(`.github/workflows/deploy.yml`) → **GitHub Pages**(~1~2분).
- 캐시버스트: CI가 `index.js`/`wasm`/`pck`/`audio.worklet.js` 파일명에 커밋 짧은 SHA를 붙임 → 새로고침만 해도 최신.
- og-image·manifest.webmanifest도 CI가 복사.

## 기술 메모 (함정 주의)
- 엔진 **Godot 4.6.3**, GDScript. 렌더 `gl_compatibility`(모바일 호환).
- **웹 한글 깨짐 방지**: 모든 텍스트에 **DoHyeon 폰트를 직접 지정**(라벨 `theme_override_fonts`, 코드 `draw_string`은 `preload`, gui custom_font). 테마 기본 폰트/`ThemeDB.fallback_font`/`get_theme_default_font()`는 웹에서 한글 안 나옴. **OTF는 웹에서 깨짐 → TTF만.**
  - DoHyeon에 없는 글자: `「」 · — …` (대체 표기) / 있는 글자: `♥ ▶`.
- **DEV 게이트**: `GameState.is_dev()`(현재 `const DEV := true`) — 출시 빌드에선 false로 dev 메뉴·🐞 오버레이·치트 전부 숨김.
- 좌표: 적·치즈는 발이 원점(`Layout.ground_y()`), 몸은 위(-y)로 그림. 공중 적은 시각 높이만 위로 올리고 충돌(관문)은 바닥선 유지.
- `Date.now()`/`randf` 등 시간·난수는 런타임에선 자유롭게 쓰되, 웨이브/적 정의 같은 데이터는 상수로.
