#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if [[ ! -d /usr/share/omarchy/shell || ! -x /usr/share/omarchy/bin/omarchy-menu-keybindings ]]; then
  echo "非 Omarchy 环境，跳过集成检查。"
  exit 0
fi

sandbox_home=$(mktemp -d)
cleanup() {
  [[ -n ${sandbox_home:-} && -d $sandbox_home && $sandbox_home == /tmp/* ]] && rm -rf -- "$sandbox_home"
}
trap cleanup EXIT

mkdir -p "$sandbox_home/.local/share/fcitx5/rime/opencc"
printf '笑脸\t笑脸 😀\n汽车\t汽车 🚗\n' \
  >"$sandbox_home/.local/share/fcitx5/rime/opencc/emoji.txt"

HOME="$sandbox_home" USER=testuser \
  "$ROOT_DIR/bin/omarchy-zh-sync" --quiet --no-restart

plugin_root="$sandbox_home/.config/omarchy/plugins"
plugin_count=$(find "$plugin_root" -mindepth 2 -maxdepth 2 -name manifest.json | wc -l)
[[ $plugin_count -eq 27 ]] || {
  echo "生成的插件数量不正确：$plugin_count" >&2
  exit 1
}

while IFS= read -r manifest; do
  jq -e '.omarchy.zhCnManaged == true and (.omarchy.clonedFrom | startswith("omarchy."))' \
    "$manifest" >/dev/null
done < <(find "$plugin_root" -mindepth 2 -maxdepth 2 -name manifest.json | sort)

for plugin in lock polkit; do
  source_manifest="/usr/share/omarchy/shell/plugins/$plugin/manifest.json"
  target_manifest="$plugin_root/testuser.$plugin/manifest.json"
  if [[ -f $source_manifest ]] && \
    jq -e '.omarchy.capabilities? // [] | index("authentication")' "$source_manifest" >/dev/null; then
    jq -e '.omarchy.capabilities? // [] | index("authentication")' "$target_manifest" >/dev/null
  fi
done

menu_file="$sandbox_home/.config/omarchy/extensions/omarchy-menu.jsonc"
node - "$menu_file" "$sandbox_home" <<'NODE'
const fs = require("fs")
const [menuPath, home] = process.argv.slice(2)
const raw = fs.readFileSync(menuPath, "utf8")
  .replace(/^\s*\/\/[^\n]*(\n|$)/gm, "")
  .replace(/,(\s*[}\]])/g, "$1")
const menu = JSON.parse(raw)
if (Object.keys(menu).length < 318) throw new Error("菜单项目数量不足")
for (const [id, label] of Object.entries({
  apps: "应用",
  setup: "设置",
  install: "安装",
  remove: "卸载",
  system: "系统"
})) {
  if (menu[id].label !== label) throw new Error(`${id} 菜单未汉化`)
}
for (const [id, label] of Object.entries({
  "install.ai.hermes": "Hermes 桌面版",
  "remove.ai.hermes": "Hermes 桌面版"
})) {
  if (menu[id] && menu[id].label !== label) throw new Error(`${id} 菜单未汉化`)
}
if (menu["remove.ai"] && (menu["remove.ai"].label !== "人工智能" || menu["remove.ai"].title !== "卸载")) {
  throw new Error("remove.ai 菜单未汉化")
}
if (menu["learn.keybindings"].label !== "快捷键") throw new Error("快捷键菜单未汉化")
if (menu["learn.keybindings"].action !== home + "/.local/bin/omarchy-menu-keybindings-zh") {
  throw new Error("快捷键入口路径不正确")
}
if (menu["update.omarchy"].action !== "omarchy-launch-floating-terminal-with-presentation " + home + "/.local/bin/omarchy-update-zh") {
  throw new Error("系统更新入口路径不正确")
}
for (const [id, script] of [
  ["update.firmware", "omarchy-update-firmware"],
  ["update.time", "omarchy-update-time"]
]) {
  if (menu[id] && menu[id].action !== "omarchy-launch-floating-terminal-with-presentation " + home + "/.local/share/omarchy-zh-cn/bin/" + script) {
    throw new Error(`${id} 入口路径不正确`)
  }
}
if (menu["setup.plugin"].label !== "插件") throw new Error("插件菜单未汉化")
for (const sub of ["enable", "disable", "clone", "remove"]) {
  const id = "setup.plugin." + sub
  if (menu[id].action !== home + "/.local/bin/omarchy-menu-plugin-zh " + sub) {
    throw new Error(`${id} 未指向中文插件菜单`)
  }
}
NODE

rg -Fq '"scrolling": "滚动布局"' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"

node - "$plugin_root/testuser.notifications/components/NotificationLocalization.js" <<'NODE'
const fs = require("fs")
const mod = { exports: {} }
new Function("module", "exports", fs.readFileSync(process.argv[2], "utf8"))(mod, mod.exports)
const translate = mod.exports.translate
for (const [input, expected] of [
  ["Battery 45%  ·  2h 10m left  ·  12.3W / 60Wh", "电池 45%  ·  剩余 2 小时 10 分  ·  12.3W / 60Wh"],
  ["Battery 45%  ·  1h left  ·  12.3W / 60Wh", "电池 45%  ·  剩余 1 小时  ·  12.3W / 60Wh"],
  ["Battery 45%  ·  45m to full  ·  12.3W / 60Wh", "电池 45%  ·  充满还需 45 分钟  ·  12.3W / 60Wh"],
  ["Battery 80%  ·  Holding at 80%  ·  0W / 60Wh", "电池 80%  ·  保持在 80%  ·  0W / 60Wh"]
]) {
  const actual = translate(input, "omarchy-action")
  if (actual !== expected) throw new Error(`电池通知未汉化：${actual}`)
}
NODE
rg -Fq 'Qt.locale("zh_CN")' "$plugin_root/testuser.weather/Panel.qml"
rg -Fq '"power-saver": "节能", "balanced": "平衡", "performance": "性能"' \
  "$plugin_root/testuser.power/Panel.qml"
rg -Fq 'text: rowRoot.isPinned ? "取消固定" : "固定"' "$plugin_root/testuser.tray/Tray.qml"
rg -Fq 'text: rowRoot.isHidden ? "显示" : "隐藏"' "$plugin_root/testuser.tray/Tray.qml"
rg -Fq '搜索剪贴板…' "$plugin_root/testuser.clipboard/Clipboard.qml"
rg -Fq 'cancelText: "取消"' "$plugin_root/testuser.clipboard/Clipboard.qml"
rg -Fq ' 个文件' "$plugin_root/testuser.clipboard/ClipboardHistory.js"
rg -Fq '，时间：' "$plugin_root/testuser.clipboard/ClipboardHistory.js"
rg -Fq '搜索表情…' "$plugin_root/testuser.emojis/Emojis.qml"
node - "$plugin_root/testuser.emojis/emojis.json" <<'NODE'
const items = require(process.argv[2])
const byEmoji = new Map(items.map(item => [item.e, item.k]))
if (!byEmoji.get("😀")?.includes("笑脸")) throw new Error("笑脸中文关键词缺失")
if (!byEmoji.get("🚗")?.includes("汽车")) throw new Error("汽车中文关键词缺失")
if (!byEmoji.get("🧑")?.includes("人物")) throw new Error("人物兜底关键词缺失")
if (!byEmoji.get("🚊")?.includes("有轨电车")) throw new Error("交通工具兜底关键词缺失")
NODE
rg -Fq '关闭无线网络' "$plugin_root/testuser.network/Panel.qml"
rg -Fq '隐藏网络' "$plugin_root/testuser.network/Panel.qml"
rg -Fq 'return "自动"' "$plugin_root/testuser.network/Model.js"
rg -Fq '正在连接…' "$plugin_root/testuser.network/Panel.qml"
rg -Fq '正在扫描设备…' "$plugin_root/testuser.bluetooth/Panel.qml"
rg -Fq '|| "设备"' "$plugin_root/testuser.bluetooth/Panel.qml"
rg -Fq '正在验证…' "$plugin_root/testuser.lock/LockView.qml"
rg -Fq "$plugin_root/testuser.agents/bin/usage-update" "$plugin_root/testuser.agents/Main.qml"
rg -Fq 'return "现在"' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq 'provider.syncDeviceCount + " 台设备"' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '· 缓存读取' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '用量同步：无法创建同步目录' "$plugin_root/testuser.agents/Main.qml"
jq -e '.barWidget.defaults.providers.grok.enabled == true and .barWidget.defaults.providers.kimi.enabled == true' \
  "$plugin_root/testuser.agents/manifest.json" >/dev/null
for collector in codex codex-collector grok-collector kimi-collector usage-update; do
  test -x "$plugin_root/testuser.agents/bin/$collector"
done
test -f "$plugin_root/testuser.agents/assets/grok.svg"
test -f "$plugin_root/testuser.agents/assets/grok-light.svg"
test -f "$plugin_root/testuser.agents/assets/kimi.svg"
test -f "$plugin_root/testuser.agents/assets/kimi-light.svg"
rg -Fq ' · 当前' "$plugin_root/testuser.monitor/Panel.qml"
for speed_plugin in speedtest disk-speedtest; do
  rg -Fq 'text: "再次测试"' "$plugin_root/testuser.$speed_plugin/SpeedTestOverlay.qml"
done
rg -Fq '无法获取测速节点' "$plugin_root/testuser.speedtest/Panel.qml"
rg -Fq '测速未完成' "$plugin_root/testuser.disk-speedtest/Panel.qml"
rg -Fq 'function localizedCommandError' "$plugin_root/testuser.wifiqr/Panel.qml"
rg -Fq '没有正在使用的无线网络连接' "$plugin_root/testuser.wifiqr/Panel.qml"
rg -Fq '拒绝使用不安全的显示器名称' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"
rg -Fq '个待处理的迁移' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"
rg -Fq '未找到 " + match[1] + " 在工作区 "' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"
rg -Fq "$sandbox_home/.local/bin/omarchy-update-zh" \
  "$plugin_root/testuser.system-update/SystemUpdate.qml"
test -x "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
bash -n "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"

update_helpers=(
  omarchy-update omarchy-update-pkg-prune omarchy-update-lock
  omarchy-update-requires-free-space omarchy-snapshot omarchy-update-keyring
  omarchy-update-firmware omarchy-update-time
  omarchy-pkg-add
  omarchy-update-system-pkgs
  omarchy-update-system-pkgs-when-conflicted omarchy-migrate
  omarchy-update-aur-pkgs omarchy-update-mise omarchy-update-orphan-pkgs
  omarchy-update-restart omarchy-update-dev omarchy-update-stay-awake
  omarchy-update-analyze-logs omarchy-hook omarchy-system-reboot
  omarchy-restart-shell
)
for helper in "${update_helpers[@]}"; do
  test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/$helper"
  bash -n "$sandbox_home/.local/share/omarchy-zh-cn/bin/$helper"
done
rg -Fq '更新过程中出现错误！' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
rg -Fq '创建系统快照' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-snapshot"
rg -Fq '清理软件包缓存' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-pkg-prune"
rg -Fq '更新 Arch 签名密钥' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-keyring"
rg -Fq '更新固件' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-firmware"
rg -Fq '正在更新系统时间…' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-time"
rg -Fq '优先调用本目录下的中文子脚本' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
rg -Fq '错误：软件包“' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-pkg-add"
rg -Fq 'echo -e "\e[32m\n更新系统软件包\e[0m"' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-system-pkgs"
rg -Fq 'echo -e "\e[32m\n更新 AUR 软件包\e[0m"' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-aur-pkgs"
rg -Fq '正在运行迁移' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-migrate"
rg -Fq '更新 mise 管理的工具' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-mise"
rg -Fq '重启前请检查日志' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-analyze-logs"
rg -Fq '钩子执行失败：' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-hook"
rg -Fq '正在重启' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-system-reboot"
rg -Fq 'Omarchy Shell 重启后未能就绪' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-restart-shell"
rg -Fq -- '--affirmative "是" --negative "否" --no-show-help' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-restart"
! rg -Fq 'Omarchy update in progress' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-stay-awake"

# 迁移脚本的运行时替换：执行前生成临时副本，只换整条英文消息。
migrate_runner="$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-migrate-zh-run"
test -x "$migrate_runner"
node --check "$migrate_runner"
rg -Fq 'omarchy-migrate-zh-run "$file" 3<&-' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-migrate"

# 迁移通知的点击动作必须落到中文迁移脚本，否则终端输出仍然是英文。
node - "$plugin_root/testuser.notifications/Service.qml" "$sandbox_home" <<'NODE'
const fs = require("fs")
const [file, home] = process.argv.slice(2)
const source = fs.readFileSync(file, "utf8")
const match = source.match(/function localizedArgv\(argv\) \{[\s\S]*?\n  \}/)
if (!match) throw new Error("通知插件缺少迁移动作本地化")
const localizedArgv = new Function(`return ${match[0]}`)()
const launcher = "omarchy-launch-floating-terminal-with-presentation"
const expected = home + "/.local/share/omarchy-zh-cn/bin/omarchy-migrate"
const migrate = localizedArgv([launcher, "omarchy-migrate"])
if (JSON.stringify(migrate) !== JSON.stringify([launcher, expected])) {
  throw new Error(`迁移通知未指向中文迁移脚本：${JSON.stringify(migrate)}`)
}
for (const argv of [
  [launcher, "omarchy-update"],
  [launcher, "omarchy-migrate", "--pending"],
  ["omarchy-migrate"],
  ["omarchy-notification-dismiss", "Omarchy Migrations"]
]) {
  if (JSON.stringify(localizedArgv(argv)) !== JSON.stringify(argv)) {
    throw new Error(`其它通知动作被改动：${JSON.stringify(argv)}`)
  }
}
if (localizedArgv(null) !== null || JSON.stringify(localizedArgv([])) !== "[]") {
  throw new Error("空通知动作处理不正确")
}
NODE

printf '%s\n' \
  '#!/bin/bash' \
  'set -euo pipefail' \
  'zram_conf=/etc/systemd/zram-generator.conf.d/99-local.conf' \
  'echo "Install MPRIS support for mpv"' \
  'echo "Keeping $zram_conf; it has local edits."' \
  'printf "%s\n" "-- Load user modules from ~/.config and Omarchy defaults from $OMARCHY_PATH." >"$MIGRATE_FIXTURE_OUT"' \
  'exit 3' >"$sandbox_home/migrate-fixture.sh"

set +e
MIGRATE_FIXTURE_OUT="$sandbox_home/migrate-fixture-out.txt" \
  "$migrate_runner" "$sandbox_home/migrate-fixture.sh" >"$sandbox_home/migrate-fixture.log"
fixture_status=$?
set -e
[[ $fixture_status -eq 3 ]] || {
  echo "迁移退出码未透传：$fixture_status" >&2
  exit 1
}
rg -Fq '为 mpv 安装 MPRIS 支持' "$sandbox_home/migrate-fixture.log"
rg -Fq '保留 /etc/systemd/zram-generator.conf.d/99-local.conf：它有本地修改。' \
  "$sandbox_home/migrate-fixture.log"
rg -Fxq -- '-- Load user modules from ~/.config and Omarchy defaults from /usr/share/omarchy.' \
  "$sandbox_home/migrate-fixture-out.txt"

if [[ -d /usr/share/omarchy/migrations ]]; then
  # 用假的 bash 拦住真正执行，只检查替换后的脚本。
  mkdir -p "$sandbox_home/migrate-stub"
  printf '%s\n' '#!/bin/bash' \
    'if [[ ${1:-} == -n ]]; then exit 0; fi' \
    'for arg in "$@"; do [[ -f $arg ]] || continue; cp "$arg" "${MIGRATE_ZH_CAPTURE:?}"; done' \
    'exit 0' >"$sandbox_home/migrate-stub/bash"
  chmod +x "$sandbox_home/migrate-stub/bash"

  node - "$migrate_runner" "$sandbox_home/migrate-stub" "$sandbox_home/migrate-capture.sh" <<'NODE'
const fs = require("fs")
const path = require("path")
const { execFileSync } = require("child_process")
const [runner, stubDir, capture] = process.argv.slice(2)
const dir = "/usr/share/omarchy/migrations"

// 引号内允许变化，引号外必须逐字一致，避免汉化动到脚本逻辑。
function skeleton(line) {
  let out = ""
  let quoted = false
  for (let i = 0; i < line.length; i++) {
    const char = line[i]
    if (quoted && char === "\\") { i++; continue }
    if (char === '"') { quoted = !quoted; continue }
    if (!quoted) out += char
  }
  return out
}

const files = fs.readdirSync(dir).filter(name => name.endsWith(".sh")).sort()
if (files.length === 0) throw new Error("没有找到任何迁移脚本")

let changed = 0
for (const name of files) {
  const source = path.join(dir, name)
  execFileSync(runner, [source], {
    env: { ...process.env, PATH: stubDir + ":" + process.env.PATH, MIGRATE_ZH_CAPTURE: capture },
    stdio: "ignore"
  })
  const before = fs.readFileSync(source, "utf8").split("\n")
  const after = fs.readFileSync(capture, "utf8").split("\n")
  if (before.length !== after.length) throw new Error(`迁移替换改变了行数：${name}`)
  for (let i = 0; i < before.length; i++) {
    if (before[i] === after[i]) continue
    if (skeleton(before[i]) !== skeleton(after[i])) {
      throw new Error(`迁移替换改动了引号外的内容：${name}:${i + 1}`)
    }
    changed++
  }
}
if (changed === 0) throw new Error("迁移脚本没有任何文案被替换")
console.log(`迁移运行时替换检查通过（${files.length} 个脚本，${changed} 处文案）。`)
NODE
fi

rg -Fq '同步已暂停' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq 'label: "已用空间"' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq 'text: "最近文件"' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq '" 小时前"' "$plugin_root/testuser.dropbox/Model.js"
rg -Fq 'Tailscale 已断开连接' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq 'text: "连接"' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq 'text: "出口节点"' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq 'actionStatus = "正在启动 Tailscale 登录…"' "$plugin_root/testuser.tailscale/Service.qml"
rg -Fq '暂无播放内容' "$plugin_root/testuser.media/BarWidget.qml"
rg -Fq '麦克风使用中' "$plugin_root/testuser.microphone/Microphone.qml"
rg -Fq 'function localizedMessage' "$plugin_root/testuser.osd/Osd.qml"
rg -Fq '"Microphone muted": "麦克风已静音"' "$plugin_root/testuser.osd/Osd.qml"
rg -Fq 'function localizedPrompt' "$plugin_root/testuser.menu/Menu.qml"
rg -Fq '"Select resolution": "选择分辨率"' "$plugin_root/testuser.menu/Menu.qml"
rg -Fq 'function localizedStatus' "$plugin_root/testuser.dropbox/Service.qml"
rg -Fq 'statusText = root.localizedStatus(String(parsed.statusText || (installed ? "Stopped" : "未安装")))' \
  "$plugin_root/testuser.dropbox/Service.qml"
rg -Fq '"Unavailable": "不可用"' "$plugin_root/testuser.dropbox/Service.qml"

node - "$plugin_root/testuser.notifications/components/NotificationLocalization.js" <<'NODE'
const fs = require("fs")
const mod = { exports: {} }
new Function("module", "exports", fs.readFileSync(process.argv[2], "utf8"))(mod, mod.exports)
const translate = mod.exports.translate
for (const [input, expected] of [
  ["Editing Cloned Plugin", "正在编辑克隆插件"],
  ["Original plugin has been replace by clone.", "原插件已被克隆版本取代。"],
  ["Restart Foot to apply the new terminal font size", "重启 Foot 以应用新的终端字体大小"],
  ["Setup Fingerprint Reader", "设置指纹识别"],
  ["Enable sudo and unlocking with your fingerprint.", "使用指纹解锁并授权 sudo。"],
  ["Set your default agent", "设置默认 AI 助手"],
  ["Let your favorite agent help with Omarchy.", "让你常用的 AI 助手协助使用 Omarchy。"],
  ["Install Dictation with Voxtype", "安装 Voxtype 语音输入"],
  ["Click to install voice dictation for Omarchy.", "点击为 Omarchy 安装语音输入。"],
  ["FIDO2 authfile needs attention", "FIDO2 认证文件需要处理"],
  ["New theme", "新主题"],
  ["Your new theme is catppuccin", "新主题为 catppuccin"],
  ["New font", "新字体"],
  ["Your new font is JetBrainsMono", "新字体为 JetBrainsMono"],
  ["Update Performed", "更新完成"],
  ["Your system is now up to date", "系统已是最新版本"]
]) {
  const actual = translate(input, "omarchy-action")
  if (actual !== expected) throw new Error(`通知未汉化：${input} -> ${actual}`)
}
NODE

# 文本替换一旦破坏括号配对，QML 会整块加载失败，而 grep 抓不到，所以真跑一遍语法检查。
qmllint_bin=$(command -v qmllint || true)
[[ -n $qmllint_bin ]] || qmllint_bin=/usr/lib/qt6/bin/qmllint
if [[ -x $qmllint_bin ]]; then
  if find "$plugin_root" -name '*.qml' -print0 |
    xargs -0 -P4 -I{} sh -c 'timeout 20 "$0" "$1" 2>&1' "$qmllint_bin" {} |
    grep -F '[syntax]'; then
    echo "生成的 QML 存在语法错误。" >&2
    exit 1
  fi
fi
# 插件脚本是 QML 模块，node 只认模块语法，所以先复制成 .mjs 再检查。
while IFS= read -r script; do
  cp "$script" "$sandbox_home/check.mjs"
  node --check "$sandbox_home/check.mjs" || {
    echo "生成的 JavaScript 存在语法错误：$script" >&2
    exit 1
  }
done < <(find "$plugin_root" -name '*.js')
test -x "$sandbox_home/.local/bin/omarchy-menu-plugin-zh"
bash -n "$sandbox_home/.local/bin/omarchy-menu-plugin-zh"
rg -Fq 'PLUGIN_NAMES=' "$sandbox_home/.local/bin/omarchy-menu-plugin-zh"
rg -Fq 'prompt="启用插件"' "$sandbox_home/.local/bin/omarchy-menu-plugin-zh"
for name in '"Notifications":"通知"' '"Clock":"日期与时间"' '"Wi-Fi QR":"无线网络二维码"' '"Workspaces":"工作区"'; do
  rg -Fq "$name" "$sandbox_home/.local/bin/omarchy-menu-plugin-zh" || {
    echo "插件菜单缺少名称映射：$name" >&2
    exit 1
  }
done

if rg -n '/home/[[:alnum:]_.-]+|/Users/[[:alnum:]_.-]+' "$sandbox_home"; then
  echo "生成结果包含开发机器信息。" >&2
  exit 1
fi

echo "Omarchy 隔离集成检查通过。"
