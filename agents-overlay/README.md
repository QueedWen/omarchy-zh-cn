# Omarchy 中文版 Agents 用量扩展

此目录由 `omarchy-zh-cn` 同步器叠加到系统自带的 Agents 插件，不复制或替换上游 QML 源码。

新增内容：

- Grok Build：读取 `~/.grok/auth.json` 中现有登录，通过 Grok CLI 的用量接口显示周期限额与预付余额。
- Kimi Code：通过 `KIMI_API_KEY`、权限为 `0600` 的 `~/.config/omarchy/agents/kimi.json`，或 Kimi Code CLI 登录读取 Coding Plan 配额。
- Codex 兼容层：把已废弃的 `untrusted` 审批值转换为当前 CLI 接受的值，并为 app-server 初始化留出更合理的等待时间。
- Grok/Kimi 深浅主题图标。

未配置或登录失效的服务只会生成不可用记录，Agents 插件会将其隐藏。访问 Token 不会写入 `~/.local/state/omarchy/agents/usage/` 的展示数据。

Kimi 配置示例：

```json
{
  "apiKey": "...",
  "region": "cn"
}
```

`region` 支持 `cn` 与 `global`。请运行 `chmod 600 ~/.config/omarchy/agents/kimi.json`，否则收集器会拒绝读取其中的凭据。

图标来源与许可见 `assets/NOTICE.md`。
