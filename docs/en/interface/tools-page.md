# Tools Tab Implementation

This document explains the node structure, tool tree, preview panel, and current layout constraints for `addons/godot_dotnet_mcp/ui/tools_tab.tscn` and `addons/godot_dotnet_mcp/ui/tools_tab.gd`.

---

## Target Responsibilities

The current `Tools` tab focuses on four capabilities:

1. show the current enabled tool count
2. consume the runtime-generated Tool Presentation Model and display the current tools in the `domain -> category -> tool -> atomic/action` hierarchy
3. expand the atomic tool chain used by `system_*` tools
4. show the description, parameters, runtime info, and atomic-tool preview for the selected item

This tab no longer handles profile selection, saving, renaming, or deletion.

---

## Scene Structure

The current `tools_tab.tscn` is split into two main parts:

```text
ToolsTab
  ├─ HeaderMargin
  │   └─ HeaderContent
  │       ├─ ToolCountLabel
  │       ├─ ActionsRow
  │       └─ UserActionsRow
  └─ ContentSplit (VSplitContainer)
      ├─ TopPane
      │   ├─ SearchSeparator
      │   ├─ SearchOuterMargin
      │   │   └─ ToolSearchEdit
      │   ├─ ToolListOuterMargin
      │   │   └─ ToolListPanel
      │   │       └─ ToolListOverlay
      │   │           ├─ ToolListMargin
      │   │           │   └─ ToolTree
      │   │           ├─ TopShadow
      │   │           └─ BottomShadow
      │   └─ PreviewSeparator
      └─ BottomPane
          └─ PreviewOuterMargin
              └─ ToolPreviewPanel
                  └─ ToolPreviewMargin
                      └─ ToolPreviewContent
                          ├─ ToolPreviewTitle
                          └─ ToolPreviewText
```

Removed old nodes:

- `ProfileRow`
- `ToolProfileDescription`
- `SaveProfileDialog`
- `DeleteProfileDialog`

---

## System Tool Tree

The current tree is generated from the runtime Tool Presentation Model. The main hierarchy is:

```text
root
  ├─ core
  │   ├─ system
  │   │   ├─ system_editor_state
  │   │   │   ├─ editor_status
  │   │   │   ├─ editor_inspector
  │   │   │   ├─ editor_filesystem
  │   │   │   ├─ debug_runtime_bridge
  │   │   │   └─ debug_dotnet
  │   │   ├─ system_project_index_build
  │   │   │   ├─ filesystem_directory
  │   │   │   ├─ script_inspect
  │   │   │   └─ resource_query
  │   │   ├─ system_runtime_control
  │   │   │   ├─ status / enable / disable
  │   │   │   └─ runtime_control
  │   │   ├─ system_runtime_step
  │   │   │   ├─ step / capture / input
  │   │   │   ├─ runtime_step
  │   │   │   ├─ runtime_capture
  │   │   │   └─ runtime_input
  │   │   ├─ system_tool_activity
  │   │   │   ├─ status / recent / get
  │   │   │   └─ self-reported _mcp_context activity
  │   │   ├─ system_dap_debugger
  │   │   │   ├─ status / get_settings / set_settings / initialize / launch / attach / configuration_done / threads / disconnect
  │   │   │   ├─ set_breakpoint / remove_breakpoint / pause / continue / step_over / stack_trace / output / terminate
  │   │   │   └─ dap_debugger
  │   │   └─ ...
  │   └─ ... internal atomic categories
  └─ user
      └─ user
          ├─ user_tool_a
          └─ user_tool_b
```

Notes:

- the root first renders domain nodes and then category nodes. `system` and `user` are no longer hard-coded root nodes
- `system_*` high-level tools expand through `SystemTreeCatalog` into their real atomic and action chains. For example, `system_editor_control` shows control-local click actions such as `click_control` / `right_click_control` and top menu actions such as `list_menus` / `open_menu` / `select_menu_item`
- `system_tool_activity` reports activity recorded at the shared execution layer. Optional `_mcp_context` is stripped before concrete tool execution and treated as self-reported coordination metadata, not as authentication or a per-tool schema field
- `runtime_*` is an internal atomic category. It is only shown as a child chain of `system_runtime_*`, and it is not exposed as an MCP tool by itself
- atomic tool nodes can keep expanding recursively
- the check state for atomic tools follows the same logic as normal tool rows and still flows back through `tool_toggled`

---

## Right-Click Menu and Popup Coordinate Contract

The Tools tab currently creates one Dock-local `PopupMenu` on the tool tree. It is used to copy names, English IDs, schemas, or to expand or collapse tree nodes. The `mouse_event.position` received by `Tree.gui_input` is in the local coordinates of `ToolTree`, and it cannot be passed directly into `PopupMenu.popup(Rect2i)`.

The coordinate boundaries are:

- **local**: the local coordinates of a `Control`, such as `mouse_event.position` in `ToolTree.gui_input`
- **canvas global**: canvas coordinates after the `Control` or `CanvasItem` transform. They can be obtained through paths such as `get_global_transform_with_canvas()`. They are suitable for hit testing and viewport input conversion
- **viewport**: coordinates inside the current `Viewport`, used for `Viewport.push_input()`, screenshot cropping, and visible-area conversion
- **screen**: screen coordinates. `PopupMenu.popup(Rect2i)` and similar editor popup positioning entries must use screen coordinates. Here this only refers to Godot popup placement, not desktop window control

So popup positioning must go through a testable helper such as `_get_tree_context_menu_screen_position(local_position)`, and use `ToolTree.get_screen_transform() * local_position` or an equivalent local-to-screen transform. Do not pass `mouse_event.position`, `get_screen_position() + local_position`, or a canvas-global coordinate directly to `popup(Rect2i)`. If you add another Dock-local `PopupMenu` or `PopupPanel` later, wrap it in the same kind of helper first and add a light contract test.

---

## Controller Responsibilities

`tools_tab.gd` currently handles:

- receiving the model and refreshing the text
- preferring `toolTree`, `toolGroups`, and `tool_presentation` from the model to build `TreeItem`
- falling back to the old local-tree rebuild logic only when the presentation model is missing
- tracking the selected item, the context menu, and preview scroll restoration
- emitting tool toggle and expand or collapse signals
- trimming the tree area and preview area in very small layouts

The main controller no longer holds every pure-logic helper. These collaborators have already been split out and then folded back into the main controller where appropriate:

- the current responsibilities now live in `ui/tools_tab.gd` as the main controller

It does not handle:

- profile persistence
- profile UI interaction
- server lifecycle control
- client config generation

---

## Search Implementation

`ToolSearchEdit.text_changed` drives tree rebuilding.

Current search strategy:

- when a system tool name matches, keep that tool
- when an atomic tool name or description matches, keep its system ancestors
- the search recursively matches `SYSTEM_TOOL_ATOMIC_CHILDREN`, so searching an atomic tool can still locate the higher-level system tool
- the current filtered result is computed directly inside `tools_tab.gd`, then rendered by group

Search does not rewrite persistent collapse state. It only changes the current tree rebuild result.

---

## Preview Panel Implementation

The preview area still uses a read-only `TextEdit`.

Current preview targets include:

- domain
- category
- tool
- atomic
- action

System-tool previews also show:

- description
- action overview
- parameter schema summary
- recursive atomic-tool list
- a hint that the tool can be expanded to inspect atomic tools

---

## Split and Shadow Implementation

### Split

The tree area and the preview area are managed by `ContentSplit` (`VSplitContainer`). The script no longer forces `split_offset`. Future layout tuning should be done in the `.tscn` first.

### Shadow

The top and bottom shadows of the tree area are initialized through:

- `TopShadow`
- `BottomShadow`

They are paired with `_configure_tree_shadow()` and show or hide at runtime depending on the scroll position.

---

## Minimum-Height Protection

There are two protection layers for very small heights:

1. use a lower `custom_minimum_size` so the tree area and preview area can keep shrinking
2. enable `clip_contents` for `TopPane`, `BottomPane`, the tool-tree panel, and the preview panel

This makes content clip first instead of overlapping or escaping the layout.

---

## Current UI Constraints

`tools_tab.gd` no longer applies profile-related runtime overrides. So these should be tuned in `tools_tab.tscn` first:

- the vertical spacing around the search box
- the vertical padding around the tool tree
- the distance between the preview area and the separator

The main UI-level controls that remain in the script are:

- control minimum height
- tree column width
- shadow size

---

## Related Files

| Path | Purpose |
|---|---|
| `ui/tools_tab.tscn` | Tools tab node tree and layout |
| `ui/tools_tab.gd` | Main Tools tab controller, containing context menu, model, selection, search, and preview logic |
| `tools/system/executor.gd` and `tools/system/impl_*.gd` | Current system high-level tool scheduling and implementation entry points |
| `tools/tool_registry.gd` | Builtin executor registration source |
| `tools/tool_manifest.gd` | Domain and category metadata access layer |
| `plugin/runtime/plugin_runtime_state.gd` | Current settings and custom-profile state |
| `plugin/runtime/tool_profile_catalog.gd` | Builtin profile catalog |
