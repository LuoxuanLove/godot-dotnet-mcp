# Dotnet Bridge

This directory now holds the internal shared .NET support library used by the Godot editor plugin.
It is not an executable host process and does not expose a standalone stdio bridge.

## Scope

- Shared Roslyn support code for the plugin façade
- Library-only build output
- No external host, no process launcher, no publish profile

## Build

```bash
dotnet build addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj
```
