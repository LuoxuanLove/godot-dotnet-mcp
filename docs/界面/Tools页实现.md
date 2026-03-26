# Tools 页实现

本文档说明 [tools_tab.tscn](/E:/Project/Mechoes/addons/godot_dotnet_mcp/ui/tools_tab.tscn) 与 [tools_tab.gd](/E:/Project/Mechoes/addons/godot_dotnet_mcp/ui/tools_tab.gd) 的节点结构、工具树、预览面板与当前布局约束。

---

## 目标职责

`Tools` 页当前聚焦四类能力：

1. 显示当前已启用的工具数
2. 以 `system` / `user` 根分组展示当前公开工具
3. 展开查看 `system_*` 工具依赖的原子工具链路
4. 展示当前选中项的描述、参数、运行时信息与原子工具预览

当前页不再承担 profile 选择、保存、重命名、删除。

---

## 场景结构

当前 `tools_tab.tscn` 主要分为两段：

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

已移除的旧节点：

- `ProfileRow`
- `ToolProfileDescription`
- `SaveProfileDialog`
- `DeleteProfileDialog`

---

## 系统工具树

当前树结构固定为：

```text
root
  ├─ system
  │   ├─ system_project_state
  │   │   ├─ project_info
  │   │   ├─ project_dotnet
  │   │   ├─ filesystem_directory
  │   │   └─ debug_runtime_bridge
  │   ├─ system_project_suggest
  │   ├─ system_runtime_capture
  │   └─ ...
  └─ user
      ├─ user_tool_a
      └─ user_tool_b
```

说明：

- 根下固定先渲染 `system` 与 `user` 两个根分组
- 当前仍保留 category / domain 元数据与信号语义，但主树默认不渲染独立 domain 节点
- 原子工具节点可继续递归展开
- 原子工具的勾选行为沿用普通工具行逻辑，仍通过 `tool_toggled` 回流

---

## 控制器职责

[tools_tab.gd](/E:/Project/Mechoes/addons/godot_dotnet_mcp/ui/tools_tab.gd) 当前负责：

- 接收 model 并刷新文案
- 构建 `system` / `user` 根分组与 TreeItem
- 根据 `SYSTEM_TOOL_ATOMIC_CHILDREN` 构建原子工具子树
- 管理当前选中项、上下文菜单和预览区滚动恢复
- 发出工具启停与展开折叠信号
- 在极小尺寸下裁剪树区和预览区内容

当前主控制器已经不再持有全部纯逻辑 helper。以下协作者已独立：

- `ui/tools_tab_context_menu_support.gd`
- `ui/tools_tab_model_support.gd`
- `ui/tools_tab_selection_support.gd`
- `ui/tools_tab_search_service.gd`
- `ui/tools_tab_preview_builder.gd`

不负责：

- profile 持久化
- profile UI 交互
- server 生命周期控制
- 客户端配置生成

---

## 搜索实现

`ToolSearchEdit.text_changed` 会驱动树重建。

当前搜索策略：

- 系统工具名称命中时保留该工具
- 原子工具名称或描述命中时，保留其所属的 系统祖先
- 搜索会递归命中 `SYSTEM_TOOL_ATOMIC_CHILDREN`，因此搜索原子工具也能定位到上层 系统工具
- 当前过滤结果先由 `tools_tab_search_service.gd` 预计算，再由主控制器按分组渲染

搜索不会改写持久化折叠状态，只影响当前树重建结果。

---

## 预览面板实现

预览区仍使用只读 `TextEdit`。

当前预览对象包括：

- domain
- category
- tool
- atomic
- action

其中 系统工具级预览会额外展示：

- 描述
- action 概览
- 参数 schema 简述
- 递归原子工具列表
- “该工具可展开查看原子工具”的引导文案

---

## 分界与阴影实现

### 分界

树区与预览区由 `ContentSplit` (`VSplitContainer`) 管理。脚本不强行覆盖 `split_offset`，后续布局微调优先改 `.tscn`。

### 阴影

树区顶部和底部阴影由：

- `TopShadow`
- `BottomShadow`

配合 `_configure_tree_shadow()` 初始化 shader，运行时根据滚动位置显示或隐藏。

---

## 极小高度保护

在极小高度下，当前实现有两层保护：

1. 通过较低的 `custom_minimum_size` 让树区与预览区都能继续缩小
2. 给 `TopPane`、`BottomPane`、工具树面板和预览面板开启 `clip_contents`

这样优先表现为内容被裁剪，而不是互相越界覆盖。

---

## 当前 UI 约束

当前 `tools_tab.gd` 已移除 profile 相关运行时覆盖，因此：

- 搜索框上下间距
- 工具树上下留白
- 预览区与分隔线距离

都应优先在 [tools_tab.tscn](/E:/Project/Mechoes/addons/godot_dotnet_mcp/ui/tools_tab.tscn) 中手动修改。

脚本仍保留的 UI 级控制主要是：

- 控件最小高度
- 树列宽
- 阴影尺寸

---

## 相关文件

| 路径 | 作用 |
|---|---|
| `ui/tools_tab.tscn` | Tools 页节点树与布局 |
| `ui/tools_tab.gd` | Tools 页主控制器 |
| `ui/tools_tab_context_menu_support.gd` | Tools 页上下文菜单辅助 |
| `ui/tools_tab_model_support.gd` | Tools 页共享模型辅助 |
| `ui/tools_tab_selection_support.gd` | Tools 页选择状态辅助 |
| `ui/tools_tab_search_service.gd` | Tools 页搜索协作者 |
| `ui/tools_tab_preview_builder.gd` | Tools 页预览协作者 |
| `tools/system_tools.gd` | 系统高层工具实现 |
| `tools/tool_manifest_data.gd` | 默认工具暴露策略与 domain/category 纯静态数据层 |
| `tools/tool_manifest.gd` | 默认工具暴露策略与 manifest 访问层 |
| `plugin/runtime/plugin_runtime_state.gd` | 当前 settings / custom profile 状态 |
| `plugin/runtime/tool_permission_policy.gd` | permission 规则 |
| `plugin/runtime/tool_profile_catalog.gd` | builtin profile 目录 |
