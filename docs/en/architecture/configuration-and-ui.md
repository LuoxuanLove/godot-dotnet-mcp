# Configuration and UI

## Dock Structure

The current Dock focuses on three tasks:

- `Home`: service state, port, language, debug toggle, and self-diagnostic summary
- `Tools`: tool-category toggles and statistics
- `Config`: connection configuration display and write-back for external MCP clients

It no longer carries:

- author showcase content
- promotional text
- explanation blocks unrelated to tool capability

## Entry and Tab Responsibilities

The Dock entry is still registered by `plugin.gd` on the right side of the Godot editor, but the node structure is now scene-based:

- `ui/mcp_dock.tscn`: Dock root scene, responsible for the title bar, status light, and `TabContainer`
- `ui/server_panel.tscn`: service state and base settings
- `ui/tools_tab.tscn`: tool tree, search, preview, category and tool toggles, and collapse state
- `ui/config_panel.tscn`: client configuration and command generation

The controller scripts only receive `apply_model(model)` and do not own service objects directly.

## `Home` Tab

### Visible Information

- status: whether the service is running
- service address: the MCP address built from the current host and port
- active connections: number of currently connected clients
- total requests: total request count and total connection count
- recent request: the last HTTP method and its time

### Available Actions

1. Change the port
2. Toggle auto-start
3. Toggle debug logging
4. Toggle the plugin language
5. Start the service
6. Restart the service
7. Stop the service
8. Fully reload the plugin

### Behavior Notes

- `Start` calls `plugin.gd -> ServerRuntimeController.start()`
- `Restart` calls `reinitialize()` first and then `start()`, which refreshes the port, debug mode, and disabled-tool list
- `Stop` only stops the `MCPServer` listener. It does not destroy the Dock
- `Full Reload Plugin` is no longer just a runtime `detach()` and `attach()`. It is driven by a separate coordinator node that calls `set_plugin_enabled(false/true)` on the Godot plugin layer, which makes it behave much closer to disabling and re-enabling the plugin in Project Settings
- Before a full reload, the plugin records the current outer tab of `MCPDock`, the inner tab, and a focus snapshot inside the tab. After the new instance starts, it first switches back to the `MCPDock` tab on the host Dock, then restores the inner tab and the original focused control
- Language switching only updates `settings.language` and triggers a lightweight `apply_model()` refresh. It no longer rebuilds the entire Dock
- Language switching and the focus restore after a full reload both follow the rule of restoring only the original control, not forcing focus. If the original control no longer exists or cannot take focus, the plugin stays quiet
- The language menu is shown as `self-name (localized name)`, for example English with its localized display name or Japanese with its localized display name.

## `Tools` Tab

### Available Actions

1. Search the currently visible tools
2. Toggle a single tool, a category, or a whole domain on or off
3. Remember the collapse state for root, category, tool, or atomic nodes
4. Use the right-click menu to copy the localized name, English ID, or schema
5. Start a delete-user-tool request from the `user` category
6. View the description, parameter summary, runtime information, and atomic-tool preview for the selected item

### Behavior Notes

- The enabled count in the tool tree is calculated from the live tool list returned by the runtime service, not from static hard-coded data
- The current main tree prefers the runtime-generated Tool Presentation Model. `toolTree` expresses the tool structure as domain, category, high-level tool, atomic, and action layers. The old local group-tree logic is only used when that model is missing
- `/api/tools`, MCP `tools/list`, and stdio `tools/list` still expose a flat `tools[]`, but now also provide `toolTree`, `toolGroups`, `groupPath`, and `treeChildren`, so clients and the Dock can share the same presentation semantics
- Search results are precomputed by a separate search collaborator before the main controller rebuilds the tree
- Preview text is built by an independent preview collaborator, and it currently covers domain, category, tool, atomic, and action nodes
- The `collapsed_system_tools` setting controls which system tools are collapsed by default in the tree. It currently covers the public builtin `system_*` tools

## `Config` Tab

The config-generation logic has been split out of the UI script and is handled by helper modules. This has two goals:

- reduce the coupling between Dock code and string templates
- keep changes for different client configs from leaking into the UI layer directly

### Platform Filtering

The top of the config page now selects the Agent platform first, and then shows only the content for that platform. It no longer stacks every platform in one long list.

The platforms fall into two groups:

- Desktop and config-file clients: Claude Desktop, Cursor, Trae, Codex Desktop, OpenCode Desktop, Windsurf, Cline, Roo Code, and Cherry Studio
- CLI command clients: Claude Code, Codex, Gemini, OpenCode, and Qwen Code

### Recommended Workflow

Use the config page in this order:

1. Select the target client in the top platform dropdown
2. Confirm whether the page is showing the config-file area or the CLI area
3. For desktop clients, check the config path and JSON content first, then decide between `Write Config` and `Copy`
4. For CLI clients, first confirm the command text. If the client supports scopes, also confirm the `user / project` scope
5. After copying or writing, return to the client side and verify the connection

### Config-File Area

The current one-click write targets include:

- Claude Desktop
- Cursor
- Trae
- Windsurf
- Cline
- Roo Code
- OpenCode

Each entry contains:

- config file path
- JSON content to write
- one-click write button
- copy button

The content area is built from `PanelContainer + Label` and reuses the `TextEdit.read_only` theme style. The copy button appears as a floating button in the upper-right corner of the content area, and it can be shown with either text or an icon. The outer group cards and client cards on the Config page use `Tree.panel` background and a 1 px `Editor.separator_color` border, which keeps the same background depth as the `Tools` page while preserving clear card boundaries.

The one-click write behavior is:

1. Parse the current JSON text
2. If the target file already exists and is valid JSON, merge into it with the smallest possible change
3. Only update the `mcpServers["godot-mcp"]` node so other servers in the file stay untouched
4. Create directories recursively before writing when needed

Additional notes:

- `Write Config` only updates `mcpServers["godot-mcp"]`. It does not clear other MCP services in the target file
- `Copy` copies the full configuration currently shown in the text box, which is useful for manual pasting into version-controlled or restricted environments

### CLI Area

The current CLI platforms are:

- Claude Code
- Codex
- Gemini
- OpenCode
- Qwen Code

Among them:

- Claude Code, Gemini, and Qwen Code also show a scope dropdown (`user` / `project`)
- Codex and OpenCode show the current command text, configuration-file, or direct-open-current-project action

The CLI area follows these rules:

- `scope` affects the command arguments or config path for CLI clients that support user-level or project-level configuration
- The CLI area prefers one-click add or remove through the client’s own command line. Clients that do not support direct command writing still get copy or open-config-file flows
- When the platform changes to a desktop client, the CLI area is hidden so unrelated commands do not stay visible at the same time

## Settings Persistence

Editor settings should have:

- a default value
- a reset path
- restore after restart
- a clear boundary between the current project and the current editor

Current persistence paths:

| Path | Purpose |
|---|---|
| `user://godot_dotnet_mcp/settings.json` | Saves port, language, auto-start, debug mode, disabled tools, collapse state, and the temporary focus snapshot for full reloads |
| `user://godot_dotnet_mcp/profiles/*.json` | Saves custom tool profiles |

Load logic lives in `plugin/config/settings_store.gd`:

- when there is no settings file yet, all categories and domains are collapsed by default
- when a settings file already exists, missing fields are filled in for compatibility
- when `tool_profile_id` is empty, the plugin falls back to `system`

## UI Constraints in the Docs

When the UI or a setting changes, the docs must also explain:

- where the entry tab lives
- the setting key or config field name
- whether the change affects the protocol layer
- whether existing client configs need migration

## Implementation Notes

### UI Wiring

The current wiring path is:

1. `_dock_model_service.build_model()` gathers state, the tool list, config text, and `editor_scale`
2. `ui/mcp_dock.gd` distributes the model to the three tabs
3. `ui/server_tab.gd` powers the current `Home` tab implementation. It first projects the model into pure presentation data through `server_tab_model_projection.gd`, then fills in the text, button state, and dropdowns. `ui/tools_tab.gd` and `ui/config_tab.gd` continue to consume their own collaborators
4. User actions flow back through explicit signals to `plugin.gd`, which then calls service objects or the settings store

### UI Localization

The Dock root container, the Home, Tools, and Config tabs, the client titles in Config, the install state, the log level, the tool-tree names, and the high-level tool descriptions are all filled from localization keys. They no longer rely on hard-coded text in the scene files.

To avoid Godot’s automatic translation from changing common English words again, the Dock root container and all three tab root controls explicitly disable `auto_translate_mode`. So plugin language switching is fully driven by `LocalizationService`, not by the editor’s global translation state.

Runtime error messages for tools still come back as structured `error` and `message` values, and the caller handles them according to tool semantics. Text that is visible inside the Dock continues to be managed centrally by localization.

### UI Scaling

The scaling strategy now uses `EditorInterface.get_editor_scale()` as the only source of truth. Scaling affects:

- Dock root minimum size
- tab padding
- spacing in `HBoxContainer`, `VBoxContainer`, and `GridContainer`
- minimum height for `SpinBox`, `OptionButton`, and `Button`
- the height of the read-only text panel in the Config content area
- the font size of dynamically generated tool-tree notes

The reason is:

- the original constants look too dense on high DPI or when the editor scale is above `1.0`
- the scaling logic has already been pushed down into the controllers and is no longer maintained by a single entry script

### Why the Server and Config Tabs Need Extra Layout Rules

These two tabs contain:

- `GridContainer`
- long-text `Label`
- read-only `TextEdit`
- `OptionButton` controls that need to stretch horizontally

If `size_flags_horizontal = SIZE_EXPAND_FILL` and scale-adjusted minimum heights are not set explicitly, the result can be:

- the text area becoming too narrow
- button heights looking smaller than the editor’s visual scale
- checkbox labels sticking to the edge or looking as if they do not exist

## Troubleshooting Tips

- If the server tab shows the right state but the controls are obviously too small, check whether `editor_scale` made it into the model
- If a checkbox only shows the box and not the label, check whether `server_tab.gd` assigned localized text to `AutoStartCheck`
- If the config page text box does not expand with width, check whether `Content`, each section, and `TextEdit` in `config_panel.tscn` all have horizontal expansion constraints
- If one-click write fails, first check whether the target path is writable and whether the existing JSON can be parsed
- If you need main-project runtime debug information, prefer `MCPRuntimeBridge`. It returns runtime-bridge events and editor debugger session state instead of a full mirror of the native Output or Debugger panels
- `MCPRuntimeBridge` registers itself automatically as the project Autoload when the plugin is enabled, so the main project does not need manual wiring. If another script already owns the same Autoload name, the runtime bridge reports that it is not connected
