# 크레딧

## 글꼴 (`assets/fonts/`)
| 파일 | 출처 | 라이선스 |
|---|---|---|
| `Mulmaru.woff2` | 물마루 by Mushsooni — https://github.com/mushsooni/mulmaru | SIL OFL 1.1 (`Mulmaru-LICENSE.txt`) |
| `Pretendard-Regular.woff2`, `Pretendard-SemiBold.woff2` | Pretendard by Kil Hyung-jin — https://github.com/orioncactus/pretendard | SIL OFL 1.1 (`Pretendard-LICENSE.txt`) |

## 효과음 (`assets/sfx/`)
| 파일 | 원본 | 라이선스 |
|---|---|---|
| `phone.ogg`, `warn.ogg` | "Interface Sounds" by Kenney — `question_002`, `error_004` | CC0 — https://kenney.nl/assets/interface-sounds |
| `stamp1~2.ogg`, `glass1~2.ogg`, `bell.ogg` | "Impact Sounds" by Kenney — `impactWood_heavy`, `impactGlass`, `impactBell_heavy` | CC0 — https://kenney.nl/assets/impact-sounds |
| `step*.ogg`, `heel*.ogg`, `book_*.ogg` | "RPG Audio", "Impact Sounds" by Kenney | CC0 |
| `click*.ogg`, `pop.ogg`, `notify.ogg`, `hint.ogg`, `ff_*.ogg`, `tick.ogg`, `alarm.ogg`, `bottle.ogg`, `chat.ogg` | "Interface Sounds" by Kenney | CC0 |
| `dingdong.ogg` | "Airplane, Seatbelt Sign Beep" by Kinoton (Freesound 670297) | CC0 — https://freesound.org/people/Kinoton/sounds/670297/ |
| `ticket.mp3` | "Thermal Receipt Print & Cut" by twisterad3 (Freesound 413838) | CC0 — https://freesound.org/people/twisterad3/sounds/413838/ |
| `paper1~3.ogg`, `cloth1~2.ogg`, `coin.ogg` | "RPG Audio" by Kenney — `bookFlip1~3`, `cloth1~2`, `handleCoins` | CC0 — https://kenney.nl/assets/rpg-audio |

## 배경 음악 (`assets/music/`)

| 파일 | 원작 | 라이선스 |
|---|---|---|
| `bgm.ogg` | "Chill lofi inspired" by omfgdude, loop edit by qubodup (OpenGameArt) | CC0: https://opengameart.org/content/chill-lofi-inspired-loop-edit |

## 초상화 (`assets/portraits/`)
이야기 인물 33명(연습 창구의 최 팀장 포함), 수배 회람 속 인물 3명과 무작위 민원인 48명(`cit01~48`)의 초상화는 이 게임을 위해 VARCO(gpt-image-2.5)로 생성했다. 2×2 표정 시트를 `tools/cut_portraits.py`로 잘라 쓴다.

## 책상 소품 (`assets/ui/`)
벽, 책상, 창구 틀, 모니터 틀, 처리·반려 도장, 도장 받침, 규정집, 비상벨, 전화, 돋보기, 명패, 휴지통, 메모지, 드링크, 첫 화면 일러스트, 밤의 원룸, 저녁 카드 그림 4장까지 21장은 이 게임을 위해 VARCO(gpt-image-2.5)로 생성했다. 원본은 `assets/ui/src/`에 있고, 화면 크기에 맞게 줄인 사본을 쓴다.
책상 위 물건(`desk_*.png`: 초코바, 캔커피, 비타민 음료와 빈 껍데기, 전단지, 번호표, 서류 뭉치) 9장도 VARCO로 생성해 `tools/cut_props.py`로 잘랐다.
