# Dock UI 스타일 가이드

이 문서는 Godot .NET MCP의 모든 Dock 페이지에 적용되는 공통 visual / interaction contract입니다. 새 페이지와 기존 페이지의 중요한 변경은 editor limitation을 기록하고 focused test로 보호하는 경우를 제외하면 이 규칙을 따라야 합니다.

## 기본 원칙

- Godot native를 유지하고 editor theme, controls, icons, focus behavior, scale을 상속합니다.
- 조용한 interface를 만들고 current task와 primary action을 metadata나 diagnostics보다 먼저 보여 줍니다.
- progressive disclosure를 사용해 필수 state는 항상 표시하고 audit 및 technical details는 필요할 때 펼칩니다.
- 표현을 단순화해도 capability를 없애지 않으며, 이동한 secondary information의 action과 evidence는 계속 접근할 수 있어야 합니다.
- current, warning, error, selected, disabled state를 색상만으로 표현하지 않습니다.

## 페이지 계층

구조는 최대 세 단계로 제한합니다.

| 계층 | 목적 | 규칙 |
|---|---|---|
| 페이지 | 하나의 Dock tab | 페이지 수준 `ScrollContainer`는 최대 하나만 사용합니다. 전용 `Tree` 또는 preview pane은 독립적으로 scroll할 수 있으며 페이지 전체 가로 scroll은 금지합니다. |
| 카드 | 하나의 feature area | title 하나, 상시 description 최대 하나, status region 하나를 둡니다. |
| 그룹 | 관련 fields / actions | labels, controls, feedback을 가까이 두고 일정한 spacing을 사용합니다. |

visual order와 keyboard focus order는 같아야 합니다. 자주 쓰는 path를 먼저 두고 고정 repository facts, hashes, timestamps, audit trail은 secondary details로 이동합니다.

list, table, preview, editor의 scope를 정하는 selector는 해당 surface 바로 앞에 둡니다. selector와 대상 content 사이에 관련 없는 status, metadata, action을 넣지 않습니다.

## 간격과 레이아웃 단위

모든 값은 current editor scale을 곱하는 logical pixels입니다.

| 단위 | 용도 |
|---|---|
| `4` | 밀접한 icon, badge, helper content |
| `8` | 한 그룹 안의 controls와 buttons |
| `10` | card 또는 inset status panel 안의 rhythm |
| `12` | page margin, card 세로 padding, major group separation |
| `14` | card 가로 padding |
| `16` | wide layout의 큰 region 사이에서만 사용 |

일반 margin과 container separation은 `.tscn` scene에 둡니다. script는 scale 또는 breakpoint 때문에 값을 바꿀 수 있지만 runtime reason 없이 정적 spacing을 중복 지정하지 않습니다.

## 테마, 텍스트, 아이콘

- editor의 `PanelContainer`, `Tree`, `LineEdit`, `TextEdit` 등 style box를 복제해 조정하고 별도 palette를 만들지 않습니다.
- accent, separator, error, font, disabled font colors는 `Editor` theme에서 읽습니다.
- 익숙한 editor action에는 `EditorIcons`를 사용합니다. icon-only action에는 tooltip과 이해 가능한 action name이 필요합니다.
- primary content는 일반 Label color를 사용합니다. description, hint, metadata는 단계적으로 약하게 표현하되 light / dark theme 모두에서 읽을 수 있어야 합니다.
- 모든 페이지에 공통 semantic variation을 도입하지 않는 한 section title은 editor default size를 사용합니다.

## 폼과 컨트롤 너비

- regular width에서는 label / field를 2열 `GridContainer`로 배치합니다.
- label의 regular minimum은 약 `112` logical pixels이며 field는 expand하고 가장 긴 localized item에 너비를 의존하지 않습니다.
- ultra-narrow에서는 1열로 전환하고 고정 field width를 해제하며 각 label을 control 바로 앞에 둡니다.
- 긴 path, ref, ID를 생략할 때는 tooltip 또는 details에서 전체 값을 볼 수 있어야 합니다.
- disabled control만으로 이유를 설명하지 말고 가까운 status text 또는 localized tooltip에 이유를 표시합니다.

## 상태, 도움말, 세부 정보

- 한 card에는 상시 description 최대 하나와 live status region 하나만 둡니다. controls, status, empty state만으로 workflow가 설명되면 description을 생략하고 같은 guidance를 반복하지 않습니다.
- idle guidance는 next action을 알려야 합니다. loading은 active scope를 표시하고 충돌 action을 잠그며 측정 가능하면 progress를 보여 줍니다.
- success text는 짧게 유지합니다. error text는 원인과 알려진 경우 recovery action을 보존합니다.
- trigger source, HTTP status, rate-limit reset, hash, comparison count는 collapsible details에 둡니다.
- persistent status region은 primary result를 담당합니다. details는 supplemental이어야 하며 같은 error나 summary를 반복하지 않고 actionable diagnostic evidence를 추가할 때만 자동으로 펼칩니다.
- error 또는 rate limit exhausted 상태에서 details가 해당 evidence를 추가하면 자동으로 펼칠 수 있지만 일반 audit은 접힌 상태로 둡니다.

## 목록, 테이블, 빈 상태

- item을 선택하거나 판단하는 데 필요한 열만 보여 주고 narrow layout의 secondary date / identifier는 tooltip 또는 details로 이동합니다.
- current row는 색상 외에도 text marker 또는 icon이 있어야 하며 같은 item을 다시 선택하는 action을 표시하지 않습니다.
- row selection이 target을 정할 때는 row 전체를 highlight합니다. selection은 비파괴 target만 업데이트하고 mutation, navigation, switch는 별도 row action으로 수행합니다.
- row action은 tertiary입니다. editor icon이 있어도 localized label 또는 tooltip을 제공합니다.
- 빈 `Tree`는 숨기고 not loaded, loading, no results, error를 구분하는 간단한 empty state를 표시합니다.
- model refresh 동안 selection, scroll position, deferred row action을 안정적으로 유지합니다.

## 액션 의미

| 우선순위 | 대표 용도 | 배치 |
|---|---|---|
| Primary | start, apply, one-click update | card마다 하나, visual / focus order의 마지막 |
| Secondary | refresh, copy, retry, open details | 영향을 받는 scope 가까이 |
| Tertiary | row switch, compact utility | 해당 row 또는 context menu |
| Destructive | remove, clear, delete | 일반 action과 분리하고 손실 가능성이 있으면 확인 |

hover-only control은 이미 찾을 수 있는 action의 shortcut으로 사용할 수 있지만 중요한 작업의 유일한 진입점이 되어서는 안 됩니다.

cached state 복원과 passive selection 변경은 side effect free여야 합니다. network access와 mutation은 명시적인 user action이 필요하며 repeated retry는 알려진 cooldown / rate-limit state를 따라야 합니다.

## Dock 반응형 동작

| content width | 예상 layout |
|---|---|
| `>= 560` | 2열 form, compact summary row, 나란한 action buttons |
| `360-559` | 읽을 수 있는 범위의 2열 form, 줄어든 metadata, compact table |
| `< 360` | 1열 form / actions, 고정 field width 없음, 낮은 table height |

container와 size flags를 사용해 Dock minimum width에서도 사용할 수 있어야 합니다. 고정 column total이 available width를 넘지 않게 합니다. editor scale `1`, `1.5`, `2`와 short / tall Dock을 검증합니다.

## 접근성

- 모든 중요한 action에 keyboard focus를 유지하고 focus order를 visual order와 맞춥니다.
- semantic state는 색상과 text, icon, shape, position 중 하나를 함께 사용합니다.
- icon-only control에는 tooltip과 의미 있는 accessible text를 제공합니다.
- 페이지 이해와 조작에 hover, animation, pointer coordinate가 필수가 되지 않게 합니다.
- target size와 contrast는 Godot editor theme와 일치시킵니다.

## 현지화

- visible label, tooltip, empty state, loading state, error message는 모두 plugin locale files로 localized 처리합니다.
- translated sentence를 fragment로 조합하지 말고 명시적 placeholder가 있는 complete message를 사용합니다.
- prose에는 smart word wrap을 사용하고 German / Russian expansion과 Chinese / Japanese / Korean layout을 검증합니다.
- button의 action verb를 유지하고 action을 자르기 전에 supporting copy를 줄입니다.

## 씬과 스크립트 책임

- `.tscn` scene은 semantic control names, 일반 containers, base margins, separation, initial visibility를 담당합니다.
- tab script는 model rendering, signals, editor scale, breakpoints, dynamic rows, tooltips, editor 기반 theme values를 담당합니다.
- model projection service는 state normalization과 presentation-ready facts를 담당하며 view script는 translated text matching으로 behavior를 추론하지 않습니다.
- Dock root code는 cross-tab coordination만 담당하고 page-specific layout은 page scene / controller에 둡니다.

## 승인 매트릭스

중요한 UI 변경은 automated contract 또는 editor evidence에서 다음 항목을 확인합니다.

| 항목 | 최소 사례 |
|---|---|
| Width | `280`, `360`, `560`, wide layout |
| Scale | scale-sensitive geometry 변경 시 `1`, `1.5`, `2` |
| Language | English, 긴 Latin/Cyrillic locale, CJK locale |
| State | idle, loading, success, error, rate limited, empty |
| Theme / input | light / dark compatible values와 keyboard focus |

겹침 없음, 페이지 전체 가로 scroll 없음, 색상만 사용하는 state 없음, action localization 완비, 변경 대상 surface가 기존에 노출하던 모든 feature에 계속 접근 가능함을 승인 조건으로 합니다.
