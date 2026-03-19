# Intelligence 工具层

Intelligence 是插件的高层工具域，15 个内置工具覆盖项目状态、场景结构、脚本分析与符号索引四个层面，是 Agent 使用本插件的推荐起点。

默认 Profile（**intelligence**）仅启用此域，足以完成大多数 AI 工作流，无需暴露全量原子工具集。

---

## 文件结构

```
tools/intelligence/
├── executor.gd        # 调度器：初始化 impl + 扫描加载 custom_tools/，路由 execute
├── atomic_bridge.gd   # 原子桥：call_atomic() 调用下层域 executor；写保护逻辑
├── impl_project.gd    # 项目级工具实现（6 个）
├── impl_scene.gd      # 场景级工具实现（3 个）
├── impl_script.gd     # 脚本级工具实现（3 个）
├── impl_index.gd      # 索引与搜索实现（3 个）
└── lsp_client.gd      # Godot LSP 客户端（StreamPeerTCP，供 impl_script 调用）
```

---

## 15 个内置工具

### 项目级（impl_project.gd）

| 工具名 | 功能说明 |
|---|---|
| `intelligence_project_state` | 项目快照：脚本数、场景数、资源数、运行状态、错误统计 |
| `intelligence_project_advise` | 综合诊断：自动检测错误、缺失场景、C# 绑定问题，给出具体可执行的建议 |
| `intelligence_runtime_diagnose` | 收集运行时错误、编译错误、性能快照，提供结构化诊断摘要；`include_gd_errors:true` 可额外读取 Output 面板 GDScript 错误 |
| `intelligence_project_configure` | 读写 ProjectSettings、Autoload 列表、输入映射 |
| `intelligence_project_run` | 通过 EditorInterface 启动主场景或指定场景 |
| `intelligence_project_stop` | 停止当前运行中的项目 |

**典型工作流**：

```
intelligence_project_state     → 了解项目当前状态
  ↓
intelligence_project_advise    → 获取具体改进建议
  ↓
（针对问题使用下方工具）
  ↓
intelligence_runtime_diagnose  → 运行后诊断
```

---

### 场景级（impl_scene.gd）

| 工具名 | 功能说明 |
|---|---|
| `intelligence_scene_validate` | 验证场景文件完整性，检测缺失的依赖资源或脚本 |
| `intelligence_scene_analyze` | 深度分析：节点层级、绑定脚本、@onready 路径、问题列表 |
| `intelligence_scene_patch` | 有序结构化修改场景，支持 `dry_run` 预演 |

**`intelligence_scene_patch` 支持的操作类型**：

| 操作 | 说明 |
|---|---|
| `add_node` | 在指定父节点下添加新节点 |
| `remove_node` | 移除指定节点 |
| `set_property` | 设置节点属性 |
| `attach_script` | 为节点挂载脚本 |
| `reparent_node` | 重新指定节点的父节点 |

`dry_run: true` 时只返回将执行的操作列表，不实际修改。

---

### 脚本级（impl_script.gd）

| 工具名 | 功能说明 |
|---|---|
| `intelligence_bindings_audit` | 审计 C# 脚本的 `[Export]` / `[Signal]` / NodePath 绑定，支持单脚本或全项目扫描 |
| `intelligence_script_analyze` | 分析脚本结构：方法、导出字段、信号、变量、场景引用、继承链；`.gd` 文件支持 `include_diagnostics:true` 获取 LSP 静态诊断 |
| `intelligence_script_patch` | 修改 `.gd` 或 `.cs` 脚本，支持 `dry_run` 预演 |

**`intelligence_script_patch` 支持的操作类型**：

| 操作 | 说明 |
|---|---|
| `add_method` | 添加方法 |
| `add_export` | 添加 export 字段 |
| `add_signal` | 添加信号 |
| `add_variable` | 添加变量 |

**`intelligence_script_analyze` LSP 静态诊断**：

当 `include_diagnostics: true` 且脚本为 `.gd` 时，`lsp_client.gd` 会通过 loader 持有的后台诊断服务连接 Godot 内置 LSP（`127.0.0.1:6005`），返回 GDScript 解析错误与警告：

```json
"diagnostics": {
  "available": true,
  "pending": false,
  "finished": true,
  "phase": "ready",
  "parse_errors": [
    {"severity": "error", "message": "...", "line": 12, "column": 4, "length": 10}
  ],
  "error_count": 1,
  "warning_count": 0
}
```

- 同次返回还会附带轻量 `diagnostics_status`，仅说明 `source / available / pending / finished / phase`
- 首次调用可能返回 `pending: true`，随后再次调用即可读取后台回填结果
- Godot LSP 未运行时：`available: false`，不影响其余分析字段
- 仅支持 `.gd` 文件，`.cs` 请使用 `intelligence_bindings_audit` 或 `debug_dotnet`
- 详细运行态自检统一通过 `plugin_runtime_state(action=get_lsp_diagnostics_status)` 读取，不在 Intelligence 返回里展开插件内部快照

---

### 索引级（impl_index.gd）

| 工具名 | 功能说明 |
|---|---|
| `intelligence_project_index_build` | 构建项目全量内存索引：脚本、场景、资源、符号 |
| `intelligence_project_symbol_search` | 在已建索引中精确或模糊搜索符号 |
| `intelligence_scene_dependency_graph` | 生成场景依赖图；可指定根场景与遍历深度 |

**使用顺序**：先调用 `intelligence_project_index_build` 建立索引，再调用 `intelligence_project_symbol_search` 搜索。索引存在内存中，重载插件后需重建。

---

## Atomic Bridge

**路径**：`tools/intelligence/atomic_bridge.gd`

Intelligence 层的 impl 不直接操作 Godot API，而是通过 Atomic Bridge 调用下层原子域 executor：

```
impl_*.gd
  → bridge.call_atomic(executor_name, tool_name, args)
    → 动态加载 tools/<executor_name>/executor.gd
      → 执行对应原子工具
```

Bridge 注入方式：`executor.gd._init()` 时执行 `impl.bridge = _bridge`，所有 impl 共享同一个 bridge 实例。

**写保护**：Bridge 检查 action 关键字与目标路径，阻止通过 Intelligence 工具直接写入 `res://addons/godot_dotnet_mcp/` 内置目录（`custom_tools/` 除外）。

**辅助方法**（供 impl 使用）：

| 方法 | 用途 |
|---|---|
| `extract_data(result, key)` | 安全提取工具返回中的数据字段 |
| `extract_array(result, key)` | 安全提取数组字段 |
| `collect_files(dir, ext)` | 递归收集指定扩展名的文件 |
| `build_issue(severity, message, path)` | 构建标准问题对象 |
| `append_unique_issue(issues, issue)` | 去重追加问题 |
| `has_severity(issues, level)` | 检查问题列表中是否含指定严重程度 |
| `normalize_dependency_path(path)` | 标准化依赖路径格式 |

---

## User 工具扩展

Intelligence executor 在 `_init()` 时除加载 impl 外，还会扫描 `custom_tools/` 目录，加载符合规范的用户工具脚本。

**接口要求**：

```gdscript
func handles(tool_name: String) -> bool
func get_tools() -> Array      # 每项须包含 "name" 字段
func execute(tool_name: String, args: Dictionary) -> Dictionary
```

**校验规则**（三步，全部通过才加载）：
1. 脚本可实例化
2. 具备 `handles`、`get_tools`、`execute` 三个方法
3. `get_tools()` 返回的所有工具名以 `user_` 开头

详细说明见 [docs/模块/用户扩展.md](用户扩展.md)。

---

## Tools 页展示逻辑

Intelligence 工具在 `MCPDock > Tools` 页顶层平铺，不折叠在 Core 域树内。

- `collapsed_intelligence_tools` 设置项控制哪些工具默认折叠（默认全部 15 个工具折叠）
- 点击工具名展开可查看参数与描述
- Shift + 点击递归展开或折叠

默认 Profile **intelligence** 仅启用此域。如需同时使用原子工具（scene、script、node 等），切换至 **task** 或 **default** Profile。

---

## 与原子工具的关系

| 层级 | 工具类型 | 操作粒度 |
|---|---|---|
| Intelligence 层 | 高层复合工具 | 读取上下文、分析结构、批量修改、诊断建议 |
| 原子层（各域 executor）| 单一操作工具 | 创建节点、读取属性、写入文件等 |

Intelligence 工具通过 Atomic Bridge 组合调用原子工具。需要超出 Intelligence 层能力的精细控制时，直接使用原子工具。
