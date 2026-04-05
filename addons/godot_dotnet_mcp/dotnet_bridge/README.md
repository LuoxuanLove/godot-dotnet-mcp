# Dotnet Bridge

This directory contains the v0.6 `.NET MCP Bridge` skeleton.

## What is in scope now

- Independent .NET 8 console project
- stdio MCP entry point
- `--health` and `--version` process modes
- Minimal JSON-RPC request routing for `initialize`, `tools/list`, `ping`, `shutdown`, and `exit`
- Read-only tool set: `dotnet_build`, `csproj_read`, `cs_file_read`, `cs_diagnostics`, `solution_analyze`
- Write tool set: `csproj_write` and `cs_file_patch`
- `csproj_write` supports target framework, package reference, project reference, and metadata updates
- `cs_file_patch` supports both text patches and semantic member patches for methods and fields
- Self-contained `win-x64` publish profile for release packaging

## What is not in scope yet

- Plugin-side installation UI
- Full release pipeline automation

## Build

```bash
dotnet build addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj
```

## Run

```bash
dotnet run --project addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj -- --health
```

## Publish

Release packaging targets `win-x64` and is designed to be self-contained, so users do not need to install .NET separately.
The publish machine still needs access to the matching `win-x64` runtime pack cache or source.

```bash
dotnet publish addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj -c Release -p:PublishProfile=WinX64SelfContained
```

The generated package should center on the single-file Bridge exe and include checksum files and minimal install notes.

## Troubleshooting

- If Windows shows a JIT debugger or `0xe0434352` dialog, update to the latest Bridge build. The current entry point catches fatal exceptions and writes them to stderr instead of surfacing the debugger prompt.
- For local development builds in this workspace, the .NET CLI may need `DOTNET_CLI_HOME` and `NUGET_PACKAGES` redirected away from the default user profile because the sandbox blocks the host profile directory.
- `cs_file_patch` applies insert text verbatim. For line-based insertions, include the newline characters you want to keep in the file.
- Semantic member patches use `typeName` and `memberName` to identify the target member. Provide `returnType` or `fieldType` plus `body` or `initializer` when adding or updating members.
