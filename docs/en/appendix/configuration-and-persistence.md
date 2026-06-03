# Configuration and Persistence

This document summarizes the config paths, persistence formats, and import and export constraints currently used by the plugin.

---

## Persistence Paths

| Path | Type | Purpose |
|---|---|---|
| `user://godot_dotnet_mcp/settings.json` | JSON | Plugin settings |
| `user://godot_dotnet_mcp/profiles/*.json` | JSON | Custom tool profiles |
| `user://godot_dotnet_mcp/captures/editor/` | Directory | Default directory for full editor screenshots; root-level `user://file.png` paths are normalized here |
| `user://godot_dotnet_mcp/captures/editor_controls/` | Directory | Default directory for control screenshots and `activate_ui` attached captures; root-level `user://file.png` paths are normalized here |
| `user://godot_dotnet_mcp/runtime/captures/<session_id>/` | Directory | Default per-session temporary output for runtime screenshots and low-frequency frame sequences; can be redirected through `capture_dir` |
| `user://godot_dotnet_mcp/runtime/events.json` | JSON | Runtime bridge fallback event cache |
| `user://godot_dotnet_mcp/logs/user_tool_audit.log` | Log | User Tool audit log |
| User-specified path | JSON | `plugin_developer` import and export of tool configuration |

---

## Plugin Settings File

Path:

```text
user://godot_dotnet_mcp/settings.json
```

Main fields:

| Field | Description |
|---|---|
| `port` | Embedded server port |
| `host` | Listener address |
| `auto_start` | Whether auto-start is enabled |
| `debug_mode` | Whether debug logs are printed |
| `log_level` | Log level |
| `permission_level` | Current permission level |
| `disabled_tools` | Full names of disabled tools |
| `tool_profile_id` | Current selected profile |
| `language` | Current language |
| `show_user_tools` | Whether the User category is shown in the Tools tab |
| `collapsed_categories` | Currently collapsed category list |
| `collapsed_domains` | Currently collapsed domain list |
| `collapsed_system_tools` | System tools collapsed by default in the Tools tab |

Missing fields are filled in at load time by `PluginRuntimeState.build_default_settings()`.

---

## Custom Profile Files

Path:

```text
user://godot_dotnet_mcp/profiles/<slug>.json
```

---

## Cache and Cleanup

The plugin does not automatically clean `user://` on startup, so it will not accidentally delete validation screenshots or diagnostic files that the user still needs. If the Agent needs to clean old root-level cache from earlier versions, it should first call:

```json
{"action": "cleanup_legacy_cache", "dry_run": true}
```

To inspect the currently managed screenshot cache, call `system_userdata_maintenance(action=list_capture_cache)`. To clean the cache files under `captures/editor/`, `captures/editor_controls/`, and `runtime/captures/`, first preview with `system_userdata_maintenance(action=cleanup_capture_cache, dry_run=true)`, then apply with `dry_run=false`. Cache cleanup skips symlink, Windows junction, and reparse point entries and returns them in `skipped_links`.

After the legacy candidates are confirmed, call `system_userdata_maintenance(action=cleanup_legacy_cache, dry_run=false)` explicitly. This entry migrates the old runtime events, User Tool audit logs, and profile files, and deletes old MCP screenshots scattered in the `user://` root.

Current format:

```json
{
	"name": "My Profile",
	"disabled_tools": [
		"scene_scene_run",
		"plugin_evolution_plugin_evolution_delete_user_tool"
	]
}
```

Notes:

- the file name is not the same as the profile id; the profile id is `custom:<slug>`
- `disabled_tools` must be a string array
- renaming a profile writes a new file first, then deletes the old one

---

## Tool Config Import and Export Files

Used by `plugin_developer_export_config` and `plugin_developer_import_config`.

Current format:

```json
{
	"format_version": 1,
	"profile_id": "default",
	"disabled_tools": [
		"scene_scene_run"
	]
}
```

Validation rules:

- `profile_id` cannot be empty
- `disabled_tools` must be a string array
- array items cannot be empty strings

Successful import does not change the file format directly. It reads the data back as structured data and then hands it to plugin state.

---

## Client Config Write Strategy

Desktop client config writing is implemented by `ClientConfigService.write_config_file()`.

The strategy is:

1. Parse the JSON text currently shown in the UI.
2. If the target file already exists, try to read and parse the original JSON.
3. Only touch the `mcpServers` node.
4. Only update the `godot-mcp` entry and do not clear other servers.
5. Create the directory recursively if it does not exist.

That means plugin writes are a minimal merge, not a full-file template overwrite.

---

## CLI Config

CLI clients do not write directly to disk. Instead, the plugin generates command text for clients such as:

- Claude Code
- Codex

Claude Code also distinguishes:

- `user`
- `project`

Changing the scope only affects the generated command text and does not change the other settings.

---

## HTTP CORS Security Configuration

The embedded HTTP MCP service does not use wildcard CORS by default and does not write `Access-Control-Allow-Origin: *` for every response. Local CLI and desktop MCP clients without `Origin` continue to connect directly through `http://127.0.0.1:<port>/mcp`. Browser requests with `Origin` must match the allowlist exactly.

The current allowlist is configured through this environment variable:

```text
GODOT_DOTNET_MCP_ALLOWED_CORS_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

Rules:

- multiple origins are separated by commas or semicolons
- matching is exact only, with no suffix, prefix, or wildcard matching
- `Origin: null` and origins not on the allowlist are rejected
- Host validation allows loopback by default and also allows the current listener host; if `GODOT_DOTNET_MCP_SERVER_HOST` or the settings file switches to a non-default host, CLI and desktop clients still connect directly through that host
- CORS controls browser cross-origin reads only and is not an authentication mechanism; the local HTTP auth token is a future hardening item

---

## Client Install Detection Cache

`ClientInstallDetectionService` keeps a short-lived in-memory cache:

- cache TTL: `5000ms`
- cache contents: client executable path, config entry state, runtime running state
- cache is not written into `user://`

Current invalidation entry points:

- manual selection or clearing of the client path on the Config page
- after Config write or remove completes
- when the Dock switches to the Config page

That means client detection is runtime projection state, not persisted config itself.

---

## Localization Resources

Language resources are not stored in `user://`; they come directly from:

- `localization/locale_*.gd`

Current localization switch flow:

- the settings file stores the selected language
- the plugin restores that language on startup
- all UI text is read through `LocalizationService`

---

## Runtime Bridge Persistence Rules

The runtime bridge is mounted into the project as an Autoload:

- name: `MCPRuntimeBridge`
- path: `res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd`

This is written into Godot project settings, not into the plugin’s own `user://` JSON.

---

## Common Troubleshooting Points

- If changing a scene margin does nothing, first check whether the corresponding tab script still overwrites that property at runtime.
- If profile import fails, first check whether `profile_id` is empty or `disabled_tools` is not a string array.
- If one-click write to a client fails, first check whether the target directory is writable and whether the current JSON can be parsed.
- If a key is shown verbatim after a language switch, first check whether the target `locale_*.gd` file is missing that key.
