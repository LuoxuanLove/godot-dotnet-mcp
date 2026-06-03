# System 도구 계층

System 도구 계층은 플러그인의 고수준 도구 진입점입니다. Agent가 MCP capability guide, project state, editor state, runtime status, editor UI, editor Output, scene, script, symbol을 한곳에서 읽고, 실행 가능한 제안과 patch 진입점도 함께 얻을 수 있게 합니다.

기본 `system` profile은 이 계층만 활성화합니다. 먼저 문맥을 이해한 뒤 적절한 고수준 `system_*` 도구를 고르기 위한 용도입니다. 더 낮은 atomic tool은 내부 구현 링크로만 보입니다.

---

## 파일 구조

```text
tools/system/
├─ executor.gd
├─ atomic_bridge.gd
├─ impl_help.gd
├─ impl_editor.gd
├─ impl_runtime.gd
├─ impl_dap.gd
├─ impl_scene.gd
├─ impl_index.gd
├─ lsp_client.gd
├─ impl_project.gd
└─ impl_script.gd
```

---

## builtin 도구

### Capability Guide
- `system_help`: Agent 지향 MCP capability guide, 권장 시작 순서, screenshot-first 힌트, 숨겨진 control 열거 힌트, runtime automation capability 노트, 현재 tool schema version을 반환합니다.

연결 후에는 먼저 `system_help`를 호출하거나 tool docs를 읽어 현재 schema version을 확인합니다. 작업이 Dock, tab, popup, layout, button visibility, focus switching과 관련될 때는 먼저 `system_editor_control(action=activate_ui)`를 써서 Godot API로 target UI를 활성화한 뒤, `system_editor_control(action=capture_editor)`로 editor screenshot을 가져옵니다. visible control 열거로 target을 찾지 못하면 `include_hidden=true`로 다시 시도합니다.

### Project Level
- `system_project_state`: file count, recent error, running state, `runtime_capabilities`를 담은 project snapshot, compact read와 segmented read를 지원
- `system_editor_state`: main screen, focus, Inspector, FileSystem, runtime summary, capabilities를 포함한 editor session snapshot
- `system_runtime_diagnose`: runtime error, compile error, performance snapshot
- `system_project_configure`: project settings, input map, Autoload 읽기와 쓰기
- `system_project_files`: directory listing, create/delete directory, file read, copy, move, delete, selection, scan, reimport를 지원하는 고수준 project file-tree 진입점
- `system_project_run`: main scene 또는 선택한 scene 실행. marker가 없으면 즉시 반환하며 `timeout_ms`는 auto-stop에만 사용합니다. marker가 있으면 structured runtime-bridge event를 기다리고 bounded wait flow를 사용합니다.
- `system_project_stop`: 현재 project run 중지
- `system_plugin_reload`: freshness 읽기 또는 완전 plugin disable/enable lifecycle reload 예약
- `system_plugin_update`: version, fingerprint, source ref 읽기, update source 선택, ref discovery 또는 sync 시작, sync와 reload progress poll

이 도구들은 현재 `tools/system/impl_project.gd`가 담당하며, `atomic_bridge.gd`를 통해 하위 `project_*`, `editor_*`, `debug_*` atomic tool을 모읍니다.

### Editor UI Level
- `system_editor_control`: main screen 전환, 전체 창 screenshot, control 열거, 좌표 매핑, focus, activation, local click, popup interaction
- `system_editor_log`: Output 읽기, error와 warning filter, Output clear

### Runtime Automation Level
- `system_runtime_control`: 현재 debugger session의 runtime-control safety gate를 조회, 활성화, 비활성화
- `system_runtime_step`: step, capture, input을 묶은 통합 runtime I/O 진입점

### DAP Debugging Level
- `system_dap_debugger`: Godot 내장 DAP endpoint에 연결해 settings, initialize, launch, attach, configuration done, threads, breakpoints, pause, continue, step, stack trace, output, terminate, disconnect를 제어

### Scene Level
- `system_scene_validate`
- `system_scene_analyze`
- `system_scene_tree`
- `system_scene_patch`

### Script Level
- `system_bindings_audit`
- `system_script_analyze`
- `system_script_patch`

### Project Resource Audit Level
- `system_resource_reference_audit`

### Index Level
- `system_project_symbol_search`
- `system_scene_dependency_graph`

---

## Workflow 조언

권장 순서는 다음과 같습니다.

```text
system_editor_state / system_project_state
  -> system_project_files / system_scene_analyze / system_script_analyze / system_runtime_diagnose
  -> system_scene_tree / system_scene_patch / system_script_patch / 대응하는 고수준 system 도구
```

목표가 editor 안에서의 runtime automation이면 권장 순서는 다음과 같습니다.

```text
system_project_run
  -> system_runtime_control(action=enable)
  -> system_runtime_step(action=step)
  -> system_runtime_step(action=capture / input)
```

목표가 editor UI 안에서의 control discovery와 interaction이면 다음을 사용합니다.

```text
system_editor_state
  -> system_editor_control(action=activate_ui)
  -> system_editor_control(action=list_controls)
  -> system_editor_control(action=get_control / capture_control)
  -> system_editor_control(action=focus_control / activate_control / click_control / right_click_control / set_control_text)
```

---

## Atomic Tool와의 관계

System tool은 모든 low-level action을 직접 구현하지 않습니다. 대신 `atomic_bridge.gd`를 통해 scene, script, project, file-system, debug, DAP atomic executor를 조합합니다.

장점은 다음과 같습니다.

- 고수준 workflow가 안정적으로 유지된다.
- 저수준 executor는 세밀한 힘을 유지하면서 Tools tree에서 내부 구현 링크로도 나타날 수 있다.
- write protection을 Atomic Bridge 계층에서 중앙 집중식으로 강제할 수 있다.

---

## 쓰기 보호

`atomic_bridge.gd`는 write action을 가로채 target path가 plugin directory 안인지 확인합니다. 기본적으로 system tool은 다음 위치에 직접 쓸 수 없습니다.

```text
res://addons/godot_dotnet_mcp/
```

플러그인 자체 파일을 정말 바꿔야 한다면 `plugin_developer` tool과 명시적인 authorization을 사용합니다.

---

## User Tool 확장

`executor.gd`는 다음도 스캔합니다.

```text
res://addons/godot_dotnet_mcp/custom_tools/
```

`handles()`, `get_tools()`, `execute()`를 구현하고 `user_`로 시작하는 tool name을 반환하는 script는 같은 tool tree에 추가됩니다.

이렇게 해서 `system`과 `user` 고수준 tool group을 같은 UI에서 나란히 볼 수 있습니다.