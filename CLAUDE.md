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
- `docs/기획_홈시스템_로드맵.md` — 전투 위에 얹는 메타 루프(코인→홈→전투준비→상점→스킬→펄·동료) 6단계 순서. 주인=기획.
- `docs/기획_자산관리_전투준비.md` — 소유·장착형 자산(직업·스킬·동료) 관리 모델 + 전투 준비 화면(4탭·마지막세팅) 설계. 주인=기획.
- `docs/기획_이벤트연출가이드.md` — 이벤트 연출 체계(컷씬/팝업/인게임 이벤트 3타입·트리거·치즈 7스프라이트 제약·펑거스 말투·작성 포맷). "어떻게 만드나". 짝=`기획_이벤트대본_1막.md`(실제 대사·연출 비트 — 프롤로그·1-1·1-3 확정). 주인=기획.
- **★도감 5종(인벤토리/도감 화면 노출 문구 + 〔내부용〕 수치). 주인=기획, 같은 포맷·철칙 공유:**
  - `docs/기획_직업도감.md` — 직업 카드(출시 4종 + 등급 사슬).
  - `docs/기획_침입자도감.md` — 적("침입자") 10종 + 드랍.
  - `docs/기획_전리품보석도감.md` — 전리품 17 + 보석 18(매입가·호감도·드랍률).
  - `docs/기획_소모품도감.md` · `docs/기획_장난감도감.md` — 1막 소모품 3 + 장난감 4(가격·효과).
  - `docs/기획_아이템도감.md` — 에셋↔ID 매핑 + 미채택 후보 카탈로그(확정 문구·수치는 위 도감이 우선).
- `design.md` (루트) — **UI 디자인 시스템(토큰·규칙)**. 고전 카툰 톤(두꺼운 잉크 외곽선·크림+골든+빨강·빈티지 질감·8px 그리드). **UI를 만들거나 손볼 땐 반드시 먼저 읽고** 그 토큰만 따른다("예쁘게"가 아니라 "이 토큰으로"). 본문=Pretendard / 타이틀=잘난체·Luckiest Guy.
- `docs/STATUS.md` — 실제 구현 현황. 주인=나(Code), 작업마다 갱신.
- `docs/지침_공격스프라이트.md` — **공격 스프라이트 삽입 프로세스(분석→발사프레임→발사부위→코드→검증).** 주인=나(Code). 새 공격 모션 넣을 때 필독·준수(개발 원칙 8).
- `docs/설계_플레이어-개발자모드.md` — 개발 인프라 설계(구조·게이트).
- `docs/계획_플레이어-개발자모드.md` — 개발 인프라 구현 계획(Task 체크리스트).
- **기획_\*.md = "미래 청사진(미구현 포함)" / STATUS.md = "실제 현실". 둘을 혼동하지 말 것.**

## 개발 원칙
1. **한 번에 다 만들지 않는다.** 작은 조각부터, 작동 확인 후 다음.
2. **임시 비주얼로 먼저**(컬러 박스), 그림은 나중에 교체.
3. 수치는 `기획_시스템밸런스_1막.md`를 따르되, **코드에서 튜닝한 값이 더 최신이면 그 값이 정답**(문서를 코드에 맞춤). 변경 시 STATUS에 기록.
4. 각 단계 끝에 **"어떻게 실행/확인하는지"** 알려줄 것(개발자가 초보).
5. **막히면 멈추고** 쉽게 설명하고 물어볼 것. 추측으로 밀어붙이지 말 것.
6. 사용자가 전달한 기획을 문서에 반영할 땐 **빠짐없이(특히 표 전체)** 옮길 것.
7. **★도감·수치 정합성 규칙 (항상 얼라인 유지).** 같은 데이터가 **코드(SSOT) ↔ 도감 5종 ↔ 시스템밸런스 §3~§5 ↔ 아이템도감** 여러 곳에 걸쳐 있다. **어느 한 값(스탯·드랍률·매입가·호감도·가격·제작 레시피·이름·등장)을 바꾸면, 그 값이 등장하는 모든 문서를 같은 커밋에서 함께 고친다.**
   - **단일 진실원천(SSOT) = 코드(`game_state.gd`·`enemy_data.gd`).** 숫자가 갈리면 코드가 정답, 문서를 코드에 맞춘다.
   - **문구·정체성(노출 텍스트)의 정답 = 도감 5종.** `아이템도감`은 에셋 매핑/후보용 — 충돌 시 도감·코드 우선.
   - 값 변경 시 끝에 **자동 대조**(코드값 ↔ 문서값 grep/스모크)로 0건 확인하고, 못 맞춘 부분은 `STATUS.md`에 **[코드-기획 불일치]** 로 남긴다.
   - 밸런스 곡선(코인 수입·펄 호감도 등) 재계산이 필요하면 임의로 바꾸지 말고 **[밸런스 재계산 필요]** 만 표시(기획 챗이 별도 진행).
8. **★공격 스프라이트 삽입 = `docs/지침_공격스프라이트.md` 프로세스 준수.** 치즈·침입자 막론하고 새 공격 모션(특히 **원거리**)을 넣을 땐 반드시: ① attack 프레임 분석으로 **발사/타격 프레임** 찾기 → ② 발사 부위 **픽셀 위치** 측정 → ③ `ATK_RELEASE`/`EMIT_OFFSET`(+필요시 `LOOP_SHOOTERS`·`AIR_BOB`) 등록 → ④ **`--fixed-fps 60` 헤드리스 검증**. 이동·대기 모션은 대충 넣어도 되지만 공격은 스프라이트와 정확히 맞춘다.

## 버전 체계 (`const BUILD`, 형식 `X.Y.Z`)
- **X (메이저)**: 출시·대폭 변경급 매우 큰 업데이트. **`1.0.0` = 3막까지 완성 첫 정식 출시.**
- **Y (마이너)**: 장기적인 큰 이벤트를 목표로 한 특정 업데이트 완료 순간. **`0.1.0` = 지금 기획한 모든 것 코드 완료 = 1막 완전 완성.**
- **Z (패치)**: 지금처럼 **자잘한 모든 업데이트마다 +1.** **99에서 안 넘어가고 100으로 계속** (`0.0.99` → `0.0.100`, 자리올림 없음).
- 현재 진행: `0.0.66`. 평소 작업은 Z만 +1. (X·Y는 위 기준 달성 시 사용자와 함께 올림.)

## Git / push 관습
- **커밋은 자주, push는 사용자가 "올려줘"라고 할 때만.** (push하면 자동으로 웹 배포됨)
- 웹에 올리는 변경이면 push 전에 `scripts/game_state.gd`의 `const BUILD`를 올린다(시작/선택 화면에 "X.Y.Z ver." 표시. 평소엔 Z만 +1).
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
│  ├─ fonts/                # Pretendard-Regular.ttf (깔끔·중립 한글 폰트, 웹 검증·TTF)
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
- `Sfx` (`sfx.gd`) — 효과음(Kenney CC0 파일 + 절차적 합성). `Sfx.play(name,pitch,vol)` / `Sfx.impact(crit)`. 트럼펫·퍼벅 등.
- `Music` (`music.gd`) — BGM 화면별 자동전환(메뉴/전투/보스/프롤로그=무음). 보스 스테이지·음소거(`GameState.bgm_enabled`) 관리.

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
- `prologue.gd` — 프롤로그 컷씬(6장면, 임시 비주얼+슬픔→온기 음악, 반응형·건너뛰기).
- **배경 3레이어**: `stage_background.gd`(원경 far 그림 + 테마 랜덤풀/고정 선택 + 안개 데이터) / `ground_layer.gd`(지면 ground, 발선 자동정렬) / `foreground.gd`(근경 near 코너 식물, 바람 살랑). 풀/고정은 `stage_background`의 `POOL_COUNT`·`FIXED_GROUND`·`FIXED_FAR`.
- `halftone_bg.gd`(+`assets/shaders/halftone_bg.gdshader`) — AM 하프톤 배경 셰이더(도메인워프 흐름·스테이지 랜덤·폭풍 프리셋), ColorRect에 부착.

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
- 캐시: **안정 파일명**(index.js/wasm/pck 그대로 — SHA 리네임 폐기, v0.0.88). SHA 리네임은 연속 배포 시 "캐시된 옛 index.html이 사라진 옛 .pck를 찾는" 404를 유발해서 제거. 최신 반영은 GitHub Pages ETag 재검증(보통 새로고침, 안 되면 강력 새로고침). 배포 직후 버전은 시작화면 `BUILD` 표시로 확인.
- og-image·manifest.webmanifest도 CI가 복사.

## 기술 메모 (함정 주의)
- 엔진 **Godot 4.6.3**, GDScript. 렌더 `gl_compatibility`(모바일 호환).
- **폰트 = `Pretendard-Regular.ttf`** (깔끔·중립 산세리프). 출처: jsDelivr `npm/pretendard@1.3.9/dist/public/static/alternative/Pretendard-Regular.ttf`(표준 static은 OTF뿐 → TTF는 alternative 폴더).
- **웹 한글 깨짐 방지(원리)**: Godot은 **임베드된 폰트를 자체 래스터화**(브라우저 폰트 무관) → 프로젝트에 든 유효한 TTF를 직접 지정하면 어느 브라우저에서도 안 깨짐. 모든 텍스트에 **폰트 직접 지정**(라벨 `theme_override_fonts`, 코드 `draw_string`은 `preload(...Pretendard...)`, project.godot `gui/theme/custom_font`, `ThemeDB.fallback_font`). **OTF는 웹에서 깨진 사례 있어 → TTF만 사용.**
  - 폰트 교체 절차: 새 TTF를 `assets/fonts/`에 넣고 → `Godot --headless --import .` 로 `.import` 생성 → 기존 폰트 경로 문자열을 전 파일에서 새 파일명으로 일괄 치환(.tscn/.tres ext_resource는 path만 참조, uid 없음) → 씬 로드 검증.
  - 새 폰트 적용 후엔 **글리프 검사 필수**(`FontFile.has_char`): 폰트에 없는 글자(특수기호·이모지)는 □로 깨지니, 코드에서 쓰는 기호를 폰트에 든 것으로 교체. Pretendard는 `「」 · — … ♥ ▶ ★ × ◆` 포함 / `✦`·이모지 없음.
- **DEV 게이트**: `GameState.is_dev()`(현재 `const DEV := true`) — 출시 빌드에선 false로 dev 메뉴·🐞 오버레이·치트 전부 숨김.
- 좌표: 적·치즈는 발이 원점(`Layout.ground_y()`), 몸은 위(-y)로 그림. 공중 적은 시각 높이만 위로 올리고 충돌(관문)은 바닥선 유지.
- `Date.now()`/`randf` 등 시간·난수는 런타임에선 자유롭게 쓰되, 웨이브/적 정의 같은 데이터는 상수로.
