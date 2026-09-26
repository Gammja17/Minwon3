# 민원실 3번 창구

햇살동 주민센터 신규 9급 주무관의 첫 2주(10/12~10/23). 1주차 금요일 감사, 2주차 금요일 인사 평가. Godot 4.7.

## 실행
Godot 에디터로 이 폴더를 열고 F5.

## 구조
- `scripts/content.gd`: 규정, 부서, 팀장 메모, 이야기 민원, 무작위 민원 생성기, 판정
- `scripts/game.gd` (오토로드 `Game`): 평판·벌점·스트레스·플래그, 대기열, 엔딩
- `scripts/office.gd` + `scenes/office.tscn`: 창구 화면
- `scripts/portrait.gd`: 민원인 얼굴·신분증 사진 그리기
- `scripts/doc_view.gd`: 서류·전산 기록 카드

## 검사
```
godot --headless --path . --script res://tools/sim.gd        # 10일치 무작위 민원 × 규정 대조, 이야기 민원 × 플래그 조합
godot --headless --path . res://tools/playtest.tscn          # 2주 자동 진행 (규정대로 한 번, 1주차를 망친 뒤 한 번)
godot --path . res://tools/shot.tscn -- <폴더>               # 주요 화면 스크린샷
```
