#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SYNC_SOURCE="$ROOT_DIR/bin/omarchy-zh-sync"
HOOK_SOURCE="$ROOT_DIR/hooks/omarchy-zh-post-update"
SYNC_TARGET="$HOME/.local/bin/omarchy-zh-sync"
KEYBINDINGS_TARGET="$HOME/.local/bin/omarchy-menu-keybindings-zh"
HOOK_TARGET="$HOME/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
PLUGIN_ROOT="$HOME/.config/omarchy/plugins"
MENU_FILE="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
SHELL_FILE="$HOME/.config/omarchy/shell.json"
STATE_DIR="$HOME/.local/state/omarchy-zh-cn"
BACKUP_DIR="$STATE_DIR/original"
DRY_RUN=0
ADOPT_EXISTING=0

PLUGIN_IDS=(
  omarchy.audio omarchy.bluetooth omarchy.clock omarchy.monitor
  omarchy.network omarchy.power omarchy.weather omarchy.agents
  omarchy.menu omarchy.notifications omarchy.tray omarchy.indicators
  omarchy.system-update omarchy.lock omarchy.polkit omarchy.clipboard
  omarchy.emojis omarchy.image-picker omarchy.reminders omarchy.speedtest
  omarchy.disk-speedtest omarchy.wifiqr
)

usage() {
  cat <<'EOF'
用法：./install.sh [--dry-run] [--adopt-existing]

安装 Omarchy 4 简体中文界面。
  --dry-run         只检查环境并显示将执行的操作
  --adopt-existing  接管用户名下来源匹配的现有 Omarchy 插件克隆
EOF
}

while (($# > 0)); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --adopt-existing) ADOPT_EXISTING=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

for command_name in node jq omarchy omarchy-plugin-catalog omarchy-shell; do
  command -v "$command_name" >/dev/null || {
    echo "缺少命令：$command_name" >&2
    exit 1
  }
done

version=$(omarchy version 2>/dev/null || true)
[[ $version == 4.* ]] || {
  echo "当前仅支持 Omarchy 4，检测到：${version:-未知版本}" >&2
  exit 1
}

user_name=${USER:-$(id -un)}
[[ $user_name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
  echo "用户名无法安全地用于插件 ID：$user_name" >&2
  exit 1
}

[[ -f $SYNC_SOURCE && -f $HOOK_SOURCE ]] || {
  echo "项目文件不完整，请从仓库根目录运行安装器。" >&2
  exit 1
}

echo "Omarchy：$version"
echo "将安装 ${#PLUGIN_IDS[@]} 个中文插件克隆。"

if ((DRY_RUN)); then
  for source_id in "${PLUGIN_IDS[@]}"; do
    target_id="$user_name.${source_id#omarchy.}"
    if [[ -d $PLUGIN_ROOT/$target_id ]]; then
      echo "检查现有插件：$target_id"
    else
      echo "将克隆：$source_id -> $target_id"
    fi
  done
  echo "将安装：$SYNC_TARGET"
  echo "将安装 post-update 自动同步钩子，并把 Super+K 指向中文快捷键面板。"
  exit 0
fi

mkdir -p "$HOME/.local/bin" "$PLUGIN_ROOT" "$BACKUP_DIR"

if [[ ! -e $STATE_DIR/install.version ]]; then
  printf '1\n' >"$STATE_DIR/install.version"
  if [[ -f $MENU_FILE ]]; then
    cp -a "$MENU_FILE" "$BACKUP_DIR/omarchy-menu.jsonc"
  else
    : >"$BACKUP_DIR/menu-was-absent"
  fi
  [[ -f $SHELL_FILE ]] && cp -a "$SHELL_FILE" "$BACKUP_DIR/shell.json"
  [[ -f $SYNC_TARGET ]] && cp -a "$SYNC_TARGET" "$BACKUP_DIR/omarchy-zh-sync"
  [[ -f $KEYBINDINGS_TARGET ]] && cp -a "$KEYBINDINGS_TARGET" "$BACKUP_DIR/omarchy-menu-keybindings-zh"
  [[ -f $HOOK_TARGET ]] && cp -a "$HOOK_TARGET" "$BACKUP_DIR/omarchy-zh-post-update"
fi

install -m 755 "$SYNC_SOURCE" "$SYNC_TARGET"

mark_managed() {
  local manifest=$1
  local source_id=$2
  local temporary="$manifest.zh-new-$$"
  jq --arg source "$source_id" '
    .omarchy = ((.omarchy // {}) + {clonedFrom: $source, zhCnManaged: true})
  ' "$manifest" >"$temporary"
  mv "$temporary" "$manifest"
}

for source_id in "${PLUGIN_IDS[@]}"; do
  target_id="$user_name.${source_id#omarchy.}"
  target_dir="$PLUGIN_ROOT/$target_id"
  manifest="$target_dir/manifest.json"

  if [[ ! -e $target_dir ]]; then
    omarchy plugin clone "$source_id"
    mark_managed "$manifest" "$source_id"
    continue
  fi

  [[ -f $manifest ]] || {
    echo "现有路径不是有效插件，拒绝覆盖：$target_dir" >&2
    exit 1
  }

  managed=$(jq -r '.omarchy.zhCnManaged // false' "$manifest")
  cloned_from=$(jq -r '.omarchy.clonedFrom // empty' "$manifest")
  if [[ $managed == true ]]; then
    [[ $cloned_from == "$source_id" ]] || {
      echo "受管理插件的来源不匹配：$target_id" >&2
      exit 1
    }
  elif ((ADOPT_EXISTING)) && [[ $cloned_from == "$source_id" ]]; then
    mark_managed "$manifest" "$source_id"
  else
    echo "发现非本项目管理的同名插件：$target_dir" >&2
    echo "如确认它是此前的汉化克隆，请重新运行：./install.sh --adopt-existing" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "$BINDINGS_FILE")"
[[ -f $BINDINGS_FILE ]] || : >"$BINDINGS_FILE"
if ! grep -Fq -- '-- >>> omarchy-zh-cn' "$BINDINGS_FILE" && \
   ! grep -Fq 'omarchy-menu-keybindings-zh' "$BINDINGS_FILE"; then
  cat >>"$BINDINGS_FILE" <<'EOF'

-- >>> omarchy-zh-cn
-- 将 Omarchy 默认的英文快捷键面板替换为中文面板。
hl.unbind("SUPER + K")
o.bind("SUPER + K", "快捷键", os.getenv("HOME") .. "/.local/bin/omarchy-menu-keybindings-zh")
-- <<< omarchy-zh-cn
EOF
fi

"$SYNC_TARGET" --adopt-existing
omarchy hook install post-update "$HOOK_SOURCE"

if command -v hyprctl >/dev/null; then
  hyprctl reload >/dev/null
  config_errors=$(hyprctl configerrors)
  [[ -z $config_errors ]] || {
    echo "$config_errors" >&2
    exit 1
  }
fi

printf '%s\n' "${PLUGIN_IDS[@]}" >"$STATE_DIR/plugin-sources"
echo "安装完成。按 Super+K 可打开中文快捷键面板。"
