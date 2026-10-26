#!/usr/bin/env bash
set -euo pipefail
if ! command -v quickshell >/dev/null || [[ -z ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
  echo "无桌面会话，跳过 QML 代理销毁测试。"
  exit 0
fi
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
node - "$1/Menu.qml" "$scratch/shell.qml" <<'NODE'
const fs = require("node:fs")
const source = fs.readFileSync(process.argv[2], "utf8")
const helper = source.match(/  function usableHostAppLibrary\(\) \{[\s\S]*?\n  \}/)[0]
const binding = source.match(/  property int appLibraryRevision:[\s\S]*?(?=  onAppLibraryChanged:)/)[0]
const methods = ["sortedEntries", "entryName", "entrySubtext", "iconSource", "refreshIcons", "launch", "remove"].map(name => `function ${name}() {}`).join("\n")
fs.writeFileSync(process.argv[3], `import QtQuick
import Quickshell
ShellRoot {
 id: root
 property bool opened: true
 property var shell: ({appLibrary:null})
 property QtObject localAppLibrary: QtObject {}
 property var proxy: null
 property int phase: 0
 property bool failed: false
 Component.onCompleted: { proxy = factory.createObject(root); shell = ({appLibrary:proxy}) }
 Component { id: factory; QtObject { property var ownerPluginId: "testuser.menu"; ${methods} } }
 ${helper}
 ${binding}
 Timer {
  interval: 750; running: true; repeat: true
  onTriggered: {
   if (root.phase === 0) {
    if (root.appLibrary !== root.proxy) root.failed = true
    root.proxy.ownerPluginId = null
   } else if (root.phase === 1) {
    if (root.appLibrary !== root.localAppLibrary) root.failed = true
    root.proxy.ownerPluginId = "testuser.menu"
   } else if (root.phase === 2) {
    if (root.appLibrary !== root.proxy) root.failed = true
    root.proxy.destroy()
   } else {
    if (root.appLibrary !== root.localAppLibrary) root.failed = true
    console.log(root.failed ? "LIFECYCLE_FAIL" : "LIFECYCLE_PASS")
    Qt.quit()
   }
   root.phase++
  }
 }
}`)
NODE
timeout 15s quickshell -n -p "$scratch" >"$scratch/result" 2>&1
if ! rg -q 'LIFECYCLE_PASS' "$scratch/result"; then
  cat "$scratch/result" >&2
  exit 1
fi
echo "QML 宿主代理失效及销毁回退检查通过。"
