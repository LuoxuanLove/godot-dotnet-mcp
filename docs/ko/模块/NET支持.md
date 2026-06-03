# .NET 지원

## 범위

현재 `.NET` 지원은 C# 코드 생성이나 완전한 semantic compilation이 아니라, 에디터 내부 정적 분석과 scene binding 검사에 집중합니다.

현재 지원하는 항목은 다음과 같습니다.

- `.cs` 파일 텍스트 읽기
- script editor에서 `.cs` 파일 열기
- `namespace` 인식
- `class` 인식
- `partial class` 인식
- base type 인식
- public method 인식
- enum 인식
- `[Export]` field와 property 인식
- `[ExportGroup]` 인식
- scene 분석 중 exported member binding state 읽기

## 사용하는 방법

### C# script 구조 보기

권장 호출은 다음과 같습니다.

1. `system_script_analyze`
2. `system_bindings_audit`

더 깊게 보려면 다음을 추가합니다.

- `script_inspect`
- `script_symbols`
- `script_exports`

대표적인 경우는 다음과 같습니다.

- `partial class`가 기대한 base type을 아직 쓰고 있는지 확인
- `namespace`, `class`, `method`, `[Export]`가 제대로 인식되는지 확인
- Inspector의 field 이름을 script의 exported member와 연결

### scene binding 확인

권장 호출은 다음과 같습니다.

1. `system_bindings_audit`
2. `system_scene_analyze`

더 깊게 보려면 다음을 추가합니다.

- `scene_bindings`
- `scene_audit`

대표적인 경우는 다음과 같습니다.

- scene node의 `[Export] NodePath`, resource reference, value field가 반영되지 않음
- node script는 맞아 보이는데 Inspector에서 field가 비어 있음
- Godot scene 문제를 concrete C# export declaration까지 추적하고 싶음

### 수동 editor 수리로 돌아가기

권장 호출은 다음과 같습니다.

1. `system_script_analyze`
2. `script_open.open`
3. `script_open.open_at_line`

이 흐름은 다음에 적합합니다.

- 구조화된 분석에서 실제 script로 돌아가기
- MCP가 위치를 찾아 주고, 최종 수정은 사람이 직접 하기

## 일반적인 활용

- scene에서 C# export reference가 비어 있는지 확인
- script가 scene에 노출하는 public structure를 확인
- 자동 검사용 exported field를 빠르게 추출
- script 선언과 실제 scene binding 결과를 비교

## 구현 메모

### 왜 full semantic analysis가 아니라 syntax-first인가

구현 목표는 Godot editor process 안에서 유용한 구조를 안정적으로 돌려주는 것이므로, plugin은 외부 compile step이나 별도 background host 없이 Godot .NET runtime 내부의 syntax-first Roslyn 경로를 사용합니다. 이유는 다음과 같습니다.

- 플러그인은 editor 안에서 직접 동작해야 하며 external compile step이나 별도 background host에 의존하면 안 됩니다.
- 목표는 exported field, class 정보, scene binding이지 완전한 language service가 아닙니다.
- response speed와 portability가 완전한 semantic coverage보다 중요합니다.

### 현재 pipeline

1. `addons/godot_dotnet_mcp/dotnet_bridge/`와 `plugin/runtime/roslyn/*`가 plugin-local Roslyn syntax-analysis core를 제공합니다.
2. `tools/script/csharp_edit_service.gd`, `tools/script/inspect_service.gd`, 그리고 system script entry point가 `.cs` file text를 읽고 Roslyn facade에 연결합니다.
3. Roslyn 경로는 `namespace`, `class`, `partial class`, `base_type`, `method`, `enum`, `[Export]`, `[ExportGroup]`, parse error를 추출합니다.
4. `tools/scene_tools.gd`가 scene에서 script instance와 exported value를 읽습니다. 고수준 브리지는 `tools/system/impl_scene.gd`와 `tools/system/impl_script.gd`에 있습니다.
5. `scene_bindings`와 `scene_audit`가 declaration state와 실제 binding state를 연결합니다.

### 가장 잘 맞는 경우

이 구현이 가장 잘 맞는 경우는 다음과 같습니다.

- 표준 Godot Mono 및 .NET gameplay script
- export-field auditing
- scene binding 문제 해결
- script surface information의 구조화된 검사

이 구현이 잘 맞지 않는 경우는 다음과 같습니다.

- 파일 간 상속 체인 추론
- generic constraint와 복잡한 property accessor semantics
- conditional compilation branch 아래의 완전한 member parsing
- 큰 C# 파일의 자동 rewrite

## 비목표

현재 비목표는 다음과 같습니다.

- Roslyn 수준의 semantic analysis
- cross-assembly symbol resolution
- 임의의 C# AST rewriting
- 범용 C# code-generation workflow

## GDScript와의 관계

GDScript도 여전히 필요한 지원을 유지합니다.

- read
- open
- export와 symbol analysis
- 제한적인 editing

다만 플러그인 인터페이스의 중심은 더 이상 GDScript가 아닙니다. Godot 프로젝트가 공통으로 쓰는 general script workflow를 중심으로 합니다.

## 문제 해결 팁

- `script_exports`에 `[Export]` field가 보이지 않으면 먼저 property 또는 field syntax가 지원 범위 안에 있는지 확인합니다.
- `scene_bindings`가 script는 보지만 exported value를 읽지 못하면, 먼저 사용자의 binding보다 scene instance binding이나 export extraction logic을 의심합니다.
- 큰 규모의 C# rewrite가 필요하면 현재 tool set은 적합하지 않습니다. 대신 전용 external code modification flow로 전환합니다.
