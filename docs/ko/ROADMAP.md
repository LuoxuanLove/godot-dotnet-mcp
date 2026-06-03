# 로드맵

이 로드맵은 Godot .NET MCP의 제품 방향을 설명합니다. 계획 문서일 뿐 릴리스 약속이나 issue 수준 설계를 대체하지 않습니다. 구현 제약, 테스트 결과, 사용자 피드백이 더 명확해지면 버전 범위는 바뀔 수 있습니다.

## 제품 포지셔닝

Godot .NET MCP는 Godot 4.6 이상 .NET 프로젝트를 위한 에디터 네이티브 MCP 플러그인입니다. 1.x에서의 정체성은 다음과 같습니다.

- MCP 서비스를 Godot 에디터 안에서 직접 실행한다.
- 실시간 에디터, 프로젝트, 씬, 런타임, 진단, 스크린샷, C# 구조, 리소스, 도구 확장 컨텍스트를 제공한다.
- Agent에게 저수준 atomic tool을 과도하게 노출하는 대신 고수준 `system_*` 워크플로를 공개한다.
- 설정을 직접적으로 유지하고, 핵심 플러그인 경험에 별도 상시 백그라운드 서버를 요구하지 않는다.
- Agent의 작업을 파일 편집뿐 아니라 진단, 런타임 증거, 에디터 상태로 검증 가능하게 한다.

이 프로젝트는 단순한 도구 수로 경쟁해서는 안 됩니다. 의미 품질, 설정 상태를 이해하는 안내, C#/.NET 프로젝트 이해, 에디터 상태 정확도, 런타임 검증, 안정적인 공개 MCP surface로 경쟁해야 합니다.

## v1.x 개발 방향

1.x 라인은 에디터 네이티브 플러그인 아키텍처를 계속 다듬으면서 Godot .NET MCP를 Agent 중심의 증거 우선 워크플로 플랫폼으로 만들어야 합니다. 우선순위는 Agent가 올바른 기능을 찾고, 집중된 변경을 만들고, Godot을 통해 검증하며, 신뢰할 수 있는 증거를 보고하도록 돕는 것입니다.

### 기능 발견과 도구 거버넌스

- `system_help`와 도구 카탈로그 리소스를 강화하여 Agent가 큰 평면 목록에서 추측하지 않고 작업에 맞춰 도구를 고를 수 있게 한다.
- core, runtime, DAP, editor UI, visual, plugin, user-extension 기능을 포함해 도구 그룹과 profile을 더 명확히 한다.
- 프로젝트 미실행, runtime control 사용 불가, DAP endpoint 사용 불가, 에디터 전면 필요, 사용자 도구 없음 같은 setup-gated 상태를 드러낸다.
- 고수준 `system_*` entry를 공개 워크플로 계층으로 유지하고, 저수준 executor는 내부 구현 세부 사항으로 보존한다.
- 공개 도구 이름, 매개변수, 반환 필드, protocol facts를 1.x 워크플로의 안정 API surface로 취급한다.

### 폐루프 런타임 검증

- 기존 project run, runtime control, runtime step, screenshot, editor log, runtime diagnosis 도구를 더 명확한 검증 워크플로로 만든다.
- 무엇을 실행했는지, 어떤 marker가 일치했는지, 어떤 스크린샷이나 런타임 상태를 캡처했는지, 오류가 있었는지, 정리가 되었는지를 설명하는 증거 지향 보고를 지원한다.
- 성공적인 시작을 성공적인 동작 검증으로 취급하지 않는다. 런타임 검증은 시작, 상호작용, 진단, 증명을 구분해야 한다.
- marker validation, runtime event 처리, screenshot 가용성, stop/cleanup 동작, 오류 보고의 contract와 harness coverage를 확장한다.

### C#과 Godot 바인딩 깊이

- Godot .NET 프로젝트 구조, export 멤버, partial class, signal, NodePath 사용, resource, PackedScene, 생성된 프로젝트 메타데이터에 대한 Roslyn 기반 검사를 심화한다.
- C# diagnostics, Godot 씬/리소스 참조, 에디터에서 보이는 바인딩, 런타임 오류 사이의 연결을 개선한다.
- managed C# 디버깅 경계를 명확히 한다. Godot DAP 도구는 Godot debugger 워크플로를 지원할 수 있지만, managed C# breakpoint에는 별도 .NET debugger가 필요할 수 있다.
- 넓지만 얕은 코드 분석 주장보다 실용적인 바인딩, 리소스, 빌드 진단 워크플로를 우선한다.

### 프로젝트 기능 팩으로서의 사용자 확장

- `custom_tools/` scaffolding, 호환성 검사, hot-load 안전성, audit 출력, 복구 안내를 개선한다.
- Agent가 플러그인 소스 코드를 수정하지 않고 프로젝트별 `user_*` 도구를 만들도록 돕는다.
- 사용자 도구의 기대 schema, 반환 구조, dry-run 패턴, 검증 기대, 실패 격리 규칙을 문서화한다.
- Tools 페이지와 prompt guidance에서 사용자 확장을 일급 기능으로 보여 주되 내장 도구와 명확히 분리한다.

### 시연 가능한 워크플로

1.x 라인은 플러그인이 실제 Godot .NET 문제를 처음부터 끝까지 해결하는 재현 가능한 예시를 포함해야 합니다.

- C# export 또는 NodePath 바인딩 문제를 발견하고, 수정하고, 다시 검증한다.
- 깨진 씬/리소스 참조를 진단하고 복구한다.
- 로그, 진단, 스크린샷, 집중된 수정을 통해 런타임 실패를 추적한다.
- 사용자 확장을 scaffold, load, audit하고 안전하게 사용한다.

이 예시는 마케팅 폭보다 반복 가능성과 증거를 강조해야 합니다.

### 안정성과 공개 schema 규율

- 이미 확립된 `system_*` 도구 정체성을 보존하고 불필요한 breaking change를 피한다.
- 가능한 경우 필드를 제거하거나 이름을 바꾸기보다 추가한다.
- protocol facts, tool schemas, resources, prompts, localized descriptions, docs, changelogs, tests를 동기화한다.
- 공개 동작이 바뀌어야 할 때는 명확한 migration notes를 유지한다.

### 에디터 UX와 Agent UX

- Dock을 service health, current context, tool discoverability, configuration, update status, actionable diagnostics에 집중시킨다.
- 에디터 UI 작업을 위한 screenshot-backed UI verification 경로를 개선한다.
- 지원 MCP client의 설정 마찰을 계속 줄이면서 현재 installation/configuration state를 보이게 한다.
- 사용자에게 보이는 플러그인 surface와 tool descriptions의 현지화를 완전하게 유지한다.

### 진단과 증거 품질

- 대규모 프로젝트에서 전체 파일 열거를 강제하지 않고 project-state summaries를 개선한다.
- scene dependency, resource reference, binding audit, runtime log, performance snapshots를 읽기 쉬운 evidence summaries로 확장한다.
- 실패 보고를 구체적으로 유지한다. 무엇이 실패했는지, 현재 session이 왜 action을 수행할 수 없는지, 어떤 setup step이 차단을 해제하는지 설명한다.

### 테스트와 릴리스 신뢰성

- headless harness, editor probe, contract, localization, release validation coverage를 계속 확장한다.
- Asset Library install validation을 내보낸 플러그인 내용과 맞춘다.
- release notes와 changelogs가 구현 로그가 아니라 사용자에게 보이는 기능과 중요한 내부 검증 변경을 설명하게 한다.

## v2.0 개발 방향

v2.0은 1.x 에디터 네이티브 플러그인 경계를 넘어서는 아키텍처 확장을 탐색하기에 적절한 시점입니다. 주요 탐색 영역은 선택적 외부 또는 headless companion mode입니다.

### 선택적 외부 또는 Headless Companion

v2.0 companion은 에디터 네이티브 플러그인이 잘 다루기 어려운 실제 워크플로를 해결할 때만 고려해야 합니다. 가능한 목표는 다음과 같습니다.

- 에디터 UI를 열지 않고 `.tscn`, `.tres`, `.csproj`, solution files, C# sources를 검사한다.
- 로컬 자동화 또는 CI 스타일 환경에서 build, restore, static audit, resource reference, binding checks를 실행한다.
- 에디터 live context가 필요하지 않을 때 제어된 headless 또는 runtime validation mode로 Godot을 시작한다.
- 원격 또는 자동화 Agent session을 위한 더 낮은 마찰 경로를 제공한다.
- 에디터 플러그인 session이 있을 때 live editor context로 업그레이드한다.

이 companion은 핵심 플러그인 경험을 약화해서는 안 됩니다. 에디터 플러그인은 live editor state, selected nodes, Dock state, editor screenshots, editor logs, editor UI control의 authoritative source로 남아야 합니다.

### v2.0 아키텍처 원칙

- 1.x 에디터 네이티브 플러그인을 안정 모드로 유지하고 폐기 예정 징검다리로 만들지 않는다.
- companion은 선택적이고 명시적이며 capability-gated여야 한다. 숨은 필수 백그라운드 프로세스가 되어서는 안 된다.
- editor-live capabilities와 headless/static capabilities 사이에 엄격한 protocol boundary를 정의한다.
- 결과 형태와 제한이 명확히 문서화되지 않는 한 모드 간 tool semantics를 중복하지 않는다.
- write operations를 가능한 범위에서 previewable, auditable, reversible하게 만들어 사용자 신뢰를 보존한다.

### 더 깊은 .NET 런타임과 디버깅 이야기

Godot과 .NET debugging/tooling 경계가 실용적이라면 v2.0은 더 깊은 .NET-oriented workflows도 탐색할 수 있습니다.

- managed exception을 C# source, scenes, resources와 더 강하게 연결한다.
- 더 풍부한 MSBuild와 SDK compatibility diagnostics를 제공한다.
- Godot DAP debugging과 managed .NET debugging responsibilities를 더 명확히 분리한다.
- runtime failures를 project files, scene bindings, exported members에 더 정확히 mapping한다.

## 비목표

- 더 큰 raw tool count를 성공 지표로 좇지 않는다.
- 임의 로컬 코드 실행을 기본 사용자-facing 기능으로 노출하지 않는다.
- 전용 .NET IDE debugger를 모호한 debugging claims로 대체하지 않는다.
- external companion을 1.x 에디터 네이티브 workflow의 필수 조건으로 만들지 않는다.
- project-specific business tools를 플러그인 저장소에 내장하지 않는다. 프로젝트별 기능은 user extensions에 속한다.
- 이 roadmap을 약속된 release schedule로 취급하지 않는다.