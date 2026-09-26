# SKEAM

SKEAM(KING 동아리의 게임 상점, https://kh32-7.github.io/skeam/)에 웹판을 올린다. 상점에 올릴 파일은 `store/`에 있다.

## 어떻게 도나

- `export_presets.cfg` 의 웹 설정 `html/head_include` 가 index.html 머리에 SKEAM SDK(`skeam-sdk.js`)를 넣는다.
- 과제를 이루는 순간 `Skeam.unlock(id)` 을 부른다 (`scripts/skeam.gd`).
  - 연습 창구에서 한 일은 세지 않는다 (연습 완주 `tut_done` 만 예외).
  - SKEAM 밖(Pages 주소로 바로 할 때 · 편집기)에서는 아무 일도 하지 않는다.
  - 같은 과제를 또 알려도 SKEAM 은 한 번만 센다. 등록하지 않은 id 는 SKEAM 이 무시한다.
- 이야기 민원의 결과 플래그로 이루는 과제는 `Skeam.FLAGS` 에 적는다.
- 과제를 더하려면 부를 곳에 `Skeam.unlock` 한 줄, `store/game.yml` 에 한 줄을 넣고 SKEAM 에 다시 등록한다. id 는 둘이 같아야 한다.

## 상점 파일 (`store/`)

| 파일 | 크기 | 내용 |
|---|---|---|
| `game.yml` | | 제목, 가격, 소개, 도전 과제 14개 |
| `skeam-등록양식.json` | | 등록 폼의 [빠르게 채우기 → 양식 붙여넣기]에 넣는 JSON |
| `about.md` | | 상점 본문 |
| `header.jpg` | 920×430 | |
| `capsule.jpg` | 600×900 | |
| `hero.jpg` | 1920×620 | |
| `screenshots/1~5.jpg` | 1280×720 | |

그림은 `python tools/store_art.py <스크린샷 폴더>` 로 다시 만든다 (스크린샷은 `tools/shot.gd`).
등록은 사이트의 게임 등록 폼으로 한다 (게임 id `counter-no-3`). 올라간 뒤 SKEAM 저장소의 `games/counter-no-3/game.yml` 에 `store/game.yml` 의 `achievements:` 를 넣는 PR을 보낸다.

## 확인

- 시험: `godot --headless --path . res://tools/playtest.tscn` (도전 과제가 알맞게 나가는지, 연습 중엔 안 나가는지)
- 배포한 뒤: Pages 주소의 페이지 소스에 `skeam-sdk.js` 줄이 있는지 본다.
