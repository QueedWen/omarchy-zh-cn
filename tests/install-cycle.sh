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
  "plugin list")
    plugins_dir="$HOME/.config/omarchy/plugins"
    state="$HOME/.config/omarchy/stub-plugins.tsv"
    rows="[]"
    if [[ -f $state ]]; then
      while IFS=$'\t' read -r id enabled; do
        [[ -n $id ]] || continue
        rows=$(jq -c --arg id "$id" --argjson enabled "${enabled:-false}" \
          '. + [{id: $id, enabled: $enabled}]' <<<"$rows")
      done <"$state"
    fi
    for manifest in "$plugins_dir"/*/manifest.json; do
      [[ -f $manifest ]] || continue
      id=$(jq -r '.id' "$manifest")
      grep -q "^$id"$'\t' "$state" 2>/dev/null && continue
      rows=$(jq -c --arg id "$id" '. + [{id: $id, enabled: false}]' <<<"$rows")
    done
    printf '%s\n' "$rows"
    ;;
  "plugin enable")
    state="$HOME/.config/omarchy/stub-plugins.tsv"
    id=$3
    if grep -q "^$id"$'\t' "$state" 2>/dev/null; then
      awk -v id="$id" 'BEGIN { FS = OFS = "\t" } $1 == id { $2 = "true" } { print }' \
        "$state" >"$state.tmp"
      mv "$state.tmp" "$state"
    else
      printf '%s\ttrue\n' "$id" >>"$state"
    fi
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

stub_state_file="$sandbox_home/.config/omarchy/stub-plugins.tsv"
printf 'omarchy.menu\ttrue\nomarchy.osd\ttrue\nomarchy.microphone\tfalse\n' >"$stub_state_file"

stub_enabled() {
  awk -F '\t' -v id="$1" '$1 == id { print $2 }' "$stub_state_file"
}

HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/install.sh" >/dev/null

test -x "$sandbox_home/.local/bin/omarchy-zh-sync"
test -x "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
test -x "$sandbox_home/.local/bin/omarchy-update-zh"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-restart"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/agents/bin/grok-collector"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/agents/bin/kimi-collector"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-firmware"
test -f "$sandbox_home/.local/state/omarchy-zh-cn/last-sync"
test ! -e "$sandbox_home/.local/state/omarchy-zh"
test -x "$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
rg -Fq '准备更新吗？' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
rg -Fq -- '-- >>> omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua"
[[ $(find "$sandbox_home/.config/omarchy/plugins" -mindepth 2 -maxdepth 2 -name manifest.json | wc -l) -eq 27 ]]
[[ $(jq -r '.bar.layout.center[0].unit' "$sandbox_home/.config/omarchy/shell.json") == metric ]]
[[ $(jq -c '.disabledPlugins' "$sandbox_home/.config/omarchy/shell.json") == '[]' ]]

test -x "$sandbox_home/.local/bin/omarchy-menu-plugin-zh"
bash -n "$sandbox_home/.local/bin/omarchy-menu-plugin-zh"
for sub in enable disable clone remove; do
  rg -Fq "$sandbox_home/.local/bin/omarchy-menu-plugin-zh $sub" \
    "$sandbox_home/.config/omarchy/extensions/omarchy-menu.jsonc"
done

# 原件在用的克隆接管，没在用的保持待命。
[[ $(stub_enabled testuser.osd) == true ]] || {
  echo "原件启用的插件未接管：testuser.osd" >&2
  exit 1
}
[[ $(stub_enabled testuser.menu) == true ]] || {
  echo "原件启用的插件未接管：testuser.menu" >&2
  exit 1
}
[[ -z $(stub_enabled testuser.microphone) ]] || {
  echo "原件停用的插件不应接管：testuser.microphone" >&2
  exit 1
}
[[ -z $(stub_enabled testuser.weather) ]] || {
  echo "原件停用的插件不应接管：testuser.weather" >&2
  exit 1
}

HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/uninstall.sh" --yes >/dev/null

rg -Fq 'old-sync' "$sandbox_home/.local/bin/omarchy-zh-sync"
rg -Fq 'old-keybindings' "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
rg -Fq 'old-update' "$sandbox_home/.local/bin/omarchy-update-zh"
rg -Fq 'old-update-confirm' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-restart"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/agents"
remaining=$(find "$sandbox_home/.local/share/omarchy-zh-cn" -type f ! -name omarchy-update-confirm | wc -l)
[[ $remaining -eq 0 ]] || {
  echo "卸载后本地化目录仍有残留文件：$remaining" >&2
  exit 1
}
rg -Fq 'old-hook' "$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
test ! -e "$sandbox_home/.config/omarchy/extensions/omarchy-menu.jsonc"
! rg -Fq -- '-- >>> omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua"
[[ $(jq -r '.bar.layout.center[0].unit' "$sandbox_home/.config/omarchy/shell.json") == imperial ]]
[[ $(jq -c '.disabledPlugins' "$sandbox_home/.config/omarchy/shell.json") == '[]' ]]
test ! -e "$sandbox_home/.local/bin/omarchy-menu-plugin-zh"
[[ $(find "$sandbox_home/.config/omarchy/plugins" -mindepth 2 -maxdepth 2 -name manifest.json 2>/dev/null | wc -l) -eq 0 ]]

echo "隔离安装与卸载周期检查通过。"
