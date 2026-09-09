# MAW MMMerge 한국어화 작업

이 브랜치는 **MAW MMMerge 4.5** 안정판을 기준으로 한국어화를 진행한다.

- 업스트림: `Malekitsu/Maw-Mod-MMMerge`
- 기준 릴리스: `4.5 - last stable before big refactor`
- 기준 커밋: `342f34edf73dbd72808422cc56f4602959a94030`
- 작업 브랜치: `korean-localization-4.5`

`main`은 업스트림 최신 개발판 추적용으로 남겨 두며, 한국어 수정은 이 브랜치에서만 진행한다.

## 작업 원칙

1. **코드와 표시 문자열을 분리해서 취급한다.** 파일명, 리소스 키, 레지스트리 키, 내부 플래그, 맵 파일명 등은 번역하지 않는다.
2. `string.format`의 `%s`, `%d`, `%f` 등 자리표시자는 원문과 번역문에서 정확히 보존한다.
3. 기존 MMMerge 한국어판에서 이미 번역된 고유명사·주문·기술·아이템 용어는 가능한 한 재사용한다.
4. MAW가 새로 추가하거나 의미를 변경한 문자열은 별도 번역 대상으로 관리한다.
5. `Data/zMaw.T.lod`는 Lua와 분리해서 추출/재패킹한다. LOD 원본을 직접 손으로 수정하지 않는다.
6. 카탈로그의 `untranslated = 0`만으로 완료를 선언하지 않는다. 게임 내 QA와 파일별 발생 위치 추적을 병행한다.

## 자동 카탈로그

`tools/extract_maw_strings.py`가 다음 파일을 생성·갱신한다.

- `localization/catalog.tsv` — 중복 제거된 번역 카탈로그
- `localization/occurrences.tsv` — 각 문자열이 실제로 등장하는 파일/행 목록
- `localization/report.json` — 상태/분류/자리표시자 검증 요약

카탈로그의 주요 열:

| 열 | 의미 |
| --- | --- |
| `id` | 원문 기반 안정 ID |
| `status` | `untranslated`, `translated`, `needs_review`, `excluded`, `obsolete` |
| `category` | UI, 상태 메시지, 툴팁, 아이템, 주문, 기술 등 |
| `source` | 영어 원문 |
| `translation` | 한국어 번역 |
| `placeholders` | 반드시 보존해야 하는 printf 자리표시자 |
| `first_file`, `first_line` | 최초 발견 위치 |
| `occurrences` | 같은 원문의 전체 출현 횟수 |

추출기를 다시 실행해도 기존 번역과 `excluded` 판정은 유지된다. 업스트림에서 사라진 문자열도 즉시 삭제하지 않고 `obsolete`로 남겨 이후 버전에서 재사용할 수 있게 한다.

## 로컬 실행

```bash
python tools/extract_maw_strings.py --root .
python tools/extract_maw_strings.py --root . --check
```

`--check`는 번역된 문자열의 자리표시자가 원문과 달라졌을 때 실패한다.

## 번역 우선순위

1. `Scripts/General/MenuExtraSettings.lua` 및 설정 UI
2. `Scripts/Global/zzMAWStatusMsg.lua` 등 전투/상태 메시지
3. `Scripts/General/zzMaw-Items.lua`
4. `Scripts/General/zzMAW-Skills.lua`
5. `Scripts/General/zzClasses.lua`
6. `Scripts/General/zzMaw-Spells.lua`
7. `Scripts/General/zzMaw-Monsters.lua`
8. `Scripts/General/zzMaw-Stats.lua`
9. `Scripts/General/zzAlchemy.lua`
10. 맵/아레나/레전더리/기타 Lua
11. `zMaw.T.lod` 텍스트 리소스

## 배포 방향

최종 배포는 MAW 원본 전체를 다시 배포하는 방식보다 **한국어 오버레이**를 우선한다. 원본 MAW 4.5 설치 위에 한국어 변경 파일만 덮어쓰는 구조를 목표로 한다.
