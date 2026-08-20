# Omarchy 简体中文界面

面向 Omarchy 4 的非官方简体中文本地化项目。它从本机当前安装的 Omarchy 源文件生成用户级插件克隆，不修改 `/usr/share/omarchy`，也不在仓库中重新分发 Omarchy 的插件源码。

## 已汉化内容

- Omarchy 主菜单及 300 多个菜单项目
- 状态栏、插件设置和常用面板
- 音频、蓝牙、网络、显示器、电源和天气
- 日期、月份、星期及日历
- 天气使用摄氏度，风速使用 `km/h`，地名保持数据源原文
- 提醒、通知历史和 Omarchy 动态通知
- 剪贴板、表情、图片选择器、测速和 Wi-Fi 二维码
- 锁屏、权限认证和系统更新提示
- `Super + K` 快捷键面板及功能说明
- Omarchy 更新后的自动重新同步

专有名称、命令、真实文件路径和第三方应用内容不会强制翻译，例如 Omarchy、Hyprland、Codex、DNS、Docker 和 `Downloads`。

## 兼容性

- Omarchy `4.x`
- Node.js、jq（Omarchy 4 默认环境已提供）
- 需要正在运行的 Omarchy Shell

本项目跟随系统已安装的插件结构生成汉化克隆。Omarchy 更新改变界面源码时，同步器会重新生成插件；如果上游结构发生不兼容变化，同步会明确失败并保留上一份可用版本。

## 安装

```bash
git clone https://github.com/QueedWen/omarchy-zh-cn.git
cd omarchy-zh-cn
./install.sh --dry-run
./install.sh
```

安装器会：

1. 检查 Omarchy 版本和依赖。
2. 使用官方 `omarchy plugin clone` 创建 22 个用户插件克隆。
3. 安装本地化同步器并生成中文插件。
4. 将天气单位设为公制。
5. 将 `Super + K` 指向中文快捷键面板。
6. 安装 `post-update` 钩子，以便系统更新后自动同步。

如果你已经有相同用户名和插件后缀的克隆，安装器会停止，避免覆盖个人修改。只有确认这些克隆就是此前的汉化版本时，才使用：

```bash
./install.sh --adopt-existing
```

## 手动同步

```bash
omarchy-zh-sync
```

可用参数：

```text
--quiet           仅在失败时输出
--no-restart      同步后不重启 Omarchy Shell
--adopt-existing  接管来源匹配的现有插件克隆
```

## 系统语言与输入法

安装器不会自动修改系统区域设置或安装软件包。需要中文系统区域、字体或 Fcitx 5/Rime 输入法时，请参阅 [系统中文环境与输入法](docs/system-setup.md)。

## 卸载

```bash
./uninstall.sh
```

卸载器会恢复安装前的菜单，移除受本项目管理的插件克隆，并恢复 `Super + K` 配置。Omarchy 的插件删除命令和卸载器都会保留带时间戳的备份，不会直接销毁用户配置。

## 修改范围

项目只写入以下用户目录：

```text
~/.config/omarchy/plugins/
~/.config/omarchy/extensions/omarchy-menu.jsonc
~/.config/omarchy/hooks/post-update.d/
~/.config/omarchy/shell.json
~/.config/hypr/bindings.lua
~/.local/bin/
~/.local/state/omarchy-zh-cn/
```

`/usr/share/omarchy` 始终只读。安装器不会收集或上传通知历史、网络信息、位置、令牌或其他用户数据。

## 开发与检查

```bash
./tests/smoke.sh
```

在 Omarchy 机器上，测试还会使用临时 `HOME` 从系统当前插件生成一套隔离副本；不会触碰真实用户配置。

贡献翻译前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 声明

这是社区项目，与 Omarchy 官方无隶属关系。Omarchy 及其源码遵循其上游许可证；本仓库只包含本项目编写的安装逻辑、同步逻辑和中文翻译，采用 MIT 许可证。
