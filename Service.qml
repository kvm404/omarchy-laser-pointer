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
  property color color: "#ff3b30"
  property int thickness: 3
  property int cursorX: 0
  property int cursorY: 0
  property bool cursorReady: false
  property var trailStrokes: []
  property var currentTrailPoints: []
  readonly property int trailLifetimeMs: 1500
  readonly property int maximumTrailPoints: 12000
  readonly property int maximumTrailStrokes: 64

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
    if (!root.mouseHeld) return

    var currentPoints = root.currentTrailPoints.slice()
    currentPoints.push({ x: x, y: y, time: now })

    // Bound a long hold without touching previously released strokes.
    while (currentPoints.length > root.maximumTrailPoints)
      currentPoints.shift()

    root.currentTrailPoints = currentPoints
  }

  function clearTrail() {
    root.trailStrokes = []
    root.currentTrailPoints = []
  }

  function beginMouseDraw() {
    if (!root.active || root.trailSuppressed) return

    // Finish any previous active stroke before starting a new one. Completed
    // strokes live in a separate list, so a new hold cannot clear or hide one.
    root.endMouseDraw()
    root.currentTrailPoints = []
    root.mouseHeld = true
  }

  function endMouseDraw() {
    if (!root.mouseHeld && root.currentTrailPoints.length === 0) return

    root.mouseHeld = false
    if (root.currentTrailPoints.length === 0) return

    var next = root.trailStrokes.slice()
    next.push({ points: root.currentTrailPoints, fadeStartMs: Date.now() })
    while (next.length > root.maximumTrailStrokes)
      next.shift()

    root.trailStrokes = next
    root.currentTrailPoints = []
  }

  function pruneTrail() {
    if (root.trailStrokes.length === 0) return

    var now = Date.now()
    var next = []
    var changed = false
    for (var i = 0; i < root.trailStrokes.length; i++) {
      var stroke = root.trailStrokes[i]
      var fadeStartMs = Number(stroke.fadeStartMs) || 0
      var stillVisible = fadeStartMs > 0 && now - fadeStartMs < root.trailLifetimeMs

      if (stillVisible) next.push(stroke)
      else changed = true
    }

    if (changed) root.trailStrokes = next
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
