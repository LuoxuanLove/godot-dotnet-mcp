## 🧩 Godot .NET MCP v1.0.1: Sharper Tool Browsing and Resource Audits

Godot .NET MCP `v1.0.1` is a focused maintenance release for users on `v1.0.0`. It keeps the same Godot 4.6+ .NET target and installation paths while tightening two visible parts of the plugin experience: browsing tools in the Dock and diagnosing C# custom `Resource` references.

### 🛠️ Clearer Tools Dock Reading

The Tools tab preview pane now fills the lower split area with the selected item description instead of leaving unused blank space. When agents or developers browse the Dock tool tree, the reference area should feel more complete and easier to read without changing the tool surface itself.

### 🔎 More Accurate C# Resource Audits

`system_resource_reference_audit` now resolves C# `[GlobalClass] Resource` scripts through Roslyn `types[]` metadata before falling back to script inspection. Valid custom resource scripts should no longer be reported as unresolved just because a `.tres` script class could not be connected to its C# type through the older path.

Resource reference parsing is also more precise for `.tres` and `.tscn` files: unquoted `ExtResource id=` declarations are recognized, `id=` text inside quoted attribute values is ignored, and missing IDs are distinguished from IDs that point to non-Script resources. The result is cleaner diagnostics when custom resources are involved.

### Compatibility and Upgrade Notes

`v1.0.1` keeps the existing Godot 4.6+ .NET requirement, Asset Library installation path, direct `addons/godot_dotnet_mcp/` source-copy installation path, and stable high-level `system_*` tool surface. Upgrade from `v1.0.0` when you want the Tools Dock layout correction and more reliable C# resource audit results.