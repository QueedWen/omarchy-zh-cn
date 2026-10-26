#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if [[ ! -d /usr/share/omarchy/shell || ! -x /usr/share/omarchy/bin/omarchy-menu-keybindings ]]; then
  echo "非 Omarchy 环境，跳过安装周期检查。"
  exit 0
fi

sandbox_root=$(mktemp -d)
sandbox_home="$sandbox_root/home"
stub_bin="$sandbox_root/bin"
mkdir -p "$sandbox_home" "$stub_bin"

cleanup() {
  [[ -n ${sandbox_root:-} && -d $sandbox_root && $sandbox_root == /tmp/* ]] && rm -rf -- "$sandbox_root"
}
trap cleanup EXIT

cat >"$stub_bin/omarchy" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-}" in
  "version ")
    echo "4.0.0-test"
    ;;
  "plugin clone")
    source_id=$3
    target_id="${USER}.${source_id#omarchy.}"
    target="$HOME/.config/omarchy/plugins/$target_id"
    mkdir -p "$target"
    jq -n --arg id "$target_id" --arg source "$source_id" \
      '{id: $id, omarchy: {clonedFrom: $source}}' >"$target/manifest.json"
    ;;
  "plugin remove")
    rm -rf -- "$HOME/.config/omarchy/plugins/$3"
    ;;
  "hook install")
    target="$HOME/.config/omarchy/hooks/$3.d/$(basename "$4")"
    mkdir -p "$(dirname "$target")"
    cp "$4" "$target"
    chmod 755 "$target"
    ;;
  "restart shell")
    ;;
  *)
    echo "未处理的 omarchy 测试调用：$*" >&2
    exit 1
    ;;
esac
STUB

cat >"$stub_bin/omarchy-shell" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB

cat >"$stub_bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  configerrors) exit 0 ;;
  reload) echo ok; exit 0 ;;
esac
exit 0
STUB
chmod 755 "$stub_bin/omarchy" "$stub_bin/omarchy-shell" "$stub_bin/hyprctl"

test_path="$stub_bin:$PATH"

mkdir -p "$sandbox_home/.local/bin" \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin" \
  "$sandbox_home/.config/omarchy/hooks/post-update.d" \
  "$sandbox_home/.config/omarchy"
printf '#!/usr/bin/env bash\necho old-sync\n' >"$sandbox_home/.local/bin/omarchy-zh-sync"
printf '#!/usr/bin/env bash\necho old-keybindings\n' >"$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
printf '#!/usr/bin/env bash\necho old-update\n' >"$sandbox_home/.local/bin/omarchy-update-zh"
printf '#!/usr/bin/env bash\necho old-update-confirm\n' >"$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
printf '#!/usr/bin/env bash\necho old-hook\n' >"$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
chmod 755 "$sandbox_home/.local/bin/omarchy-zh-sync" \
  "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh" \
  "$sandbox_home/.local/bin/omarchy-update-zh" \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm" \
  "$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
cat >"$sandbox_home/.config/omarchy/shell.json" <<'JSON'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [],
      "center": [{"id": "omarchy.weather", "unit": "imperial"}],
      "right": []
    }
  },
  "plugins": [],
  "disabledPlugins": []
}
JSON

HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/install.sh" >/dev/null

test -x "$sandbox_home/.local/bin/omarchy-zh-sync"
test -x "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
test -x "$sandbox_home/.local/bin/omarchy-update-zh"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-restart"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/agents/bin/grok-collector"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/agents/bin/kimi-collector"
test -x "$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
rg -Fq '准备更新吗？' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
rg -Fq -- '-- >>> omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua"
[[ $(find "$sandbox_home/.config/omarchy/plugins" -mindepth 2 -maxdepth 2 -name manifest.json | wc -l) -eq 26 ]]
[[ $(jq -r '.bar.layout.center[0].unit' "$sandbox_home/.config/omarchy/shell.json") == metric ]]

# Optional translations must not add previously unused bar widgets.
jq -e '[.bar.layout[][]?.id] | all(. != "testuser.dropbox" and . != "testuser.tailscale" and . != "testuser.media" and . != "testuser.microphone")' \
  "$sandbox_home/.config/omarchy/shell.json" >/dev/null

HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/uninstall.sh" --yes >/dev/null

rg -Fq 'old-sync' "$sandbox_home/.local/bin/omarchy-zh-sync"
rg -Fq 'old-keybindings' "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
rg -Fq 'old-update' "$sandbox_home/.local/bin/omarchy-update-zh"
rg -Fq 'old-update-confirm' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-restart"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/agents"
for helper in omarchy-menu-timezone omarchy-menu-share omarchy-setup-security-sshd; do
  test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/$helper"
done
rg -Fq 'old-hook' "$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
test ! -e "$sandbox_home/.config/omarchy/extensions/omarchy-menu.jsonc"
! rg -Fq -- '-- >>> omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua"
[[ $(jq -r '.bar.layout.center[0].unit' "$sandbox_home/.config/omarchy/shell.json") == imperial ]]

echo "隔离安装与卸载周期检查通过。"
