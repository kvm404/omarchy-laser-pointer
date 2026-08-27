import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Injected by omarchy-shell when the service is created.
  property var shell: null
  property var manifest: null

  readonly property string pluginId: "io.github.kvm404.laser-pointer"
  property bool active: false
  property color color: "#ff3b30"
  property int cursorX: 0
  property int cursorY: 0
  property bool cursorReady: false

  function toggle() {
    if (root.shell && typeof root.shell.toggle === "function") {
      root.shell.toggle(root.pluginId, "{}")
      return
    }

    // Makes the service harmless to instantiate outside the shell while
    // developing or linting the plugin.
    root.active = !root.active
  }

  function refreshCursor() {
    if (!cursorProcess.running) cursorProcess.running = true
  }

  function updateCursor(raw) {
    var output = String(raw || "").trim()
    if (!output) return

    try {
      var position = JSON.parse(output)
      if (position && isFinite(Number(position.x)) && isFinite(Number(position.y))) {
        root.cursorX = Math.round(Number(position.x))
        root.cursorY = Math.round(Number(position.y))
        root.cursorReady = true
      }
    } catch (error) {
      // Keep the last valid position. A transient hyprctl failure should not
      // make the pointer disappear between two successful samples.
    }
  }

  Timer {
    interval: 33
    repeat: true
    running: root.active
    onTriggered: root.refreshCursor()
  }

  Process {
    id: cursorProcess
    command: ["hyprctl", "-j", "cursorpos"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateCursor(text)
    }

    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.cursorReady) root.cursorReady = false
    }
  }

  onActiveChanged: if (root.active) root.refreshCursor()
}
