## 🧩 Godot .NET MCP v1.1.1: Complete DAP Debugger Sessions

Godot .NET MCP `v1.1.1` focuses on making the built-in Godot Debug Adapter Protocol workflow usable as a complete session, not just a collection of one-off breakpoint and stepping calls. Agents can now initialize a debugger connection, launch or attach, finish configuration, inspect threads, and close the session through the same high-level DAP tool surface.

### ✨ Full DAP Session Flow

- `system_dap_debugger` now supports runtime settings, explicit session IDs, `initialize`, `launch`, `attach`, `configuration_done`, `threads`, `terminate`, and `disconnect` while keeping one high-level Debug Adapter Protocol entry point.
- Existing breakpoint, pause, continue, step-over, stack-trace, and output-event actions continue to work through the same tool, so clients do not need to switch between fragmented debugger tools.

### 🛡️ Safer Debugger Endpoint Handling

- DAP endpoint access defaults to loopback hosts, keeping normal Godot editor debugging local unless remote hosts are explicitly enabled.
- Raw DAP request and message details are no longer returned by default; when protocol troubleshooting requires `include_raw=true`, sensitive-looking fields are redacted before being reported.
- Session, message, frame, buffer, and breakpoint caches now have fixed bounds to keep long debugger sessions from growing without limit.

### 🔧 Clearer Diagnostics and Tool Discovery

- DAP lifecycle mistakes now return structured protocol errors such as `dap_invalid_session_state`, `dap_invalid_settings`, and `dap_limit_exceeded`, making client-side recovery easier.
- Tool descriptions, Tools-page documentation, protocol facts, and harness coverage were updated so the advertised debugger actions match the runtime schema.

### ✅ Compatibility and Upgrade Notes

This release keeps the Godot 4.6 / .NET 8 compatibility target and does not change installation paths. Users who rely on the DAP tool should reconnect or refresh their MCP tool schema after upgrading so clients see the new `2026-05-03.13` DAP action surface.
