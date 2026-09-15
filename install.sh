#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SYNC_SOURCE="$ROOT_DIR/bin/omarchy-zh-sync"
HOOK_SOURCE="$ROOT_DIR/hooks/omarchy-zh-post-update"
UPDATE_SOURCE="$ROOT_DIR/bin/omarchy-update-zh"
UPDATE_CONFIRM_SOURCE="$ROOT_DIR/bin/omarchy-update-confirm-zh"
SYNC_TARGET="$HOME/.local/bin/omarchy-zh-sync"
KEYBINDINGS_TARGET="$HOME/.local/bin/omarchy-menu-keybindings-zh"
UPDATE_TARGET="$HOME/.local/bin/omarchy-update-zh"
UPDATE_CONFIRM_DIR="$HOME/.local/share/omarchy-zh-cn/bin"
UPDATE_CONFIRM_TARGET="$UPDATE_CONFIRM_DIR/omarchy-update-confirm"
AGENTS_OVERLAY_SOURCE="$ROOT_DIR/agents-overlay"
AGENTS_OVERLAY_TARGET="$HOME/.local/share/omarchy-zh-cn/agents"
HOOK_TARGET="$HOME/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
PLUGIN_ROOT="$HOME/.config/omarchy/plugins"
MENU_FILE="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
SHELL_FILE="$HOME/.config/omarchy/shell.json"
STATE_DIR="$HOME/.local/state/omarchy-zh-cn"
BACKUP_DIR="$STATE_DIR/original"
DRY_RUN=0
ADOPT_EXISTING=0

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

for command_name in node jq gum omarchy omarchy-plugin-catalog omarchy-shell; do
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

[[ -f $SYNC_SOURCE && -f $HOOK_SOURCE && -f $UPDATE_SOURCE && -f $UPDATE_CONFIRM_SOURCE && -d $AGENTS_OVERLAY_SOURCE ]] || {
  echo "项目文件不完整，请从仓库根目录运行安装器。" >&2
  exit 1
}

mapfile -t PLUGIN_IDS < <(node "$SYNC_SOURCE" --list-plugins)
[[ ${#PLUGIN_IDS[@]} -gt 0 ]] || {
  echo "无法从同步器读取插件清单：$SYNC_SOURCE --list-plugins" >&2
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
      echo "将生成中文克隆：$source_id -> $target_id"
    fi
  done
  echo "将安装：$SYNC_TARGET"
  echo "将安装：$UPDATE_TARGET（中文更新流程）"
  echo "将安装：$AGENTS_OVERLAY_TARGET（Codex/Grok/Kimi 用量扩展与主题图标）"
  echo "将安装 post-update 自动同步钩子，并把 Super+K 与设置菜单的插件入口指向中文面板。"
  exit 0
fi

mkdir -p "$HOME/.local/bin" "$UPDATE_CONFIRM_DIR" "$PLUGIN_ROOT" "$BACKUP_DIR"

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

backup_once() {
  local current=$1
  local backup=$2
  local absent_marker=$3
  if [[ ! -e $backup && ! -e $absent_marker ]]; then
    if [[ -f $current ]]; then
      cp -a "$current" "$backup"
    else
      : >"$absent_marker"
    fi
  fi
}

backup_once "$UPDATE_TARGET" "$BACKUP_DIR/omarchy-update-zh" "$BACKUP_DIR/omarchy-update-zh-was-absent"
backup_once "$UPDATE_CONFIRM_TARGET" "$BACKUP_DIR/omarchy-update-confirm" "$BACKUP_DIR/omarchy-update-confirm-was-absent"

install -m 755 "$SYNC_SOURCE" "$SYNC_TARGET"
install -m 755 "$UPDATE_SOURCE" "$UPDATE_TARGET"
install -m 755 "$UPDATE_CONFIRM_SOURCE" "$UPDATE_CONFIRM_TARGET"
mkdir -p "$AGENTS_OVERLAY_TARGET/bin" "$AGENTS_OVERLAY_TARGET/assets"
cp -a "$AGENTS_OVERLAY_SOURCE/bin/." "$AGENTS_OVERLAY_TARGET/bin/"
cp -a "$AGENTS_OVERLAY_SOURCE/assets/." "$AGENTS_OVERLAY_TARGET/assets/"
install -m 644 "$AGENTS_OVERLAY_SOURCE/README.md" "$AGENTS_OVERLAY_TARGET/README.md"

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

  # 缺失的克隆由同步器直接生成：官方的 clone 命令会顺手把组件放进状态栏，
  # 对没在用的 Dropbox、Tailscale 之类会多出一个图标。接管交给 takeover_clones。
  [[ -e $target_dir ]] || continue

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

# 等 Omarchy Shell 扫到所有克隆，再决定哪些接管。
plugins_json=""
wait_for_clones() {
  local attempt missing source_id
  for ((attempt = 0; attempt < 20; attempt++)); do
    plugins_json=$(omarchy plugin list --json 2>/dev/null || true)
    if [[ -n $plugins_json ]]; then
      missing=0
      for source_id in "${PLUGIN_IDS[@]}"; do
        jq -e --arg id "$user_name.${source_id#omarchy.}" \
          'map(select(.id == $id)) | length > 0' <<<"$plugins_json" >/dev/null || missing=1
      done
      ((missing == 0)) && return 0
    fi
    sleep 0.3
  done
  return 1
}

# 原件在用才让克隆接管，栏位原地替换，不新增图标。
takeover_clones() {
  local source_id clone_id original_enabled clone_enabled
  [[ -n $plugins_json ]] || return 0
  for source_id in "${PLUGIN_IDS[@]}"; do
    clone_id="$user_name.${source_id#omarchy.}"
    original_enabled=$(jq -r --arg id "$source_id" 'map(select(.id == $id))[0].enabled // false' <<<"$plugins_json")
    clone_enabled=$(jq -r --arg id "$clone_id" 'map(select(.id == $id))[0].enabled // false' <<<"$plugins_json")
    if [[ $original_enabled == true && $clone_enabled != true ]]; then
      omarchy plugin enable "$clone_id" >/dev/null 2>&1 || true
    fi
  done
}

wait_for_clones || echo "警告：Omarchy Shell 未及时列出全部克隆，本次跳过接管。" >&2
takeover_clones

if command -v hyprctl >/dev/null; then
  hyprctl reload >/dev/null
  config_errors=$(hyprctl configerrors)
  [[ -z $config_errors ]] || {
    echo "$config_errors" >&2
    exit 1
  }
fi

printf '%s\n' "${PLUGIN_IDS[@]}" >"$STATE_DIR/plugin-sources"
echo "安装完成。按 Super+K 可打开中文快捷键面板；系统更新流程也已汉化。"
