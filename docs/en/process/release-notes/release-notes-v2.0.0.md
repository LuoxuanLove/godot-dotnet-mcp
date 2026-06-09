## 🧩 Godot .NET MCP v2.0.0: Companion Sessions

Godot .NET MCP v2.0.0 starts the optional Companion direction with a project-scoped .NET contract layer. The first pieces define how static project analysis stays available without an open editor, and how editor-live automation becomes available only after a matching Godot editor bridge is online.

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v2.0.0/docs/en/process/release-notes/release-notes-v2.0.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v2.0.0/docs/zh-CN/流程/发布说明/发布说明-v2.0.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v2.0.0/docs/ja/プロセス/リリースノート/リリースノート-v2.0.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v2.0.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v2.0.0.md">한국어</a></p>

### ✨ Static Analysis Without Pretending To Be Live

The Companion contract separates static/headless capabilities from live editor capabilities. Project sessions can expose C# and resource-analysis style work while clearly withholding selected node, Inspector, Dock, screenshot, and runtime validation state until the editor bridge is connected.

### 🔐 Project-Scoped Sessions

Tool calls must carry both `project_id` and `session_id`, and the broker rejects attempts to reuse a session across a different project. This gives the v2.0 line a clear isolation boundary before multi-project orchestration is added.

### ✅ Compatibility and Upgrade Notes

The Companion layer is a contract library in this stage. It does not start a background process, open a port, launch Godot, or change the existing editor-native plugin startup behavior.
