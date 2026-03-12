# Tools 页实现

本文档说明 `ui/tools_tab.tscn` 与 `ui/tools_tab.gd` 的节点结构、树构建逻辑、预设管理、预览面板和当前布局约束。

---

## 目标职责

`Tools` 页负责五类能力：

1. 显示当前已启用工具数
2. 选择、保存、重命名、删除工具预设
3. 按 `domain -> category -> tool` 三层树结构启停工具
4. 搜索工具与分类
5. 展示当前选中项的描述、参数与 action 概览

---

## 场景结构

当前 `tools_tab.tscn` 主要分为三段：

```text
ToolsTab
  ├─ HeaderMargin
  │   └─ HeaderContent
  │       ├─ ToolCountLabel
  │       ├─ ProfileRow
  │       ├─ ToolProfileDescription
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

当前设计要点：

- 头部操作区与树区拆开，避免 profile 操作和搜索区互相干扰
- 下半区通过 `VSplitContainer` 支持树区与预览区的拖拽分界
- 树区上下阴影不依赖主题资源，而由 `ColorRect + ShaderMaterial` 绘制

---

## 控制器职责

`tools_tab.gd` 当前负责：

- 接收 model 并刷新文案
- 重建 profile 下拉
- 构建和刷新树
- 管理搜索关键字与命中结果
- 管理当前选中项和预览文本
- 发出用户操作信号
- 在极小尺寸下裁剪树区和预览区内容

不负责：

- 持久化 profile
- 真正启停 server
- 计算客户端配置

---

## 树数据来源

`plugin.gd` 传入的 model 中，树构建主要依赖：

- `tools_by_category`
- `domain_defs`
- `disabled_tools`
- `collapsed_categories`
- `collapsed_domains`
- `show_user_tools`
- `search_text`

控制器重建树时会：

1. 先创建隐藏 root。
2. 遍历 `domain_defs`，筛出命中的 category。
3. 为每个 domain 创建 domain item。
4. 为每个 category 创建 category item。
5. 为每个 tool 创建叶子项，并配置：
   - 文本
   - tooltip
   - metadata
   - 勾选框状态
   - 部分启用 / 加载异常视觉状态

---

## 选中与勾选分流

当前 `Tree` 采用双列语义：

- 文本列：承载树层级、文本显示、选中高亮和预览元数据
- 勾选列：承载启停勾选

这样做的目的有两个：

- 避免 checkbox 点击与文本选中互相抢事件
- 保持文字缩进仍由标准树层级渲染

当前控制器会把：

- 点击文本列 -> 视为选中项变更，刷新预览
- 点击勾选列 -> 视为启停操作，发出 `tool_toggled/category_toggled/domain_toggled`

---

## 搜索实现

`ToolSearchEdit.text_changed` 会驱动搜索刷新。搜索命中策略是：

- category 名称命中时保留整类
- tool 名称命中时保留工具及其祖先路径
- domain 本身不单独作为搜索目标，而由其下 category 是否命中决定是否显示

搜索结果不会改写持久化折叠状态，只影响当前树重建结果。

---

## 预设管理实现

头部 Profile 区域通过以下信号回流到 `plugin.gd`：

- `profile_selected`
- `save_profile_requested`
- `rename_profile_requested`
- `delete_profile_requested`

按钮启用状态由控制器根据当前选中 profile 是否是自定义 profile 决定。内置 profile 只允许应用，不允许改名或删除。

---

## 预览面板实现

当前预览区使用只读 `TextEdit`，而不是 `RichTextLabel`。原因是：

- 文本内容更稳定
- 自动换行与复制更直接
- 在多轮回归后，`TextEdit.set_text()` 的表现更稳定

预览面板展示对象包括：

- domain
- category
- tool

其中 tool 级预览会尽量展示：

- 描述
- 可用 action
- 参数 schema 的简要结构

---

## 分界与阴影实现

### 分界

树区与预览区由 `ContentSplit` (`VSplitContainer`) 管理。脚本不再强行覆盖 `split_offset`，因此：

- 手动拖动的位置保留在场景与运行时容器分配中
- 后续布局微调应优先改 `.tscn`

### 阴影

树区顶部和底部阴影由：

- `TopShadow`
- `BottomShadow`

配合 `_configure_tree_shadow()` 初始化 shader，运行时根据滚动位置显示或隐藏。

显示规则：

- 顶部已向下滚动时显示上阴影
- 底部仍有隐藏内容时显示下阴影

---

## 极小高度保护

在极小高度下，当前实现有两层保护：

1. 通过较低的 `custom_minimum_size` 让树区与预览区都能继续缩小
2. 给 `TopPane`、`BottomPane`、工具树面板和预览面板开启 `clip_contents`

这样即使可用高度继续下降，也会优先发生“内容被裁剪”，而不是互相越界覆盖。

---

## 当前 UI 调整约束

当前 `tools_tab.gd` 已移除绝大多数普通 margin / separation 的运行时覆盖，因此：

- 搜索框上下间距
- 工具树上下留白
- 预览区与分隔线距离

都应优先在 `tools_tab.tscn` 中手动修改。

脚本仍保留的 UI 级控制主要是：

- 控件最小高度
- 树列宽
- 阴影尺寸

---

## 相关文件

| 路径 | 作用 |
|---|---|
| `ui/tools_tab.tscn` | Tools 页节点树与布局 |
| `ui/tools_tab.gd` | Tools 页控制器 |
| `plugin/runtime/tool_catalog_service.gd` | profile 比对、计数与分类辅助 |
| `plugin/config/settings_store.gd` | profile 与导入导出配置持久化 |
