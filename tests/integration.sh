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
[[ $plugin_count -eq 26 ]] || {
  echo "生成的插件数量不正确：$plugin_count" >&2
  exit 1
}

while IFS= read -r manifest; do
  jq -e '.omarchy.zhCnManaged == true and (.omarchy.clonedFrom | startswith("omarchy."))' \
    "$manifest" >/dev/null
done < <(find "$plugin_root" -mindepth 2 -maxdepth 2 -name manifest.json | sort)

# A cloned menu may receive the bar-scoped API, which has no appLibrary.
# Verify the generated binding with both API shapes and after replacement.
node - "$plugin_root/testuser.menu" <<'NODE'
const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")
const path = require("node:path")
const plugin = process.argv[2]
const menu = fs.readFileSync(path.join(plugin, "Menu.qml"), "utf8")
const binding = menu.match(/readonly property var appLibrary: (.+)/)[1]
const localAppLibrary = { entries: ["chatgpt", "Clash Verge"] }
const root = { shell: { appLibrary: null } }
const context = vm.createContext({ root, localAppLibrary })
const evaluate = () => vm.runInContext(binding, context)
assert.equal(evaluate(), localAppLibrary)
const hostedLibrary = { entries: ["Firefox"] }
root.shell = { appLibrary: hostedLibrary }
assert.equal(evaluate(), hostedLibrary)
root.shell = {}
assert.equal(evaluate(), localAppLibrary)
root.shell = null
assert.equal(evaluate(), localAppLibrary)
for (const [source, target] of [["AppLibrary.qml", "LocalAppLibrary.qml"], ["AppSearch.js", "AppSearch.js"]]) {
  assert.deepEqual(fs.readFileSync(path.join(plugin, target)),
    fs.readFileSync(path.join("/usr/share/omarchy/shell/services", source)))
}
NODE

node - "$plugin_root/testuser.notifications/components/NotificationLocalization.js" <<'NODE'
const assert = require("node:assert/strict")
const { translate } = require(process.argv[2])
for (const [english, chinese] of Object.entries({
  "Editing Cloned Plugin": "正在编辑克隆插件",
  "Original plugin has been replace by clone.": "原插件已由克隆插件替代。",
  "Original plugin has been replaced by clone.": "原插件已由克隆插件替代。",
  "Install Dictation with Voxtype": "安装 Voxtype 语音输入",
  "Click to install voice dictation for Omarchy.": "点击为 Omarchy 安装语音输入。"
})) {
  assert.equal(translate(english, "omarchy-action"), chinese)
  assert.equal(translate(english, "third-party-app"), english)
}
assert.equal(translate("An unknown message", "omarchy-action"), "An unknown message")
NODE

node - "$plugin_root" "$sandbox_home" <<'NODE'
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")
const [plugins, home] = process.argv.slice(2)
const dropbox = require(path.join(plugins, "testuser.dropbox/Model.js"))
const now = 2_000_000_000_000
assert.equal(dropbox.relativeTime(now / 1000 - 120, now), "2 分钟前")
assert.equal(dropbox.relativeTime(now / 1000 - 7200, now), "2 小时前")
assert.equal(dropbox.relativeTime(now / 1000 - 86400 * 40, now), "1 个月前")
assert.ok(dropbox.fileMeta({modifiedTs: now / 1000 - 120, folder:"My Files"}, now).includes("My Files"))
const model = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(plugins, "testuser.tailscale/Model.js"), "utf8"), model)
const peer = model.peerFromStatus("device-1", {HostName:"My Laptop", DNSName:"host.example.ts.net.", TailscaleIPs:["100.1.2.3"], Online:true, OS:"linux"})
assert.equal(peer.DisplayName, "My Laptop")
assert.equal(peer.DNSName, "host.example.ts.net")
assert.equal(peer.TailscaleIPs[0], "100.1.2.3")
assert.equal(peer.Online, true)
for (const [file, expected] of [
  ["testuser.dropbox/Panel.qml", "没有已同步的文件。"],
  ["testuser.tailscale/Panel.qml", "此私有网络中没有设备。"],
  ["testuser.media/BarWidget.qml", "暂无正在播放的媒体"],
  ["testuser.microphone/Microphone.qml", "麦克风已静音"]
]) assert.ok(fs.readFileSync(path.join(plugins, file), "utf8").includes(expected))
for (const script of ["omarchy-menu-timezone", "omarchy-menu-share", "omarchy-setup-security-sshd"]) {
  const original = fs.readFileSync(path.join("/usr/share/omarchy/bin", script), "utf8")
  const localized = fs.readFileSync(path.join(home, ".local/share/omarchy-zh-cn/bin", script), "utf8")
  // Translation must preserve privileged operations, command options and paths.
  const privilegedLines = text => text.split("\n").filter(line => /^\s*sudo /.test(line))
  assert.deepEqual(privilegedLines(localized), privilegedLines(original))
}
NODE
for helper in omarchy-menu-timezone omarchy-menu-share omarchy-setup-security-sshd; do
  bash -n "$sandbox_home/.local/share/omarchy-zh-cn/bin/$helper"
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
if (menu["learn.keybindings"].label !== "快捷键") throw new Error("快捷键菜单未汉化")
if (menu["learn.keybindings"].action !== home + "/.local/bin/omarchy-menu-keybindings-zh") {
  throw new Error("快捷键入口路径不正确")
}
if (menu["update.omarchy"].action !== "omarchy-launch-floating-terminal-with-presentation " + home + "/.local/bin/omarchy-update-zh") {
  throw new Error("系统更新入口路径不正确")
}
NODE

rg -Fq '"scrolling": "滚动布局"' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"
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
rg -Fq '未找到 " + match[1] + " 在工作区 "' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"
rg -Fq "$sandbox_home/.local/bin/omarchy-update-zh" \
  "$plugin_root/testuser.system-update/SystemUpdate.qml"
test -x "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
bash -n "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"

update_helpers=(
  omarchy-update omarchy-update-pkg-prune omarchy-update-lock
  omarchy-update-requires-free-space omarchy-snapshot omarchy-update-keyring
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

if rg -n '/home/[[:alnum:]_.-]+|/Users/[[:alnum:]_.-]+' "$sandbox_home"; then
  echo "生成结果包含开发机器信息。" >&2
  exit 1
fi

echo "Omarchy 隔离集成检查通过。"
