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
    if (root.trailStrokes.length === 0) return

    var next = root.trailStrokes.slice()
    var currentIndex = next.length - 1
    var current = next[currentIndex]
    var currentPoints = current.points.slice()
    currentPoints.push({ x: x, y: y, time: now })
    next[currentIndex] = {
      points: currentPoints,
      fadeStartMs: current.fadeStartMs
    }

    var totalPoints = 0
    for (var i = 0; i < next.length; i++)
      totalPoints += next[i].points.length

    // Bound total memory while preserving the newest strokes. In practice
    // this only matters during an unusually long or very high-rate hold.
    while (totalPoints > root.maximumTrailPoints && next.length > 0) {
      var oldest = next[0]
      if (oldest.points.length === 0) {
        next.shift()
        continue
      }

      var remaining = oldest.points.slice(1)
      totalPoints -= 1
      if (remaining.length === 0 && oldest.fadeStartMs > 0)
        next.shift()
      else
        next[0] = { points: remaining, fadeStartMs: oldest.fadeStartMs }
    }

    root.trailStrokes = next
  }

  function clearTrail() {
    root.trailStrokes = []
  }

  function beginMouseDraw() {
    if (!root.active || root.trailSuppressed) return

    // Start a fresh stroke without clearing released strokes. Each stroke
    // keeps its own release time so several recent strokes can fade together.
    var next = root.trailStrokes.slice()
    next.push({ points: [], fadeStartMs: 0 })
    root.trailStrokes = next
    root.mouseHeld = true
  }

  function endMouseDraw() {
    if (!root.mouseHeld) return

    root.mouseHeld = false
    if (root.trailStrokes.length === 0) return

    var next = root.trailStrokes.slice()
    var currentIndex = next.length - 1
    var current = next[currentIndex]
    if (!current || current.points.length === 0) {
      next.pop()
    } else {
      next[currentIndex] = {
        points: current.points,
        fadeStartMs: Date.now()
      }
    }
    root.trailStrokes = next
  }

  function pruneTrail() {
    if (root.trailStrokes.length === 0) return

    var now = Date.now()
    var next = []
    var changed = false
    for (var i = 0; i < root.trailStrokes.length; i++) {
      var stroke = root.trailStrokes[i]
      var isCurrentStroke = root.mouseHeld && i === root.trailStrokes.length - 1
      var fadeStartMs = Number(stroke.fadeStartMs) || 0
      var stillVisible = isCurrentStroke
        || (fadeStartMs > 0 && now - fadeStartMs < root.trailLifetimeMs)

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
