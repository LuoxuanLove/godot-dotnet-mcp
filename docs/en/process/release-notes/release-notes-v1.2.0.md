## 🧩 Godot .NET MCP v1.2.0: Reconnect-Aware Agent Workflows

Godot .NET MCP `v1.2.0` is a reliability and editor-control release for agents that stay connected to Godot while projects, plugins, and custom tools are changing. It improves reconnect guidance, multi-client diagnostics, Godot UI automation, User-tool observability, and protocol guardrails while keeping Godot 4.6+ .NET support, Asset Library installs, direct source-copy installs, and existing high-level tool names compatible.

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.0/docs/en/process/release-notes/release-notes-v1.2.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.0/docs/zh-CN/流程/发布说明/发布说明-v1.2.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.0/docs/ja/プロセス/リリースノート/リリースノート-v1.2.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v1.2.0.md">한국어</a></p>

### 🔁 Reconnect-Aware Multi-Client Sessions

Health, plugin reload, and plugin update responses now report maintenance-window state, reconnect expectations, retry timing, and stale-tool-list guidance. Clients can tell when a disconnect is temporary, when schemas may need to be fetched again, and when update sync or lifecycle reload work is still in progress.

HTTP health reporting also includes stable connection IDs, request IDs, client summaries, active sessions, and recently disconnected sessions. When several MCP clients or agent sessions are attached at once, the plugin gives them a clearer picture of who is connected and how to recover after a reload.

### 🖱️ Stronger Godot Editor UI Control

`system_editor_control` can now work through more of the Godot editor UI directly. Agents can list top menus, open `MenuButton` popups, select visible `PopupMenu` rows by text, index, or id, switch registered editor main screens, control distraction-free mode, and send hover or leave events for tooltip and floating-panel checks.

These controls make editor automation less dependent on OS-level mouse movement. They also reject hidden popups, disabled rows, separators, submenu rows, duplicate text matches, and conflicting selectors, so UI automation fails with clearer reasons instead of silently choosing the wrong menu item.

### 🧰 Tool Activity and User-Tool Diagnostics

The new `system_tool_activity` entry reports running tool calls, recent completions, execution order, and optional self-reported `_mcp_context` supplied by clients. This gives parallel agents a lightweight way to understand what is already happening before starting another long-running operation.

User-tool runtime diagnostics now surface discovered custom tools, load failures, watcher state, compatibility summaries, and recent audit entries through plugin evolution diagnostics and project health. The diagnostics are read-only and do not change custom-tool loading behavior, but they make extension-tool failures much easier to inspect.

### 🛡️ Safer Protocol and Debug Boundaries

HTTP and stdio now handle malformed JSON-RPC top-level `params` consistently with standard `-32602` errors, while invalid `tools/call.arguments` values continue to report normal MCP tool-result errors. Resource and Prompt Guide output also has size protection: oversized file-backed resources fail before expensive reads, and shortened prompt text includes `_meta` truncation details.

DAP debugger calls now reject oversized frames and excessive timeouts with clear limit errors. Script editing also uses explicit `NotImplementedException` guard bodies for generated empty C# methods, reducing ambiguous generated-body behavior.

### 🌐 Localized Documentation and Release Notes

The public documentation tree is now maintained in English, Simplified Chinese, Japanese, and Korean with localized directory and file names. Dock UI localization gained Korean coverage and broader translated tool metadata, client guidance, prompt-guide text, reconnect guidance, and fallback labels across supported languages.

The `v1.2.0` release notes are preserved in all four documentation trees. The GitHub Release body is rendered from the English note, while the note itself links to the other language versions so readers can choose the documentation language that fits them.

### ✅ Compatibility and Upgrade Notes

Existing high-level tool names remain compatible. The public tool schema version changes because editor control, tool activity, and User-tool diagnostics expose new capabilities, so clients should reconnect and fetch the tool list again after upgrading.

No file layout migration is required for existing installs. Continue using the Godot Asset Library installation path or copy `addons/godot_dotnet_mcp/` directly from the source tree. During plugin reloads or update syncs, clients should poll health, reconnect if the transport drops, and refresh tools when the maintenance window says schemas may be stale.
