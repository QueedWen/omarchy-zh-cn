# 经验记录

每次开始新会话前先看一遍这里，避免重复踩同一个坑。

## 术语约定

- **Token 保留英文**：用量相关文案统一写 `Token`，不要译成「令牌」。
- 产品名、CLI 命令、真实路径和系统返回的数据一律保留原文，只翻译界面文案。
- 状态栏组件名沿用克隆清单里的中文名，不要在别处另起译名。

## 工程经验

- **注入代码时整条语句一起替换**。只给表达式加前缀会在末尾少一个括号，QML 会直接
  语法报错，而 `grep` 断言抓不到。已踩坑：`Menu.qml` 的 `dmenuPrompt`、
  Dropbox `Service.qml` 的 `statusText`。
- **文本替换必须有语法闸门**。集成检查对生成的 QML 跑 `qmllint`、对 JS 跑
  `node --check`；`qmllint` 在个别文件上会卡住，必须加 `timeout`。
- **`String.prototype.replace` 的替换串会解释 `$` 模式**。用户级脚本注入统一走
  `replaceRequired`（`split`/`join`），否则 `$'` 会悄悄破坏生成的脚本。
- **验收要看产物，不只看断言**。新增或改写文案后，肉眼确认生成文件里的实际字符串。
- **受管清单保持单一来源**。插件清单只写在 `bin/omarchy-zh-sync`，`install.sh` 通过
  `--list-plugins` 读取，避免两处清单不一致。
