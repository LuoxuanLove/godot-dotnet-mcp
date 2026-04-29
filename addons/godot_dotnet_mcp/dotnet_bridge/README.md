# Dotnet Bridge

This directory now holds the internal shared .NET support library used by the Godot editor plugin.
It does not expose a standalone runtime entry point.

## Scope

- Shared Roslyn support code for the plugin façade
- Library-only build output
- No process launcher or publish profile

## Build

```bash
dotnet build addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj
```
