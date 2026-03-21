此目录用于存放随插件 release 一起分发的中心服务安装包。

约定：
- 不放开整个 `central_server/bin/` 到仓库。
- 仅放置正式打包后的发布 zip 与对应的 `.sha256`。
- 插件安装顺序为：自带安装包 -> 远程 release 安装包 -> 本地源码输出（开发态兜底）。

更新方式：
- 运行 `scripts/publish_central_server.ps1`
- 脚本会自动生成 release zip，并同步覆盖本目录中的最新安装包
