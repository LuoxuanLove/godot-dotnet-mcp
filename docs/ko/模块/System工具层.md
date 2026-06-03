# System 도구 계층

이 문서는 외부에 노출되는 System 계층 도구와 내부 구현 구조를 설명합니다.

## 공개 표면

- `system_editor_state`
- `system_project_state`
- `system_runtime_control`
- `system_runtime_step`
- `system_dap_debugger`
- `system_scene_validate`
- `system_scene_analyze`
- `system_scene_patch`
- `system_script_analyze`
- `system_script_patch`
- `system_resource_reference_audit`

## 내부 구조

- `atomic_bridge.gd`가 하위 executor를 연결합니다.
- `impl_*.gd`가 기능별 구현을 나눕니다.
- `custom_tools/`는 User 도구를 위한 별도 영역입니다.

## 원칙

- 공개 계층은 단순하게 유지합니다.
- 내부 구현은 필요에 따라 나눌 수 있지만, 외부 이름은 안정적으로 유지합니다.
