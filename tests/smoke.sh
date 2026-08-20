#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/uninstall.sh"
bash -n "$ROOT_DIR/hooks/omarchy-zh-post-update"
node --check "$ROOT_DIR/bin/omarchy-zh-sync"
"$ROOT_DIR/bin/omarchy-zh-sync" --help >/dev/null

if rg -n '/home/[[:alnum:]_.-]+|/Users/[[:alnum:]_.-]+' "$ROOT_DIR" \
  -g '!tests/smoke.sh' -g '!tests/integration.sh'; then
  echo "发现个人路径或用户名。" >&2
  exit 1
fi

for expected in \
  '"scrolling": "滚动布局"' \
  '"dwindle": "螺旋平铺"' \
  '"WIND": "风速"' \
  'omarchy-menu-select '\''快捷键'\'''; do
  rg -Fq "$expected" "$ROOT_DIR/bin/omarchy-zh-sync" || {
    echo "缺少关键翻译：$expected" >&2
    exit 1
  }
done

echo "静态检查通过。"
"$ROOT_DIR/tests/integration.sh"
"$ROOT_DIR/tests/install-cycle.sh"
