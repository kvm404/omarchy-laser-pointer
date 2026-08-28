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
  property bool mouseHeld: false
  property bool trailSuppressed: false
  property double trailFadeStartMs: 0
  property color color: "#ff3b30"
  property int thickness: 3
  property int cursorX: 0
  property int cursorY: 0
  property bool cursorReady: false
  property var trailPoints: []
  readonly property int trailLifetimeMs: 1000
  readonly property int maximumTrailPoints: 12000

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

    while (next.length >= root.maximumTrailPoints)
      next.shift()

    next.push({ x: x, y: y, time: now })
    root.trailPoints = next
  }

  function clearTrail() {
    root.trailPoints = []
    root.trailFadeStartMs = 0
  }

  function beginMouseDraw() {
    if (!root.active || root.trailSuppressed) return

    // Start a fresh stroke. A previous stroke is already fading or has
    // disappeared; keeping it would make the next hold inherit its age.
    root.clearTrail()
    root.mouseHeld = true
  }

  function endMouseDraw() {
    if (!root.mouseHeld) return

    root.mouseHeld = false
    root.trailFadeStartMs = root.trailPoints.length > 0 ? Date.now() : 0
  }

  function pruneTrail() {
    if (root.mouseHeld || root.trailPoints.length === 0) return

    if (root.trailFadeStartMs > 0
        && Date.now() - root.trailFadeStartMs >= root.trailLifetimeMs) {
      root.clearTrail()
    }
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
        if (root.active && root.mouseHeld && !root.trailSuppressed && moved)
          root.appendTrailPoint(nextX, nextY)
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
    onTriggered: {
      root.refreshCursor()
      root.pruneTrail()
    }
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
      root.endMouseDraw()
      root.clearTrail()
    }
  }

  onTrailSuppressedChanged: {
    if (root.trailSuppressed) root.endMouseDraw()
  }
}
