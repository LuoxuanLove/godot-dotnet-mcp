此目录用于描述插件 bundled 中心服务包的目标结构。

约定：
- 不放开整个 `central_server/bin/` 到仓库。
- bundled 包应在发布阶段注入到 `dist/plugin-bundled-win-x64/` 中，而不是由打包脚本默认回写源码树。
- 插件安装顺序为：自带安装包 -> 远程 release 安装包 -> 本地源码输出（开发态兜底）。

更新方式：
- 运行 `scripts/publish_central_server.ps1`
- 脚本会生成：
  - `dist/central-server-win-x64/`
  - `dist/plugin-lean/`
  - `dist/plugin-bundled-win-x64/`
- 其中 bundled 包会在 `dist/plugin-bundled-win-x64/` 的 stage 与 zip 中注入中心服务安装包，源码树默认不再被脚本覆盖
