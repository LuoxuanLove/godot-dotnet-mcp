# .NET 支持

## 支持范围

当前 `.NET` 支持聚焦于编辑器内静态分析与场景绑定检查，而不是 C# 代码生成或完整语义编译。

已支持：

- 读取 `.cs` 文件文本
- 在脚本编辑器中打开 `.cs`
- 识别 `namespace`
- 识别 `class`
- 识别 `partial class`
- 识别基类
- 识别 public method
- 识别 enum
- 识别 `[Export]` 字段和属性
- 识别 `[ExportGroup]`
- 在场景分析中读取导出成员的绑定状态

## 操作说明

### 查看 C# 脚本结构

推荐调用：

1. `system_script_analyze`
2. `system_bindings_audit`

需要下钻时，再补充：

- `script_inspect`
- `script_symbols`
- `script_exports`

典型场景：

- 确认某个 `partial class` 是否仍然挂在期望基类上
- 查看 `namespace`、`class`、`method` 和 `[Export]` 是否被识别
- 把 Inspector 里看到的字段名和脚本中的导出成员做对应

### 检查场景绑定

推荐调用：

1. `system_bindings_audit`
2. `system_scene_analyze`

需要下钻时，再补充：

- `scene_bindings`
- `scene_audit`

典型场景：

- 场景节点的 `[Export] NodePath`、资源引用或数值字段没有生效
- 节点脚本看起来正常，但 Inspector 中字段为空
- 想把 Godot 场景问题定位到具体 C# 脚本的导出声明

### 回到编辑器人工修复

推荐调用：

1. `system_script_analyze`
2. `script_open.open`
3. `script_open.open_at_line`

用途：

- 从结构化分析结果回到真实脚本
- 让 MCP 辅助定位，人来完成最终修改

## 典型用途

- 检查场景里的 C# 导出引用是否为空
- 查看某脚本暴露给场景的公共结构
- 快速提取导出字段用于自动检查
- 对比脚本声明与场景绑定的实际结果

## 实现方法

### 为什么是 syntax-first 而不是完整语义分析

当前实现目标是“在 Godot 编辑器进程内稳定返回可用结构”，因此采用插件内 Roslyn 的 syntax-first 路线，而不是引入完整 SemanticModel / 项目级语义分析。这样做的原因：

- 插件需要在编辑器内直接工作，不依赖外部编译过程或独立后台宿主
- 目标是导出字段、类信息和场景绑定，而不是完整语言服务
- 返回速度和可移植性优先于完整语义覆盖

### 当前实现链路

1. `addons/godot_dotnet_mcp/dotnet_bridge/` 与 `plugin/runtime/roslyn/*` 提供插件内 Roslyn 语法分析核心。
2. `tools/script/csharp_edit_service.gd`、`tools/script/inspect_service.gd` 与 system 脚本入口读取 `.cs` 文件文本并接入 Roslyn façade。
3. Roslyn 路径提取 `namespace`、`class`、`partial class`、`base_type`、`method`、`enum`、`[Export]`、`[ExportGroup]` 与 parse errors。
4. `tools/scene/bindings_service.gd` 读取场景中的脚本实例与导出值。
5. `scene_bindings` / `scene_audit` 将声明与实际绑定状态关联起来。

### 适用边界

当前实现更适合：

- Godot 常规 Mono / .NET 游戏脚本
- 导出字段审计
- 场景绑定排查
- 结构化浏览脚本表面信息

当前实现不适合：

- 跨文件继承链推导
- 泛型约束和复杂属性访问器语义分析
- 条件编译分支下的完整成员解析
- 自动重写大型 C# 文件

## 非目标能力

当前不提供：

- Roslyn 级语义分析
- 跨程序集符号解析
- 任意 C# AST 级改写
- 通用 C# 代码生成工作流

## 与 GDScript 的关系

GDScript 仍保留必要支持：

- 读取
- 打开
- 导出与符号分析
- 有限编辑

但插件的接口组织不再以 GDScript 为中心，而是以 Godot 项目的通用脚本工作流为中心。

## 排障建议

- 如果 `script_exports` 看不到 `[Export]` 字段，先确认属性或字段写法是否处于当前支持范围。
- 如果 `scene_bindings` 能看到脚本却拿不到导出值，优先怀疑场景实例绑定或导出提取逻辑，而不是直接怀疑用户未绑定。
- 如果要做大规模 C# 改写，当前工具集不适合，应该转为外部专门代码修改流程。
