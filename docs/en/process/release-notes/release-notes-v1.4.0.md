## 🧩 Godot .NET MCP v1.4.0: Protocol Refactor Line Initialized

Godot .NET MCP v1.4.0 opens the protocol-refactor line with a stricter plugin-first release surface, resource-first context entry points, and stronger contract gates for public MCP behavior.

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.4.0/docs/en/process/release-notes/release-notes-v1.4.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.4.0/docs/zh-CN/流程/发布说明/发布说明-v1.4.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.4.0/docs/ja/プロセス/リリースノート/リリースノート-v1.4.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.4.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v1.4.0.md">한국어</a></p>

### ✨ Release Highlights

The v1.4.0 line establishes the protocol-refactor baseline: passive context moves toward MCP Resources, workflow orientation stays in Prompts, public Tools narrow toward action and computed workflow entries, and legacy discovery calls return explicit replacement guidance.

### 📚 Resource-First Protocol Surface

The v1.4.0 line moves passive context, status, and catalog discovery toward MCP Resources, keeps workflow planning in Prompts, and narrows public Tools to actions or computed workflow results. Legacy discovery calls now provide explicit replacement guidance instead of remaining first-class public tools.

Editor Output reads now follow the same resource-first model: clients can read `godot-dotnet-mcp://logs/editor/output` or `godot-dotnet-mcp://logs/editor/errors`, while Output clearing remains an explicit editor-control action instead of a passive Resource.

### 🧪 Reproducible Plugin Gates

Release-facing claims stay tied to plugin-owned checks: localized documentation validation, manifest-backed public-tool guardrails, headless MCP contracts, and clean install verification. This keeps the release notes focused on behavior users can reproduce from the plugin repository itself.

### ✅ Compatibility and Upgrade Notes

This version line updates plugin metadata to v1.4.0 and continues to target Godot 4.6+ .NET projects. Clients should prefer the new resource and prompt entry points for passive context and planning, while legacy discovery calls provide migration guidance instead of remaining first-class public tools.
