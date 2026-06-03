# Home and Config Page Implementation

This document describes the scene script responsibilities, dynamic layout logic, and config generation flow for the `Home` and `Config` pages. The file names `server_panel.tscn` and `server_tab.gd` stay unchanged, but the first visible tab has already been reshaped into `Home` in the latest README.

---

## `Home` Page

### Target Responsibilities

`Home` is responsible for:

- showing the current service state and service address
- showing connection count, request count, and the latest request
- changing the port, auto-start, log level, and language
- starting, restarting, and stopping the embedded server
- triggering a full plugin reload
- showing the plugin’s own diagnostic summary

The current Home page does not expose the CORS allowlist directly. Browser-style clients that need cross-origin access to the local HTTP MCP should configure a precise origin through the `GODOT_DOTNET_MCP_ALLOWED_CORS_ORIGINS` environment variable. CLI and desktop config-file clients usually do not need CORS.

### Controller Responsibilities

`server_tab.gd` currently does four main things:

1. It asks `server_tab_model_projection.gd` to project the model into pure presentation data.
2. It writes the projected result back to status text, button state, and dropdowns.
3. It keeps the Home page responsive layout and scaling logic.
4. It turns button and setting actions into signals.

The status overview, self-diagnostic summary, and the log and language option models are no longer assembled directly in `server_tab.gd`. They now live in `server_tab_model_projection.gd`.

### Responsive Layout

`server_tab.gd` still keeps more runtime layout control than the `Tools` page because it depends on:

- `GridContainer`
- diagnostic cards
- multi-column settings areas

These controls need to switch into a tighter arrangement at different widths.

### Self-Diagnostic Card

The data shown in the top self-diagnostic card on the Home page comes from:

- `plugin_runtime_state(action=get_lsp_diagnostics_status)`: detailed runtime self-check snapshot
- `project_state(include_runtime_health=true)`: lightweight health summary

This content stays on the Home page so the service state, service address, reload entry, and plugin self-diagnostics remain on the front page instead of living in a separate service flow.

---

## `Config` Page

### Target Responsibilities

`Config` is responsible for:

- platform switching
- desktop client config display
- CLI command display
- Claude Code scope switching
- one-click install, write, and uninstall for `godot-mcp`
- copying config text or commands
- clearly showing install status and the install location or scope

### Controller Structure

`config_tab.gd` no longer writes every client card into the `.tscn` ahead of time. Instead, it creates cards at runtime. The reasons are:

- after a platform switch, only the current target client is shown
- card content is driven by the model, which works better for multi-client expansion
- CLI and desktop clients use different button combinations

### Client Card Generation

Each client card is created in `_create_client_card()` at runtime:

- `PanelContainer`
- `MarginContainer`
- `VBoxContainer`
- title, description, path text, content area, and button area

The static group cards and dynamic client cards on the Config page both override `PanelContainer.panel` through `config_tab.gd::_make_framed_panel_style()`: the background copies the editor theme’s `Tree.panel`, then adds a `1px` border with `Editor.separator_color` on `StyleBoxFlat`. This keeps the same background depth as the `Tools` page while restoring clear card boundaries.

The config content area no longer uses an editable control directly. Instead, it uses `PanelContainer + Label` and applies the `TextEdit.read_only` theme style. The copy button floats in the upper-right corner of the content area and stays hidden by default. It appears when the mouse enters the content area. This keeps the visual hierarchy of a read-only text area and avoids the extra scrolling and focus behavior that `TextEdit` would add in a narrow layout.

Button behavior:

- Desktop clients: show `Write Config`, `Remove Config`, open client, path management, and copy actions depending on capability
- CLI clients: show one-click install or uninstall, open terminal, path management, and copy actions depending on capability

### Platform Groups

`Config` currently groups platforms into:

- `desktop`
- `cli`

Claude Code also gets a dedicated scope-row display.

---

## Config Generation and Write Flow

The runtime flow is:

```text
plugin.gd
  -> build model
  -> config_tab.gd
  -> user clicks Write / Copy
  -> mcp_dock.gd signal
  -> plugin.gd / config_feature.gd
  -> config_feature_config_workflow.gd
  -> ClientConfigService.write_config_file()
```

During writing:

1. First parse the JSON text shown in the current UI.
2. If the target file already exists and can be parsed, read the original config.
3. Only touch the `mcpServers` node.
4. Only update the `godot-mcp` entry and do not overwrite other MCP servers.

---

## Shared Constraints for the `Server` and `Config` Pages

- Text is driven by the localization service and does not depend on Godot auto-translation.
- Actions flow back to `plugin.gd` through signals.
- The tabs themselves do not hold `MCPHttpServer` or `SettingsStore` instances.
- The read-only text area should reuse the Godot text-control theme where possible. The Config page content area uses `PanelContainer + Label` and applies the `TextEdit.read_only` style to keep the appearance consistent.

---

## Related Files

| Path | Purpose |
|---|---|
| `ui/server_panel.tscn` | Server page scene |
| `ui/server_tab.gd` | Server page controller, responsible for writing back projections, layout, and signals |
| `ui/server_tab_model_projection.gd` | Pure projection collaborator for the Server page, responsible for status summary, self-diagnostics, and option model construction |
| `ui/config_panel.tscn` | Config page scene |
| `ui/config_tab.gd` | Config page controller |
| `plugin/config/client_config_service.gd` | Config page config service facade, which delegates to serializer, inspection, transaction, and launcher adapter |
| `plugin/config/config_paths.gd` | Client paths and command templates |
