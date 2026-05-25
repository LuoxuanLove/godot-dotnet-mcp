## 🎉 Godot .NET MCP v1.0.0: First Stable Release

Godot .NET MCP `v1.0.0` is the first stable release of an editor-native MCP bridge built for Godot 4.6+ .NET projects. It turns the running Godot editor into a live, inspectable, controllable workspace for MCP-capable clients: scenes, selected nodes, project files, editor state, runtime logs, diagnostics, screenshots, client setup, and extension points all become available from one local plugin surface.

This is the stable baseline for editor-aware AI workflows in Godot. Instead of asking a client to infer everything from files on disk, Godot .NET MCP lets it work from the same editor context that developers actually use: what is open, what is selected, what is running, what failed, and what the editor can see right now.

### 🧭 Editor-Native MCP, No Extra Host

The MCP service runs inside the Godot editor process. Enable the plugin, open the Dock, start the service, and connect a client. There is no separate daemon, central server, packaged bridge app, or extra background host to install before the editor can provide context.

That design matters because the editor is the source of truth for many Godot decisions. The plugin can report the current project, active scene, selected nodes, Dock state, plugin health, runtime state, editor logs, diagnostics, and screenshots from the live session instead of a stale repository snapshot.

### 🎮 Live Godot Context for Agents

`v1.0.0` exposes the context an agent needs before it edits anything: project metadata, scene tree details, selected nodes, resource references, file inventory, editor diagnostics, output logs, and runtime status. The result is a workflow where clients can inspect first, act second, and verify after the change.

Scene and resource tools help read scene structure, validate references, audit dependencies, and identify suspicious project scans. Script and project tools help connect files, scenes, resources, and C# bindings into one Godot-aware picture instead of treating each file type as an isolated document.

### 🌳 Scene, Resource, and Editor Workflows

The stable tool surface is organized around real Godot work: scenes, nodes, resources, scripts, project state, editor state, diagnostics, runtime execution, screenshots, and plugin operations. High-level tools sit on top of internal helpers so clients can use meaningful workflows without depending on low-level implementation details.

The Tools Dock presents those capabilities in a localizable, inspectable tree. Split plugin tool categories, clearer descriptions, and contract coverage keep the registered tool surface easier to understand and safer to evolve.

### ▶️ Runtime Automation with Evidence

Godot .NET MCP can start and stop scenes, monitor runtime state, collect runtime logs, send input, and capture game runtime views. Runtime marker checks can wait for success or failure text before declaring a run complete, and marker-mode auto-stop helps keep automation runs contained.

Compared with the prerelease line, `v1.0.0` also includes stability fixes around runtime bridge messages, foreground-window capability reporting, headless or dummy rendering captures, repeated marker text, high-volume logs, and failure diagnostics. When runtime automation cannot proceed, the plugin now tries harder to explain whether the client should retry, change launch mode, inspect project state, or use a fallback.

### 🖼️ Screenshots and Visual Editor Awareness

Screenshots are a first-class part of the workflow. Clients can capture editor and runtime views, use visual evidence while reasoning about UI state, and verify results without relying only on textual descriptions.

This is especially important for editor plugins and game workflows, where the relevant answer is often visible in a panel, popup, viewport, or running scene. `v1.0.0` makes that visual layer part of the local MCP surface.

### 🔎 Godot .NET and C# Support

The plugin includes a lightweight Roslyn syntax-first layer for C# projects. It focuses on structure recognition, diagnostics boundaries, C# file operations, project context, and scene binding audits without pretending to replace a full IDE semantic model.

For Godot .NET projects, that means clients can reason about C# scripts alongside scenes and resources. They can inspect bindings, understand script structure, and avoid treating `.cs`, `.tscn`, and `.tres` files as unrelated pieces.

### ⚙️ Client Configuration from the Dock

The Config page is designed to make setup direct. It can generate or copy connection settings for common MCP clients, show detected paths and config targets, describe client capability levels, and provide one-click actions where supported.

The goal is simple: install the plugin, start the local service, copy or apply the config, and connect the client. Users should not need to reverse-engineer command lines or maintain a separate host process just to let an agent see the editor.

### 🧰 User Extensions and Project-Specific Tools

Users can add project-specific `user_*` GDScript tools under `custom_tools/`. The plugin discovers and loads them as first-class tools, so a project can extend the MCP surface for its own workflows without rebuilding the plugin.

This keeps the stable core focused while still leaving room for specialized automation. Teams can add narrow, project-aware actions beside the built-in tools and let clients discover them through the same tool registry.

### 🚨 Diagnostics, Health, and Release Stability

The stable release includes the diagnostic work from the prerelease cycle: startup and reload phase timing, clearer listener failures, occupied or restricted port explanations, structured skipped capture results, suspect empty-scan reports, and more actionable `system_project_run` failure evidence.

`v1.0.0` also fixes issues discovered after the prereleases, including default C# project discovery for debug `dotnet` operations and Dock naming consistency. The release notes, changelog, and generated commit summary now stay aligned to the post-`v1.0.0-pre3` boundary so the stable release does not repeat commits that were already published in a prerelease.

### 🚀 Installation

Godot .NET MCP supports two installation paths:

- Install from the Godot Asset Library.
- Copy the `addons/godot_dotnet_mcp/` source directory into a Godot project.

After copying from source, users can stay on the latest GitHub code by updating the copied addon through their usual editor or GUI file workflow, or by using MCP project-file tools when appropriate.

The plugin targets Godot 4.6+ with .NET support.

### 🏁 Why This Release Matters

`v1.0.0` establishes Godot .NET MCP as a stable foundation for editor-aware AI workflows in Godot .NET projects. It brings together live editor context, scene and resource inspection, runtime automation, visual verification, C# structure support, client setup, diagnostics, and user extensions into one local plugin.

If the prereleases were about proving the shape of the bridge and hardening the rough edges, this stable release is the point where the full experience comes together: easier setup, richer context, more useful tools, better diagnostics, and a cleaner release path for future improvements.
