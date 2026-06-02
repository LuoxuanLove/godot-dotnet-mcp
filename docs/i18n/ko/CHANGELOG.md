# 변경 로그

이 파일은 Godot .NET MCP의 한국어 변경 로그 진입점입니다. 전체 정식 변경 기록은 [영어 CHANGELOG](../../../CHANGELOG.md)에 기록됩니다.

<p align="center"><a href="../../../CHANGELOG.md">English</a> | <a href="CHANGELOG.md">한국어</a> | <a href="../ja/CHANGELOG.md">日本語</a> | <a href="../zh-CN/CHANGELOG.md">简体中文</a></p>

## 미출시 (1.2.0)

대상 버전: 1.2.0.

### Documentation

- `v1.2.0` 릴리스 노트 소스를 pending-theme 템플릿으로 초기화하고, 플러그인 메타데이터를 갱신한 뒤 오래된 `v1.1.2` 소스를 제거했습니다.
- README, CHANGELOG, ROADMAP의 다국어 진입점을 정리하고 한국어, 일본어, 간체 중국어 문서를 `docs/i18n/` 아래에 배치했습니다.

### Internal

- 플러그인 메타데이터, protocol facts, .NET bridge 메타데이터, 플러그인 업데이트 계약 fixture 기대값을 `1.2.0` 개발 라인으로 전환했습니다.

## 1.1.2 - 2026-06-02

### Changed

- 내장 MCP Prompt Guides를 `godot.project_orientation`, `godot.content_authoring`, `godot.debug_triage`, `godot.reference_integrity`, `godot.runtime_validation`, `godot.editor_ui_control`의 여섯 워크플로 중심진입점로 재구성했습니다.
- 디버거 안내를 `godot.debug_triage`에 통합하여 prompt 발견 결과가 별도 디버거 전용 가이드가 아니라 하나의 실패 진단 워크플로로 보이게 했습니다.

### Fixed

- 재구성된 MCP Prompt Guides를 `system_help`를 통해 노출하여 Agent가 주요 기능 안내에서 `prompts/list`, `prompts/get`, 여섯 개의 내장 prompt ID를 발견할 수 있게 했습니다.
- DAP 디버거 Tools 페이지 카테고리, 액션 이름, 매개변수 설명을 현지화하여 현지화된 도구 미리보기가 원시 영어 schema 텍스트로 되돌아가지 않게 했습니다.
- Tools 페이지 동적 액션과 빈 매개변수 fallback 텍스트를 현지화하면서, 특정 도구 key가 없을 때 기존 schema 설명은 유지하도록 했습니다.
- 깨끗한 Asset Library 설치에서 Roslyn bridge 구현 소스가 내보낸 플러그인 다운로드에 포함되어 호스트 Godot C# 프로젝트에서 직접 컴파일되지 않도록 했습니다.
- 프랑스어 현지화 파일에서 악센트 문자, 굽은 아포스트로피, 줄바꿈 없는 공백, 합자가 mojibake가 아니라 올바르게 표시되도록 수정했습니다.
- reference-integrity Prompt Guide의 `resource_path` 인자를 system_resource_reference_audit의 텍스트 파일 지원 범위와 맞춰 .tscn 및 .tres 경로만 받도록 했습니다.

### Documentation

- Prompt Guides, 현지화, 깨끗한 Asset Library 설치 유지보수 릴리스를 위한 `v1.1.2` 수동 릴리스 노트 소스를 추가했습니다.
- Asset Library 설치용 addon README 사본을 업데이트하여 내보낸 패키지가 패키지 내부에 없는 상대 경로 대신 저장소에서 호스팅되는 문서, 변경 로그, 현재 dev 브랜치 미리보기 이미지로 연결되도록 했습니다.
- Prompt Guides 문서를 업데이트하여 여섯 개의 상위 워크플로진입점를 설명하고, DAP 디버깅이 별도 prompt guide가 아니라 `godot.debug_triage`의 일부임을 명확히 했습니다.

### Internal

- `git archive --worktree-attributes`를 사용하고 fixture의 Roslyn 패키지 참조를 제거하며, Roslyn runtime 소스나 bridge 소스 없이도 내보낸 플러그인 사본이 빌드되는지 확인하는 깨끗한 Asset Library 설치 harness 빌드를 추가했습니다.
- 실제 tool-loader 현지화 inventory 계약을 추가하여 모든 지원 locale에서 Tools 페이지의 표시 트리, 액션, 매개변수 fallback 범위를 검사하도록 했습니다.
- 지원 언어 중 하나라도 다른 locale에 있는 번역 key를 누락하면 CI가 실패하는 locale key parity harness 계약을 추가했습니다.
- MCP prompt, system help, router, 현지화 계약을 업데이트하여 prompt surface가 여섯 개의 상위 워크플로 가이드로 유지되도록 했습니다.

## 이전 버전

1.1.1 이전의 전체 기록은 [영어 CHANGELOG](../../../CHANGELOG.md)를 참조하세요. 한국어 변경 로그는 앞으로 공개 변경에 맞춰 계속 업데이트됩니다.