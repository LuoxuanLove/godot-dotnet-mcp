# .NET Support

## Scope

Current `.NET` support focuses on in-editor static analysis and scene binding checks, not on C# code generation or full semantic compilation.

Supported today:

- reading `.cs` file text
- opening `.cs` files in the script editor
- recognizing `namespace`
- recognizing `class`
- recognizing `partial class`
- recognizing base types
- recognizing public methods
- recognizing enums
- recognizing `[Export]` fields and properties
- recognizing `[ExportGroup]`
- reading exported member binding state during scene analysis

## How to Use It

### View C# script structure

Recommended calls:

1. `bindings_audit`
2. `scene_analyze`

For deeper inspection, add:

- `script_inspect`
- `script_symbols`
- `script_exports`

Typical cases:

- confirm whether a `partial class` still uses the expected base type
- check whether `namespace`, `class`, `method`, and `[Export]` are being recognized
- map Inspector field names to exported members in the script

### Check scene bindings

Recommended calls:

1. `bindings_audit`
2. `scene_analyze`

For deeper inspection, add:

- `bindings`
- `audit`

Typical cases:

- a scene node's `[Export] NodePath`, resource reference, or value field does not take effect
- the node script looks correct, but the field is empty in the Inspector
- you want to trace a Godot scene issue back to a concrete C# export declaration

### Return to manual editor repair

Recommended calls:

1. `scene_analyze`
2. `script_open.open`
3. `script_open.open_at_line`

Use this to:

- move from structured analysis back to the real script
- let MCP help with the location, while a human performs the final edit

## Typical Uses

- check whether a C# export reference in a scene is empty
- inspect the public structure exposed by a script to a scene
- quickly extract exported fields for automated checks
- compare script declarations with the actual scene binding result

## Implementation Notes

### Why syntax-first instead of full semantic analysis

The implementation goal is to return useful structure reliably inside the Godot editor process, so the plugin uses a syntax-first Roslyn path inside the Godot .NET runtime instead of a full SemanticModel or project-level semantic analysis. The reasons are:

- the plugin must work directly inside the editor and must not depend on an external compile step or separate background host
- the goal is exported fields, class information, and scene bindings, not a full language service
- response speed and portability are more important than complete semantic coverage

### Current pipeline

1. `addons/godot_dotnet_mcp/dotnet_bridge/` and `plugin/runtime/roslyn/*` provide the plugin-local Roslyn syntax-analysis core.
2. `tools/script/csharp_edit_service.gd`, `tools/script/inspect_service.gd`, and the system script entry points read `.cs` file text and connect to the Roslyn facade.
3. The Roslyn path extracts `namespace`, `class`, `partial class`, `base_type`, `method`, `enum`, `[Export]`, `[ExportGroup]`, and parse errors.
4. `addons/godot_dotnet_mcp/tools/scene_tools.gd` implements the scene-level binding tools, while `tools/system/impl_scene.gd` and `tools/system/impl_script.gd` bridge the higher-level audit flow to those scene and script entry points.
5. `bindings` and `audit` tie the declaration state to the actual binding state.

### Best fit

This implementation is best for:

- standard Godot Mono and .NET gameplay scripts
- export-field auditing
- scene binding troubleshooting
- structured inspection of script surface information

This implementation is not a good fit for:

- cross-file inheritance chain inference
- generic constraints and complex property accessor semantics
- full member parsing under conditional compilation branches
- automatically rewriting large C# files

## Non-Goals

Current non-goals:

- Roslyn-level semantic analysis
- cross-assembly symbol resolution
- arbitrary C# AST rewriting
- a generic C# code-generation workflow

## Relationship with GDScript

GDScript still keeps the necessary support:

- read
- open
- export and symbol analysis
- limited editing

But the plugin interface is no longer centered on GDScript. It is centered on the general script workflow used by Godot projects.

## Troubleshooting Tips

- If `script_exports` does not show `[Export]` fields, first check whether the property or field syntax is in the supported range.
- If `bindings` can see the script but cannot read the exported value, first suspect the scene instance binding or the export extraction logic, not the user?s binding.
- If you need large-scale C# rewrites, the current tool set is not suitable. Switch to a dedicated external code modification flow instead.
