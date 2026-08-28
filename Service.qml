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
  property int thickness: 3
  property int cursorX: 0
  property int cursorY: 0
  property bool cursorReady: false
  property var trailPoints: []
  readonly property int trailLifetimeMs: 1000

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

  function appendTrailPoint(x, y) {
    var now = Date.now()
    var next = root.trailPoints.slice()

    while (next.length > 0 && now - next[0].time > root.trailLifetimeMs)
      next.shift()

    next.push({ x: x, y: y, time: now })
    root.trailPoints = next
  }

  function clearTrail() {
    root.trailPoints = []
  }

  function updateCursor(raw) {
    var output = String(raw || "").trim()
    if (!output) return

    try {
      var position = JSON.parse(output)
      if (position && isFinite(Number(position.x)) && isFinite(Number(position.y))) {
        var nextX = Math.round(Number(position.x))
        var nextY = Math.round(Number(position.y))
        var moved = root.cursorReady && (nextX !== root.cursorX || nextY !== root.cursorY)

        root.cursorX = nextX
        root.cursorY = nextY
        root.cursorReady = true

        // The trail leaves ink only while the pointer is moving. The laser
        // head is rendered at the current cursor hotspot by Overlay.qml.
        if (root.active && moved) root.appendTrailPoint(nextX, nextY)
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

  onActiveChanged: {
    if (root.active) {
      root.refreshCursor()
    } else {
      root.clearTrail()
    }
  }
}
