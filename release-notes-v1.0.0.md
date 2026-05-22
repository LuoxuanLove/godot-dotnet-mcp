## Godot .NET MCP v1.0.0

Godot .NET MCP v1.0.0 is the first stable release of the editor-native MCP bridge for Godot .NET projects. It turns the running Godot editor into a live, inspectable workspace for MCP-capable clients: scenes, selected nodes, editor state, runtime feedback, diagnostics, screenshots, and client configuration all become available from the plugin itself.

This release introduces the stable baseline for editor-aware AI workflows in Godot .NET projects.

### Editor-native MCP for Godot

Godot .NET MCP runs inside the Godot editor process. The MCP service is provided by the plugin, so users do not need to run a separate host application or external bridge. Clients work from the editor's current state instead of guessing from files on disk alone.

### Live project and editor context

The plugin exposes the context that matters during real Godot work: the open project, current scene, selected nodes, Dock state, editor logs, diagnostics, screenshots, and runtime state. This lets MCP clients inspect before acting, confirm what the editor can see, and make changes against the live project instead of a stale snapshot.

### Scene, resource, and script workflows

Godot .NET MCP provides high-level workflows for reading and validating scenes, checking resource references, inspecting project files, understanding script structure, and auditing C# scene bindings. These workflows are designed around Godot projects as they are actually edited: scenes, nodes, resources, scripts, and runtime feedback all matter together.

### Runtime automation and diagnostics

The stable release includes runtime support for starting and stopping scenes, reading runtime diagnostics, sending input, and capturing game runtime views. Runtime marker checks, foreground-window capability reporting, structured capture skips, and improved failure diagnostics make automation results easier to understand and safer to act on.

### Godot .NET and C# support

C# support is built into the plugin through a lightweight Roslyn syntax-first layer. It focuses on structure recognition, diagnostics, C# file operations, project context, and scene binding audits without pretending to be a full IDE-grade semantic analyzer.

### Visual editor awareness

Screenshots are part of the core workflow. Clients can capture editor and runtime views so UI state, visual issues, and run results can be reviewed directly instead of described from memory.

### Client configuration from the Dock

The Config page helps connect common MCP clients by generating or copying connection settings, showing detected paths and config targets, and providing one-click actions where supported. The goal is to make local setup direct without adding another background application.

### User-extensible tools

Users can add project-specific `user_*` GDScript tools under `custom_tools/`. The plugin discovers and loads them as first-class tools, making it possible to extend the MCP surface for project-specific workflows without rebuilding the plugin.

### Installation

Godot .NET MCP supports two installation paths:

- Install from the Godot Asset Library.
- Copy the `addons/godot_dotnet_mcp/` source directory into a Godot project.

The plugin targets Godot 4.6+ with .NET support.

### Why this release matters

v1.0.0 establishes Godot .NET MCP as a stable foundation for editor-aware AI workflows in Godot .NET projects. It brings together editor context, runtime feedback, C# syntax support, screenshots, client setup, diagnostics, and user extensions into one local plugin surface.
