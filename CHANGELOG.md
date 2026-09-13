# 更新记录

## 未发布

- 修正克隆版菜单的应用列表为空：clone 取不到 shell 的 appLibrary 时，改用本地 AppLibrary 后备。
- Agents 状态栏新增 Grok Build 与 Kimi Code 的订阅用量和限额展示。
- 为 Grok、Kimi 增加随 Omarchy 主题切换的浅色与深色图标。
- 兼容新版 Codex CLI 的审批策略，并延长 app-server 初始化等待时间。
- 安装与更新后同步会自动重新应用 Agents 扩展；卸载时一并清理。

## 0.1.0 - 2026-08-20

- 首次公开版本。
- 汉化 22 个 Omarchy 4 用户插件克隆。
- 汉化主菜单、快捷键面板和 Omarchy 动态通知。
- 日期与星期使用 `zh_CN` 区域格式。
- 天气默认使用摄氏度和 `km/h`。
- 增加安装、卸载、更新后同步和静态检查脚本。
