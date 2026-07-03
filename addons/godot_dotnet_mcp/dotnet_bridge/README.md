# Dotnet Bridge

This directory holds the internal .NET bridge used by the Godot editor plugin.
Release validation publishes framework-dependent Roslyn runtime files so C# syntax/member/export/patch support can ship with the installable addon without exposing these source files to the host Godot project compile surface. The installed runtime files require a local .NET 8 runtime available to the `dotnet` host.

## Scope

- Shared Roslyn support code for the plugin façade
- Single-process JSON command entry point for release/runtime probes
- Publish profile for the installable framework-dependent Roslyn runtime files

## Build

```bash
dotnet build addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj
```

```bash
dotnet run --project addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj -- --capabilities
```

```bash
dotnet run --project addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj -- --call-json-file cs_file_read request.json
```
