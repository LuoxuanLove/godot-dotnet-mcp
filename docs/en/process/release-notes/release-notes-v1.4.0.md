## 🧩 Godot .NET MCP v1.4.0: Protocol Refactor Draft

This is the draft release note source for the unreleased v1.4.0 protocol refactor line. It summarizes the user-visible changes currently staged under `Unreleased` in the changelog; it is not a release announcement until the version is formally published.

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v1.4.0/docs/en/process/release-notes/release-notes-v1.4.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v1.4.0/docs/zh-CN/流程/发布说明/发布说明-v1.4.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v1.4.0/docs/ja/プロセス/リリースノート/リリースノート-v1.4.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v1.4.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v1.4.0.md">한국어</a></p>

### ✨ Protocol-First MCP Surface

The v1.4 line moves the default MCP surface to the 2025-11-25 target. Passive context, status, logs, and catalog discovery now live in Resources; workflow orientation stays in Prompts; Tools focus on actions or computed workflow results. Legacy discovery calls return explicit replacement guidance instead of remaining first-class public tools.

### 🌊 Streamable HTTP and Stdio

The default endpoint remains `http://127.0.0.1:3000/mcp`, but its semantics are now aligned with Streamable HTTP: protocol and session headers, JSON/SSE `Accept` negotiation, Origin/CORS checks, GET SSE streams, resumable event history, finite POST SSE responses, heartbeat events, queued server-to-client delivery, and `DELETE /mcp` session termination. Stdio now defaults to newline-delimited JSON-RPC, with legacy `Content-Length` framing retained only as an explicit compatibility mode.

### 🧭 Resource and Prompt UI

The Dock now exposes Resources and Prompts as first-class tabs, including protocol catalog counts, copyable IDs, resource previews, prompt argument inputs, generated prompt previews, and bounded icon rendering. The Tools tab also consumes shared catalog metadata for titles, icons, annotations, input schemas, output schemas, previews, search, and schema copy actions.

### 🧠 C# Semantic Runtime

C# semantic tooling remains available after Asset Library or prepared addon installation through an isolated Roslyn runtime bundle. The shipped addon keeps Roslyn and bridge source files out of the host project compile surface while still supporting semantic read and patch workflows.

### ✅ Compatibility and Validation

This line keeps compatibility guidance for retired discovery tools, hardens HTTP/stdio JSON-RPC behavior, and adds guardrails for public tool removals, root monolith closure, catalog facts, optional capabilities, changelog structure, Roslyn runtime bundle shape, and clean install validation.
