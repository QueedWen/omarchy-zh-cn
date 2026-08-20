#!/usr/bin/env bash

set -euo pipefail

STATE_DIR="$HOME/.local/state/omarchy-zh-cn"
PLUGIN_ROOT="$HOME/.config/omarchy/plugins"
MENU_FILE="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
SHELL_FILE="$HOME/.config/omarchy/shell.json"
HOOK_FILE="$HOME/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
SYNC_TARGET="$HOME/.local/bin/omarchy-zh-sync"
KEYBINDINGS_TARGET="$HOME/.local/bin/omarchy-menu-keybindings-zh"
ASSUME_YES=0

while (($# > 0)); do
  case "$1" in
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) echo "用法：./uninstall.sh [--yes]"; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done

[[ -f $STATE_DIR/install.version ]] || {
  echo "没有找到 omarchy-zh-cn 的安装状态，停止卸载。" >&2
  exit 1
}

if ((!ASSUME_YES)); then
  read -r -p "卸载 Omarchy 简体中文界面并恢复原菜单？[y/N] " answer
  [[ $answer == y || $answer == Y ]] || exit 0
fi

timestamp=$(date -u +%Y%m%d%H%M%S)
user_name=${USER:-$(id -un)}

if [[ -f $STATE_DIR/plugin-sources ]]; then
  mapfile -t plugin_sources <"$STATE_DIR/plugin-sources"
else
  plugin_sources=()
fi

for source_id in "${plugin_sources[@]}"; do
  [[ -n $source_id ]] || continue
  target_id="$user_name.${source_id#omarchy.}"
  manifest="$PLUGIN_ROOT/$target_id/manifest.json"
  if [[ -f $manifest ]] && [[ $(jq -r '.omarchy.zhCnManaged // false' "$manifest") == true ]]; then
    omarchy plugin remove "$target_id" --yes
  fi
done

if [[ -f $MENU_FILE ]]; then
  cp -a "$MENU_FILE" "$MENU_FILE.omarchy-zh-cn-uninstall-$timestamp.bak"
fi
if [[ -f $STATE_DIR/original/omarchy-menu.jsonc ]]; then
  mkdir -p "$(dirname "$MENU_FILE")"
  cp -a "$STATE_DIR/original/omarchy-menu.jsonc" "$MENU_FILE"
elif [[ -f $STATE_DIR/original/menu-was-absent ]]; then
  rm -f "$MENU_FILE"
fi

if [[ -f $BINDINGS_FILE ]] && grep -Fq -- '-- >>> omarchy-zh-cn' "$BINDINGS_FILE"; then
  cp -a "$BINDINGS_FILE" "$BINDINGS_FILE.omarchy-zh-cn-uninstall-$timestamp.bak"
  temporary="$BINDINGS_FILE.zh-new-$$"
  awk '
    $0 == "-- >>> omarchy-zh-cn" { managed = 1; next }
    $0 == "-- <<< omarchy-zh-cn" { managed = 0; next }
    !managed { print }
  ' "$BINDINGS_FILE" >"$temporary"
  mv "$temporary" "$BINDINGS_FILE"
fi

if [[ -f $STATE_DIR/original/shell.json && -f $SHELL_FILE ]]; then
  original_unit=$(jq -r '
    [.bar.layout[][] | select(.id | endswith(".weather")) | (.unit // "__missing__")][0] // "__missing__"
  ' "$STATE_DIR/original/shell.json")
  temporary="$SHELL_FILE.zh-new-$$"
  jq --arg unit "$original_unit" '
    .bar.layout |= with_entries(
      .value |= map(
        if (.id | endswith(".weather")) then
          if $unit == "__missing__" then del(.unit) else .unit = $unit end
        else . end
      )
    )
  ' "$SHELL_FILE" >"$temporary"
  mv "$temporary" "$SHELL_FILE"
fi

if [[ -f $STATE_DIR/original/omarchy-zh-post-update ]]; then
  mkdir -p "$(dirname "$HOOK_FILE")"
  cp -a "$STATE_DIR/original/omarchy-zh-post-update" "$HOOK_FILE"
elif [[ -f $HOOK_FILE ]]; then
  mv "$HOOK_FILE" "$HOOK_FILE.uninstalled-$timestamp.bak"
fi

if [[ -f $STATE_DIR/original/omarchy-zh-sync ]]; then
  cp -a "$STATE_DIR/original/omarchy-zh-sync" "$SYNC_TARGET"
else
  rm -f "$SYNC_TARGET"
fi
if [[ -f $STATE_DIR/original/omarchy-menu-keybindings-zh ]]; then
  cp -a "$STATE_DIR/original/omarchy-menu-keybindings-zh" "$KEYBINDINGS_TARGET"
else
  rm -f "$KEYBINDINGS_TARGET"
fi

if command -v hyprctl >/dev/null; then hyprctl reload >/dev/null || true; fi
omarchy restart shell >/dev/null || true

archive="$HOME/.local/state/omarchy-zh-cn-uninstalled-$timestamp"
mv "$STATE_DIR" "$archive"
echo "卸载完成。插件和修改过的配置均保留了可恢复备份。"
echo "卸载状态备份：$archive"
