#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/uninstall.sh"
bash -n "$ROOT_DIR/hooks/omarchy-zh-post-update"
bash -n "$ROOT_DIR/bin/omarchy-update-zh"
bash -n "$ROOT_DIR/bin/omarchy-update-confirm-zh"
for script in codex usage-update; do
  bash -n "$ROOT_DIR/agents-overlay/bin/$script"
done
python -c 'import ast, pathlib, sys; [ast.parse(pathlib.Path(item).read_text()) for item in sys.argv[1:]]' \
  "$ROOT_DIR/agents-overlay/bin/codex-collector" \
  "$ROOT_DIR/agents-overlay/bin/grok-collector" \
  "$ROOT_DIR/agents-overlay/bin/kimi-collector"
python -B -m unittest "$ROOT_DIR/agents-overlay/tests/test_collectors.py"
node --check "$ROOT_DIR/bin/omarchy-zh-sync"
"$ROOT_DIR/bin/omarchy-zh-sync" --help >/dev/null

plugin_count=$("$ROOT_DIR/bin/omarchy-zh-sync" --list-plugins | wc -l)
[[ $plugin_count -eq 27 ]] || {
  echo "插件清单数量不正确：$plugin_count" >&2
  exit 1
}
rg -Fq -- '--list-plugins' "$ROOT_DIR/install.sh" || {
  echo "安装器未使用同步器提供的插件清单。" >&2
  exit 1
}

if rg -n '/home/[[:alnum:]_.-]+|/Users/[[:alnum:]_.-]+' "$ROOT_DIR" \
  -g '!tests/smoke.sh' -g '!tests/integration.sh'; then
  echo "发现个人路径或用户名。" >&2
  exit 1
fi

for expected in \
  '"Microphone muted": "麦克风已静音"' \
  '"Logging out": "正在注销"' \
  '"Set timezone": "设置时区"' \
  '"Keyboard layout": "键盘布局"' \
  '"同步已暂停"' \
  '"Tailscale 已断开连接"' \
  '"Restart Foot to apply the new terminal font size": "重启 Foot 以应用新的终端字体大小"' \
  '"FIDO2 authfile needs attention": "FIDO2 认证文件需要处理"' \
  '"Install MPRIS support for mpv": "为 mpv 安装 MPRIS 支持"' \
  '"$1，因此 SSH 密码认证仍处于启用状态；运行 omarchy-setup-security-sshd 可手动加固。"' \
  'omarchy-migrate-zh-run "$file" 3<&-' \
  '"Unavailable": "不可用"' \
  'function localizedMessage' \
  'function localizedPrompt' \
  'function localizedStatus' \
  '菜单插件结构已变化：应用库注入' \
  'function syncPluginMenu' \
  'setup.plugin.enable' \
  '^Battery (\d+)%  ·  (.+) left  ·  (.*)$' \
  '"scrolling": "滚动布局"' \
  '"dwindle": "螺旋平铺"' \
  '"WIND": "风速"' \
  'omarchy-menu-select '\''快捷键'\''' \
  '系统更新插件结构已变化：更新入口'; do
  rg -Fq "$expected" "$ROOT_DIR/bin/omarchy-zh-sync" || {
    echo "缺少关键翻译：$expected" >&2
    exit 1
  }
done

rg -Fq '准备更新吗？' "$ROOT_DIR/bin/omarchy-update-confirm-zh"
rg -Fq -- '--affirmative "是"' "$ROOT_DIR/bin/omarchy-update-confirm-zh"
rg -Fq -- '--negative "否"' "$ROOT_DIR/bin/omarchy-update-confirm-zh"

node - "$ROOT_DIR/bin/omarchy-zh-sync" <<'NODE'
const fs = require("fs")
const source = fs.readFileSync(process.argv[2], "utf8")
const expected = [
  '"install.ai.hermes": {\n    "label": "Hermes 桌面版"\n  },',
  '"remove.ai": {\n    "label": "人工智能",\n    "title": "卸载"\n  },',
  '"remove.ai.hermes": {\n    "label": "Hermes 桌面版"\n  },'
]
for (const item of expected) {
  if (!source.includes(item)) throw new Error(`缺少 Omarchy 4.0.3 AI 菜单翻译：${item.split("\n")[0]}`)
}
NODE

echo "静态检查通过。"
"$ROOT_DIR/tests/integration.sh"
"$ROOT_DIR/tests/install-cycle.sh"
