# MAW MMMerge 한국어화 작업

이 브랜치는 **MAW MMMerge 4.5** 안정판을 기준으로 한국어화를 진행한다.

- 업스트림: `Malekitsu/Maw-Mod-MMMerge`
- 기준 릴리스: `4.5 - last stable before big refactor`
- 기준 커밋: `342f34edf73dbd72808422cc56f4602959a94030`
- 작업 브랜치: `korean-localization-4.5`

`main`은 업스트림 최신 개발판 추적용으로 남겨 두며, 한국어 수정은 이 브랜치에서만 진행한다.

## 설치 순서

현재 한국어 오버레이는 **기존 한국어 MMMerge를 먼저 설치한 뒤 MAW 4.5를 설치하고, 마지막에 이 저장소의 `korean/` 내용물을 덮어쓰는 방식**을 전제로 한다.

1. 한국어 MMMerge 기반 설치
2. MAW MMMerge 4.5 설치
3. 이 브랜치의 `korean/` 폴더 안 내용을 게임 루트에 마지막으로 복사

마지막 단계가 중요한 이유는 `korean/Data/zzzMawKO.T.lod`가 MAW 4.5의 테이블 수치와 구조를 유지하면서 한국어 표시 필드를 다시 적용하기 때문이다. 기본 한국어 LOD가 MAW 테이블을 덮어 수치·레시피를 이전 값으로 되돌리는 상황을 막기 위해 `zzzMawKO.T.lod`가 후순위로 로드되도록 이름을 정했다.

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

## 런타임 영어 잔존 검사

`tools/scan_runtime_english.py`는 카탈로그 번역률과 별도로 실제 실행되는 한국어 overlay의 Lua를 검사한다.

- 상태 메시지
- 질문/대화 메시지
- 이벤트 힌트
- UI Text/Tooltip/Title/Label
- 설명 및 표시명

현재 strict 검사에서 고신뢰 사용자 노출 영어 잔존은 0건이어야 Actions가 성공한다. 디버그 메시지, 내부 판정값, 안정적인 약어처럼 의도적으로 영어를 유지하는 값만 명시적으로 제외한다.

## zMaw.T.lod 한국어 오버레이

`Data/zMaw.T.lod`에는 Lua 카탈로그와 별개로 게임 표시와 밸런스에 직접 관여하는 9개 텍스트 테이블이 들어 있다.

- `ITEMS.txt`
- `MONSTERS.txt`
- `POTION.TXT`
- `POTNOTES.TXT`
- `Placemon.txt`
- `SPCITEMS.TXT`
- `class.txt`
- `mapstats.txt`
- `rnditems.txt`

`.github/workflows/zmaw-lod-audit.yml`은 `mmarch 7.0.0`을 고정 사용하여 MAW 4.5의 `zMaw.T.lod`를 추출하고, 한국어 표시 필드를 적용한 다음 `korean/Data/zzzMawKO.T.lod`를 다시 만든다.

현재 자동 이식하거나 번역하는 표시 필드:

| 파일 | 한국어화 필드 | 적용 수 |
| --- | --- | ---: |
| `ITEMS.txt` | Name, Not identified name, Notes | 6,583 |
| `MONSTERS.txt` | Name | 651 |
| `Placemon.txt` | Name | 161 |
| `mapstats.txt` | Name | 207 |
| `class.txt` | Class name, Class description | 106 |
| `SPCITEMS.TXT` | BonusStat, NameAdd | 146 |
| `POTION.TXT` | Name, Description, Effect | 366 |
| `POTNOTES.TXT` | Name, Description, Effect | 366 |
| `rnditems.txt` | 의도적 비번역: 확률/내부 키 + 문서용 라벨 | 0 |

현재 LOD에서 한국어화된 표시 필드는 **총 8,586개**다. 9개 내장 텍스트 테이블은 모두 번역 대상/비번역 대상으로 분류를 끝냈으며, 현재 `pending_schema_review`는 0개다.

`POTION.TXT`와 `POTNOTES.TXT`는 각각 122행을 별도로 검토한다. 두 파일은 같은 ID에서도 이름이나 설명이 다른 경우가 많으므로 서로 복사하지 않고 독립적으로 번역한다. `tools/export_zmaw_potion_display.py`가 두 테이블의 `Name / Description / Effect`를 감사용으로 추출하고, `tools/build_korean_zmaw_potions.py`가 해당 세 필드만 한국어화한다.

물약 테이블의 **4열 이후 레시피·조합·제어 행렬은 번역 대상에서 제외**한다. 빌더가 각 행에서 이 뒤쪽 필드가 수정 전과 동일한지 확인하며, 하나라도 달라지면 빌드가 실패한다. 따라서 MAW 4.5의 실제 물약 조합 규칙과 수치는 유지한다.

`rnditems.txt`는 `tools/audit_zmaw_rnditems.py`로 별도 검증한다. MAW 4.5 파일의 데이터 행 2,200개는 `숫자 아이템 ID / 리소스 ID / 보물 레벨 1~6 확률 / 사람용 영문 라벨` 구조이며, 실제 확률 데이터는 앞쪽 ID와 6개 수치 필드에 있다. 마지막 영문 아이템·주문명은 런타임 표시명이 아니라 테이블을 읽는 사람이 확인하기 위한 문서용 라벨이다. 따라서 해당 라벨을 한국어화할 이유가 없고, **`rnditems.txt` 전체를 MAW 4.5 원본 바이트 그대로 보존**한다. 새 audit는 행 구조와 6개 확률 필드를 검사하며, 스키마가 예상과 달라지면 Actions를 실패시킨다.

기존 `munument1/-KR-MMMerge`의 ID/행 기반 한국어 런타임 테이블은 일치가 확인된 표시 필드에만 사용한다. **그 외 MAW 4.5 수치·레시피·파일명·내부 키는 원본 값을 유지한다.**

빌드 후에는 생성한 `zzzMawKO.T.lod`를 다시 추출하여 9개 파일을 staging 결과와 바이트 단위로 비교한다. 이 round-trip 검사가 통과해야 Actions가 성공한다.

### mapstats 저장 호환성

MAW 4.5는 원래 `Game.MapStats[i].Name`을 던전 완료 상태 저장 키로 사용한다. 맵 표시명을 한국어로 바꾸면 기존 세이브의 영문 키와 달라질 수 있으므로 `tools/apply_mapstats_key_compat.py`가 MAW overlay를 보정한다.

- 새 저장 키: `Game.MapStats[i].FileName`
- 기존 영문 맵 이름 키 자동 이전
- 이미 한국어 이름으로 저장된 키도 자동 이전

따라서 맵 화면 표시명은 한국어로 유지하면서 내부 진행 상태는 언어에 독립적인 파일명 키를 사용한다.

## 로컬 실행

```bash
python tools/extract_maw_strings.py --root .
python tools/extract_maw_strings.py --root . --check
```

`--check`는 번역된 문자열의 자리표시자가 원문과 달라졌을 때 실패한다.

LOD 재생성은 GitHub Actions의 `zMaw.T.lod Korean audit` 워크플로가 담당한다.

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

최종 배포는 MAW 원본 전체를 다시 배포하는 방식보다 **한국어 오버레이**를 우선한다. 원본 MAW 4.5 설치 위에 한국어 변경 파일만 마지막에 덮어쓰며, `zzzMawKO.T.lod`가 MAW 테이블 데이터와 한국어 표시를 함께 최종 확정한다.

현재 자동 검사 통과는 번역 파이프라인의 무결성을 뜻할 뿐, 게임 전체 한국어화 완료를 의미하지 않는다. 실제 게임에서의 메뉴·전투·아이템·맵·저장 호환성 QA를 별도로 계속 진행한다.
